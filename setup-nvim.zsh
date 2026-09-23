#!/usr/bin/env zsh

# Installs Neovim, the NvChad starter, and the Lua configuration kept in the
# nvim/ folder next to this script.
#
#   ./setup-nvim.zsh                full reinstall (the default)
#   ./setup-nvim.zsh -i				only what is missing or has changed
#
# After a full run, set your terminal font to "JetBrainsMono Nerd Font",
# open a fresh terminal, launch nvim, then run :TSInstall cpp python lua elixir

set -euo pipefail

NVIM_VERSION="latest" # a tag such as v0.11.2 pins a specific release
TS_VERSION="v0.24.7"  # last tree-sitter release before the glibc 2.39 bump
FONT="JetBrainsMono"
SCRIPT_DIR="${0:A:h}"
CONFIG_SRC="${SCRIPT_DIR}/nvim"
NVIM_CONFIG="${HOME}/.config/nvim"

info() { printf '\n\033[1;34m==>\033[0m %s\n' "${1}"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "${1}"; }
skip() { printf '\033[1;32m[skip]\033[0m %s\n' "${1}"; }

usage() {
    cat <<'EOF'
usage: setup-nvim.zsh [--incremental | --full]

  --full, -f          wipe and reinstall everything (default)
  --inc, -i           install only what is missing
  --help, -h          this message
EOF
}

# ------------------------------- arguments ------------------------------------
MODE="full"
while (($#)); do
    case "${1}" in
        -i | --inc) MODE="incremental" ;;
        -f | --full) MODE="full" ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            warn "unknown argument '${1}'"
            usage
            exit 1
            ;;
    esac
    shift
done

incremental() { [[ "${MODE}" == "incremental" ]]; }
CONFIG_CHANGED=0

# -------------------------- dependency check ----------------------------------
require() {
    command -v "${1}" >/dev/null 2>&1 || {
        warn "missing '${1}', install it first"
        exit 1
    }
}

for cmd in git curl tar; do require "${cmd}"; done

[[ -d "${CONFIG_SRC}/lua" ]] || {
    warn "nvim/lua not found next to this script (looked in ${CONFIG_SRC})"
    exit 1
}

machine="$(uname -m)"

if incremental; then
    info "Incremental:: skipping anything already in place"
else
    info "Full:: config, plugins, state and cache are rebuilt"
fi

# ----------------------------- add to .zshrc ----------------------------------
# Appends a line to ~/.zshrc unless it is already there.
persist_in_zshrc() {
    grep -qF "${1}" "${HOME}/.zshrc" 2>/dev/null || printf '\n%s\n' "${1}" >>"${HOME}/.zshrc"
}

# ------------------------------- Neovim ---------------------------------------
# The official release tarball, unpacked into /opt. Distro packages (apt) ship
# a Neovim too old for NvChad v2.5, which needs 0.11+.
case "${machine}" in
    x86_64) nvim_arch="linux-x86_64" ;;
    aarch64) nvim_arch="linux-arm64" ;;
    *)
        warn "unknown arch ${machine}, defaulting to linux-x86_64"
        nvim_arch="linux-x86_64"
        ;;
esac
nvim_prefix="/opt/nvim-${nvim_arch}"

wanted_nvim_version() {
    if [[ "${NVIM_VERSION}" != "latest" ]]; then
        printf '%s' "${NVIM_VERSION}"
        return 0
    fi
    local effective
    effective="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
        "https://github.com/neovim/neovim/releases/latest" 2>/dev/null)" || return 1
    printf '%s' "${effective##*/}"
}

installed_nvim_version() {
    [[ -x "${nvim_prefix}/bin/nvim" ]] || return 1
    local out
    out="$("${nvim_prefix}/bin/nvim" --version 2>/dev/null)" || return 1
    # first line only, then its second field: "NVIM v0.12.5" -> v0.12.5
    out="${out%%$'\n'*}"
    printf '%s' "${${out#* }%% *}"
}

