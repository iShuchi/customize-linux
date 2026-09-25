#!/usr/bin/env bash

# Installs Neovim, the NvChad starter, and the Lua configuration kept in the
# nvim/ folder next to this script.
#
#   ./setup-nvim.sh                 full reinstall (the default)
#   ./setup-nvim.sh -i              only what is missing or has changed
#
# After a full run, set your terminal font to "JetBrainsMono Nerd Font",
# open a fresh terminal, launch nvim, then run :TSInstall cpp python lua elixir

set -euo pipefail

NVIM_VERSION="latest" # a tag such as v0.11.2 pins a specific release
TS_VERSION="v0.24.7"  # last tree-sitter release before the glibc 2.39 bump
FONT="JetBrainsMono"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${SCRIPT_DIR}/nvim"
NVIM_CONFIG="${HOME}/.config/nvim"

source "${SCRIPT_DIR}/lib/log.sh"

usage() {
    cat <<'EOF'
usage: setup-nvim.sh [--incremental | --full]

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
        fail "missing '${1}', installing the requirement"
        exit 1
    }
}

for cmd in git curl tar; do require "${cmd}"; done

[[ -d "${CONFIG_SRC}/lua" ]] || {
    fail "nvim/lua not found next to this script (looked in ${CONFIG_SRC})"
    exit 1
}

machine="$(uname -m)"

if incremental; then
    title "Updating NEOVIM Setup"
else
    title "Full-FLedged NEOVIM Setup"
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
    # second word of the first line: "NVIM v0.12.5" -> v0.12.5
    read -r _ out _ <<<"${out}"
    printf '%s' "${out}"
}

install_neovim() {
    local tarball="nvim-${nvim_arch}.tar.gz" url tmp
    if [[ "${NVIM_VERSION}" == "latest" ]]; then
        url="https://github.com/neovim/neovim/releases/latest/download/${tarball}"
    else
        url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${tarball}"
    fi

    tmp="$(mktemp -d)"
    curl -fsSL "${url}" -o "${tmp}/${tarball}"
    sudo rm -rf "${nvim_prefix}"
    sudo tar -C /opt -xzf "${tmp}/${tarball}"
    rm -rf "${tmp}"
}

nvim_have="$(installed_nvim_version || true)"
nvim_want="$(wanted_nvim_version || true)"

if incremental && [[ -n "${nvim_have}" ]]; then
    if [[ -z "${nvim_want}" ]]; then
        warn "Could not reach GitHub to check for a newer NEOVIM than ${nvim_have}"
    elif [[ "${nvim_have}" != "${nvim_want}" ]]; then
        sudo_init
        run "Updating Neovim ${nvim_have} to ${nvim_want}" install_neovim
    fi
else
    sudo_init
    run "Installing NEOVIM ${nvim_want:-${NVIM_VERSION}}" install_neovim
fi

export PATH="${PATH}:${nvim_prefix}/bin"
# shellcheck disable=SC2016  # the literal, unexpanded text is what belongs in .zshrc
persist_in_zshrc "export PATH=\"\$PATH:${nvim_prefix}/bin\""

# ------------------------------- NvChad ---------------------------------------

nvchad_present() { [[ -f "${NVIM_CONFIG}/init.lua" && -d "${NVIM_CONFIG}/lua" ]]; }

install_nvchad() {
    rm -rf "${HOME}/.local/share/nvim" "${HOME}/.local/state/nvim" "${HOME}/.cache/nvim"
    git clone --depth 1 https://github.com/NvChad/starter "${NVIM_CONFIG}"
    rm -rf "${NVIM_CONFIG}/.git"
}

if ! incremental || ! nvchad_present; then
    incremental && warn "No usable config at ${NVIM_CONFIG}, doing a fresh starter install"
    if [[ -d "${NVIM_CONFIG}" ]]; then
        backup="${NVIM_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
        mv "${NVIM_CONFIG}" "${backup}"
        info "Old config moved to ${backup/#${HOME}/\~}"
    fi
    run "Installing NvChad starter" install_nvchad
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
    read -r _ out _ <<<"${out}"
    printf '%s' "${out}"
}

