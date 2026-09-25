#!/usr/bin/env bash
#
# setup-code.sh
#
# Replicates this VS Code setup on another machine: every installed
# extension, the settings.json (formatters, linters, theme, icon theme),
# keybindings, argv.json (all kept in vscode/) are present here.
#
# Usage:
#   ./setup-code.sh           full install, then copy the config (the default)
#   ./setup-code.sh -i        only copy vscode/ changes into ~/.config/Code/User
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/vscode"
USER_DIR="$HOME/.config/Code/User"
STAMP="$(date +%Y%m%d%H%M%S)"

source "$SCRIPT_DIR/lib/log.sh"

usage() {
    cat <<'EOF'
usage: setup-code.sh [--inc | --full]

  --full, -f          install VS Code
  --inc, -i           copy changed files from vscode/ into ~/.config/Code/User
  --help, -h          this message
EOF
}

# ------------------------------- arguments ------------------------------------
MODE="full"
while (($#)); do
    case "$1" in
        -i | --inc) MODE="incremental" ;;
        -f | --full) MODE="full" ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            warn "unknown argument '$1'"
            usage
            exit 1
            ;;
    esac
    shift
done

incremental() { [[ "$MODE" == "incremental" ]]; }

if incremental; then
    title "Updating VS Code Setup"
    command -v code >/dev/null 2>&1 \
        || warn "VS Code is not installed, run ./setup-code.sh without -i first"
else
    title "Full-Fledged VS Code Setup"
fi

# Microsoft apt repo, as in https://code.visualstudio.com/docs/setup/linux
install_vscode() {
    sudo apt-get update
    sudo apt-get install -y wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | sudo gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg
    # An older one-line vscode.list with a different Signed-By makes apt
    # refuse to update, so it is replaced by the deb822 vscode.sources.
    sudo rm -f /etc/apt/sources.list.d/vscode.list
    sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
    sudo apt-get update
    sudo apt-get install -y code
}

if ! incremental; then
    if ! command -v code >/dev/null 2>&1; then
        sudo_init
        run "Installing VS Code" install_vscode
    fi

    command -v code >/dev/null 2>&1 || { fail "code is not on PATH, stopping"; exit 1; }

# ------------------------------- Extensions -----------------------------------
EXTENSIONS=(
    akamud.vscode-theme-onedark
    anthropic.claude-code
    charliermarsh.ruff
    davidanson.vscode-markdownlint
    donjayamanne.githistory
    dotjoshjohnson.xml
    eamodio.gitlens
    esbenp.prettier-vscode
    github.vscode-github-actions
    helgardrichard.helium-icon-theme
    jaehyunshim.vscode-ros2
    mhutchie.git-graph
    morningfrog.urdf-visualizer
    ms-azuretools.vscode-containers
    ms-python.black-formatter
    ms-python.debugpy
    ms-python.python
    ms-python.vscode-pylance
    ms-python.vscode-python-envs
    ms-vscode-remote.remote-containers
    ms-vscode-remote.remote-ssh
    ms-vscode-remote.remote-ssh-edit
    ms-vscode.cmake-tools
    ms-vscode.cpp-devtools
    ms-vscode.cpptools
    ms-vscode.cpptools-extension-pack
    ms-vscode.cpptools-themes
    ms-vscode.remote-explorer
    redhat.vscode-xml
    redhat.vscode-yaml
    smilerobotics.urdf
    streetsidesoftware.code-spell-checker
    tomoki1207.pdf
    vue.volar
)

    INSTALLED="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"

    for ext in "${EXTENSIONS[@]}"; do
        grep -qx "${ext,,}" <<<"$INSTALLED" && continue
        run "Installing $ext" code --install-extension "$ext" --force
    done
fi

# ----------------------------- User config ------------------------------------
    mkdir -p "$USER_DIR"

    backup() {
        [ -f "$1" ] && cp "$1" "$1.bak.$STAMP"
    }
    RENDERED="$(mktemp)"
    CONFIG_CHANGED=0
    for f in settings.json keybindings.json argv.json; do
        [ -f "$CONFIG_SRC/$f" ] || { warn "vscode/$f not found next to this script"; continue; }
        sed "s#__HOME__#$HOME#g" "$CONFIG_SRC/$f" > "$RENDERED"
        if [ -f "$USER_DIR/$f" ] && cmp -s "$RENDERED" "$USER_DIR/$f"; then
            continue
        fi
        backup "$USER_DIR/$f"
        cp "$RENDERED" "$USER_DIR/$f"
        ok "Updated $f"
        CONFIG_CHANGED=1
    done
    rm -f "$RENDERED"
    [ "$CONFIG_CHANGED" -eq 1 ] || ok "Config up to date"

    mkdir -p "$USER_DIR/snippets"

if ! incremental; then

# -------------------------------- Formatter ----------------------------------

    # settings.json points clang-format, black and ruff at ~/.local/bin
    MISSING_TOOLS=()
    for t in clang-format black ruff; do
        [ -x "$HOME/.local/bin/$t" ] || MISSING_TOOLS+=("$t")
    done

    if ((${#MISSING_TOOLS[@]})); then
        if command -v pip3 >/dev/null 2>&1; then
            run "Installing ${MISSING_TOOLS[*]}" pip3 install --user --upgrade "${MISSING_TOOLS[@]}"
        else
            warn "pip3 not found, install python3-pip, then: pip3 install --user ${MISSING_TOOLS[*]}"
        fi
    fi
fi

title "Done"
info "Restart VS Code to pick up the new extensions and settings."