install_neovim() {
    require sudo

    local tarball="nvim-${nvim_arch}.tar.gz" url tmp
    if [[ "${NVIM_VERSION}" == "latest" ]]; then
        url="https://github.com/neovim/neovim/releases/latest/download/${tarball}"
    else
        url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${tarball}"
    fi

    tmp="$(mktemp -d)"
    curl -fL "${url}" -o "${tmp}/${tarball}"
    sudo rm -rf "${nvim_prefix}"
    sudo tar -C /opt -xzf "${tmp}/${tarball}"
    rm -rf "${tmp}"
}

info "Installing Neovim (${NVIM_VERSION})"
nvim_have="$(installed_nvim_version || true)"
nvim_want="$(wanted_nvim_version || true)"

if incremental && [[ -n "${nvim_have}" ]]; then
    if [[ -z "${nvim_want}" ]]; then
        skip "Neovim ${nvim_have} present, could not reach GitHub to check for a newer one"
    elif [[ "${nvim_have}" == "${nvim_want}" ]]; then
        skip "Neovim ${nvim_have} already installed in ${nvim_prefix}"
    else
        info "Neovim ${nvim_have} -> ${nvim_want}"
        install_neovim
    fi
else
    install_neovim
fi

export PATH="${PATH}:${nvim_prefix}/bin"
# shellcheck disable=SC2016  # the literal, unexpanded text is what belongs in .zshrc
persist_in_zshrc "export PATH=\"\$PATH:${nvim_prefix}/bin\""

nvim --version | head -1

# ------------------------------- NvChad ---------------------------------------

nvchad_present() { [[ -f "${NVIM_CONFIG}/init.lua" && -d "${NVIM_CONFIG}/lua" ]]; }

install_nvchad() {
    if [[ -d "${NVIM_CONFIG}" ]]; then
        local backup="${NVIM_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
        mv "${NVIM_CONFIG}" "${backup}"
        info "Old config moved to ${backup}"
    fi
    rm -rf "${HOME}/.local/share/nvim" "${HOME}/.local/state/nvim" "${HOME}/.cache/nvim"
    git clone --depth 1 https://github.com/NvChad/starter "${NVIM_CONFIG}"
    rm -rf "${NVIM_CONFIG}/.git"
}

info "Installing NvChad starter"
if incremental && nvchad_present; then
    skip "NvChad starter already at ${NVIM_CONFIG}, keeping plugins, state and cache"
else
    incremental && warn "no usable config at ${NVIM_CONFIG}, doing a fresh starter install"
    install_nvchad
fi

# ------------------------- tree-sitter CLI ------------------------------------
case "${machine}" in
    x86_64) ts_arch="linux-x64" ;;
    aarch64) ts_arch="linux-arm64" ;;
    *)
        warn "unknown arch ${machine}, defaulting to linux-x64"
        ts_arch="linux-x64"
        ;;
esac
ts_bin="${HOME}/.local/bin/tree-sitter"

installed_ts_version() {
    [[ -x "${ts_bin}" ]] || return 1
    local out
    out="$("${ts_bin}" --version 2>/dev/null)" || return 1
    printf '%s' "${${out#* }%% *}"
}

install_tree_sitter() {
    require gunzip
    mkdir -p "${HOME}/.local/bin"
    curl -fL "https://github.com/tree-sitter/tree-sitter/releases/download/${TS_VERSION}/tree-sitter-${ts_arch}.gz" -o /tmp/ts.gz
    gunzip -f /tmp/ts.gz
    chmod +x /tmp/ts
    mv /tmp/ts "${ts_bin}"
}

info "Installing tree-sitter CLI ${TS_VERSION}"
ts_have="$(installed_ts_version || true)"
if incremental && [[ "${ts_have}" == "${TS_VERSION#v}" ]]; then
    skip "tree-sitter ${ts_have} already at ${ts_bin}"
else
    [[ -n "${ts_have}" ]] && info "tree-sitter ${ts_have} -> ${TS_VERSION#v}"
    install_tree_sitter