install_tree_sitter() {
    mkdir -p "${HOME}/.local/bin"
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/${TS_VERSION}/tree-sitter-${ts_arch}.gz" -o /tmp/ts.gz
    gunzip -f /tmp/ts.gz
    chmod +x /tmp/ts
    mv /tmp/ts "${ts_bin}"
}

ts_have="$(installed_ts_version || true)"
if ! incremental || [[ "${ts_have}" != "${TS_VERSION#v}" ]]; then
    require gunzip
    if [[ -n "${ts_have}" && "${ts_have}" != "${TS_VERSION#v}" ]]; then
        run "Updating tree-sitter CLI ${ts_have} to ${TS_VERSION#v}" install_tree_sitter
    else
        run "Installing tree-sitter CLI ${TS_VERSION#v}" install_tree_sitter
    fi
fi

# --------------------------------- PATH ---------------------------------------
export PATH="${HOME}/.local/bin:${PATH}"
# shellcheck disable=SC2016
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
    [[ -n "$(find "${HOME}/.local/share/fonts" -name "${FONT}*.[ot]tf" -print -quit 2>/dev/null)" ]]
}

install_font() {
    mkdir -p "${HOME}/.local/share/fonts"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT}.zip" -o "/tmp/${FONT}.zip"
    unzip -o "/tmp/${FONT}.zip" -d "${HOME}/.local/share/fonts" >/dev/null
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null
    fi
}

if incremental && font_installed; then
    :
elif command -v unzip >/dev/null 2>&1; then
    run "Installing ${FONT} Nerd Font" install_font
else
    warn "unzip not found. Install unzip and re-run"
fi

# ------------------------- the Lua configuration ------------------------------
copy_config_changed() {
    local src rel dest
    while IFS= read -r -d '' src; do
        rel="${src#"${CONFIG_SRC}"/}"
        dest="${NVIM_CONFIG}/${rel}"
        if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
            continue
        fi
        mkdir -p "$(dirname "${dest}")"
        cp "${src}" "${dest}"
        ok "Updated ${rel}"
        CONFIG_CHANGED=1
    done < <(find "${CONFIG_SRC}" -type f -print0)
}

if incremental; then
    copy_config_changed
    ((CONFIG_CHANGED)) || ok "Config up to date"
else
    cp -R "${CONFIG_SRC}/." "${NVIM_CONFIG}/"
    ok "Config copied into ${NVIM_CONFIG/#${HOME}/\~}"
    CONFIG_CHANGED=1
fi

if command -v luacheck >/dev/null 2>&1; then
    :
elif command -v apt-get >/dev/null 2>&1; then
    apt_install lua-check
else
    warn "apt-get not found, install luacheck yourself (e.g. luarocks install luacheck)"
fi

for linter in shellcheck ruff clang-tidy luacheck; do
    command -v "${linter}" >/dev/null 2>&1 || warn "Linter '${linter}' not installed, it is skipped until you add it"
done

for tool in fzf rg; do
    command -v "${tool}" >/dev/null 2>&1 || warn "'${tool}' not installed, fuzzy finding (fzf-lua) needs it"
done

# ------------------------- bootstrap plugins ----------------------------------
try "Plugins finish installing on first launch" \
    "Installing plugins" nvim --headless -c 'lua require("lazy").install({ wait = true, show = false })' -c 'qa!'

# base46 compiles its highlights to a cache; chadrc changes need a rebuild.
if ((CONFIG_CHANGED)); then
    try "The highlight cache rebuilds on first launch" \
        "Rebuilding highlight cache" nvim --headless -c 'lua require("base46").load_all_highlights()' -c 'qa!'
fi

title "Done"
if incremental; then
    info "Open a fresh terminal if the PATH lines were just added."
else
    info "Next steps:"
    info "  1. Set your terminal font to \"JetBrainsMono Nerd Font\" in its preferences."
    info "  2. Fully close and reopen the terminal so the font and PATH take effect."
    info "  3. Launch nvim and run:  :TSInstall cpp python lua elixir"
fi
