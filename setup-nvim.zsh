#!/usr/bin/env zsh

# Installs Neovim, the NvChad starter, and the Lua configuration kept in the
# nvim/ folder next to this script.
#
# After running, set your terminal font to "JetBrainsMono Nerd Font",
# open a fresh terminal, launch nvim, then run :TSInstall cpp python lua

set -euo pipefail

NVIM_VERSION="latest" # a tag such as v0.11.2 pins a specific release
TS_VERSION="v0.24.7"  # last tree-sitter release before the glibc 2.39 bump
FONT="JetBrainsMono"
SCRIPT_DIR="${0:A:h}"
CONFIG_SRC="${SCRIPT_DIR}/nvim"

info() { printf '\n\033[1;34m==>\033[0m %s\n' "${1}"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "${1}"; }

# -------------------------- dependency check ----------------------------------
for cmd in git curl gunzip tar sudo; do
    command -v "${cmd}" >/dev/null 2>&1 || {
        warn "missing '${cmd}', install it first"
        exit 1
    }
done

[[ -d "${CONFIG_SRC}/lua" ]] || {
    warn "nvim/lua not found next to this script (looked in ${CONFIG_SRC})"
    exit 1
}

machine="$(uname -m)"

# ----------------------------- add to .zshrc ----------------------------------
# Appends a line to ~/.zshrc unless it is already there.
persist_in_zshrc() {
    grep -qF "${1}" "${HOME}/.zshrc" 2>/dev/null || printf '\n%s\n' "${1}" >>"${HOME}/.zshrc"
}

# ------------------------------- Neovim ---------------------------------------
# The official release tarball, unpacked into /opt. Distro packages (apt) ship
# a Neovim too old for NvChad v2.5, which needs 0.11+.
info "Installing Neovim (${NVIM_VERSION})"
case "${machine}" in
    x86_64) nvim_arch="linux-x86_64" ;;
    aarch64) nvim_arch="linux-arm64" ;;
    *)
        warn "unknown arch ${machine}, defaulting to linux-x86_64"
        nvim_arch="linux-x86_64"
        ;;
esac

nvim_tarball="nvim-${nvim_arch}.tar.gz"
if [[ "${NVIM_VERSION}" == "latest" ]]; then
    nvim_url="https://github.com/neovim/neovim/releases/latest/download/${nvim_tarball}"
else
    nvim_url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${nvim_tarball}"
fi

nvim_tmp="$(mktemp -d)"
curl -fL "${nvim_url}" -o "${nvim_tmp}/${nvim_tarball}"
sudo rm -rf "/opt/nvim-${nvim_arch}"
sudo tar -C /opt -xzf "${nvim_tmp}/${nvim_tarball}"
rm -rf "${nvim_tmp}"

export PATH="${PATH}:/opt/nvim-${nvim_arch}/bin"
# shellcheck disable=SC2016  # the literal, unexpanded text is what belongs in .zshrc
persist_in_zshrc "export PATH=\"\$PATH:/opt/nvim-${nvim_arch}/bin\""

nvim --version | head -1

# -----------------------. NvChad fresh install --------------------------------
info "Installing NvChad starter"
if [[ -d "${HOME}/.config/nvim" ]]; then
    backup="${HOME}/.config/nvim.bak.$(date +%Y%m%d%H%M%S)"
    mv "${HOME}/.config/nvim" "${backup}"
    info "Old config moved to ${backup}"
fi
rm -rf "${HOME}/.local/share/nvim" "${HOME}/.local/state/nvim" "${HOME}/.cache/nvim"
git clone --depth 1 https://github.com/NvChad/starter "${HOME}/.config/nvim"
rm -rf "${HOME}/.config/nvim/.git"

# ------------------------- tree-sitter CLI ------------------------------------
info "Installing tree-sitter CLI ${TS_VERSION}"
case "${machine}" in
    x86_64) ts_arch="linux-x64" ;;
    aarch64) ts_arch="linux-arm64" ;;
    *)
        warn "unknown arch ${machine}, defaulting to linux-x64"
        ts_arch="linux-x64"
        ;;
esac
mkdir -p "${HOME}/.local/bin"
curl -fL "https://github.com/tree-sitter/tree-sitter/releases/download/${TS_VERSION}/tree-sitter-${ts_arch}.gz" -o /tmp/ts.gz
gunzip -f /tmp/ts.gz
chmod +x /tmp/ts
mv /tmp/ts "${HOME}/.local/bin/tree-sitter"

# --------------------------------- PATH ---------------------------------------
info "Ensuring ~/.local/bin is on PATH"
export PATH="${HOME}/.local/bin:${PATH}"
# shellcheck disable=SC2016  # the literal, unexpanded text is what belongs in .zshrc
persist_in_zshrc 'export PATH="$HOME/.local/bin:$PATH"'

# ---------- verify the binary actually runs on this glibc ---------------------
if ! "${HOME}/.local/bin/tree-sitter" --version >/dev/null 2>&1; then
    warn "tree-sitter binary will not run here (glibc likely too old even for ${TS_VERSION})."
    warn "Build from source instead:"
    warn "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    warn "  source \$HOME/.cargo/env && cargo install tree-sitter-cli"
fi

# ------------------------------- Nerd Font ------------------------------------
info "Installing ${FONT} Nerd Font"
if command -v unzip >/dev/null 2>&1; then
    mkdir -p "${HOME}/.local/share/fonts"
    curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT}.zip" -o "/tmp/${FONT}.zip"
    unzip -o "/tmp/${FONT}.zip" -d "${HOME}/.local/share/fonts" >/dev/null
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null
    else
        warn "fc-cache not found, font cache not refreshed"
    fi
else
    warn "unzip not found, skipping font install. Install unzip and re-run, or grab a Nerd Font from nerdfonts.com"
fi

# ------------------------- the Lua configuration ------------------------------
info "Copying nvim/lua/ over the starter's ~/.config/nvim/lua"
cp -R "${CONFIG_SRC}/." "${HOME}/.config/nvim/"

for linter in shellcheck ruff clang-tidy luacheck; do
    command -v "${linter}" >/dev/null 2>&1 || warn "linter '${linter}' not installed, it will be skipped until you add it"
done

# ------------------------- bootstrap plugins ----------------------------------
info "Bootstrapping plugins (headless)"
# `Lazy! sync` hands back before the async clones finish, which can leave the
# sidebar plugins uninstalled; the Lua API blocks until they are on disk.
nvim --headless -c 'lua require("lazy").install({ wait = true, show = false })' -c 'qa!' 2>/dev/null \
    || warn "plugin bootstrap had issues, it will finish on first launch"

# base46 compiles its highlights to a cache; chadrc changes need a rebuild.
nvim --headless -c 'lua require("base46").load_all_highlights()' -c 'qa!' 2>/dev/null \
    || warn "highlight cache not rebuilt, it will rebuild on first launch"

info "Done."
cat <<'EOF'

Next steps:
  1. Set your terminal font to "JetBrainsMono Nerd Font" in its preferences.
  2. Fully close and reopen the terminal so the font and PATH take effect.
  3. Launch nvim and run:  :TSInstall cpp python lua elixir

EOF