fi

# --------------------------------- PATH ---------------------------------------
info "Ensuring ~/.local/bin is on PATH"
export PATH="${HOME}/.local/bin:${PATH}"
persist_in_zshrc 'export PATH="$HOME/.local/bin:$PATH"'

# ---------- verify the binary actually runs on this glibc ---------------------
if ! "${ts_bin}" --version >/dev/null 2>&1; then
    warn "tree-sitter binary will not run here (glibc likely too old even for ${TS_VERSION})."
    warn "Build from source instead:"
    warn "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    warn "  source \$HOME/.cargo/env && cargo install tree-sitter-cli"
fi

# ------------------------------- Nerd Font ------------------------------------
font_installed() {
    local -a found
    found=("${HOME}/.local/share/fonts"/**/${FONT}*.(ttf|otf)(N))
    ((${#found}))
}

install_font() {
    mkdir -p "${HOME}/.local/share/fonts"
    curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT}.zip" -o "/tmp/${FONT}.zip"
    unzip -o "/tmp/${FONT}.zip" -d "${HOME}/.local/share/fonts" >/dev/null
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null
    else
        warn "fc-cache not found, font cache not refreshed"
    fi
}

info "Installing ${FONT} Nerd Font"
if incremental && font_installed; then
    skip "${FONT} Nerd Font already in ~/.local/share/fonts"
elif command -v unzip >/dev/null 2>&1; then
    install_font
else
    warn "unzip not found, skipping font install. Install unzip and re-run, or grab a Nerd Font from nerdfonts.com"
fi

# ------------------------- the Lua configuration ------------------------------
copy_config_changed() {
    local src rel dest
    for src in "${CONFIG_SRC}"/**/*(.DN); do
        rel="${src#${CONFIG_SRC}/}"
        [[ "${rel}" == .git/* ]] && continue
        dest="${NVIM_CONFIG}/${rel}"
        if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
            continue
        fi
        mkdir -p "${dest:h}"
        cp "${src}" "${dest}"
        printf '    updated %s\n' "${rel}"
        CONFIG_CHANGED=1
    done
}

if incremental; then
    info "Syncing changed files from nvim/ into ${NVIM_CONFIG}"
    copy_config_changed
    ((CONFIG_CHANGED)) || skip "config already matches nvim/, nothing copied"
else
    info "Copying nvim/lua/ over the starter's ${NVIM_CONFIG}/lua"
    cp -R "${CONFIG_SRC}/." "${NVIM_CONFIG}/"
    CONFIG_CHANGED=1
fi

for linter in shellcheck ruff clang-tidy luacheck; do
    command -v "${linter}" >/dev/null 2>&1 || warn "linter '${linter}' not installed, it will be skipped until you add it"
done

# ------------------------- bootstrap plugins ----------------------------------
info "Bootstrapping plugins (headless)"
nvim --headless -c 'lua require("lazy").install({ wait = true, show = false })' -c 'qa!' 2>/dev/null \
    || warn "plugin bootstrap had issues, it will finish on first launch"

# base46 compiles its highlights to a cache; chadrc changes need a rebuild.
if ((CONFIG_CHANGED)); then
    nvim --headless -c 'lua require("base46").load_all_highlights()' -c 'qa!' 2>/dev/null \
        || warn "highlight cache not rebuilt, it will rebuild on first launch"
else
    skip "config unchanged, highlight cache left as is"
fi

info "Done."
if incremental; then
    cat <<'EOF'

Incremental run finished. Plugins, Mason servers, tree-sitter parsers and shada
were left untouched. Open a fresh terminal if the PATH lines were just added.

EOF
else
    cat <<'EOF'

Next steps:
  1. Set your terminal font to "JetBrainsMono Nerd Font" in its preferences.
  2. Fully close and reopen the terminal so the font and PATH take effect.
  3. Launch nvim and run:  :TSInstall cpp python lua elixir

EOF
fi
