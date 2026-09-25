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

say()  { echo "--> $*"; }
warn() { echo "!!! $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/vscode"
USER_DIR="$HOME/.config/Code/User"
STAMP="$(date +%Y%m%d%H%M%S)"

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

echo "=== VS Code environment setup starting ==="

if incremental; then
    say "Incremental:: skipping installs, syncing vscode/ config only"
    command -v code >/dev/null 2>&1 \
        || warn "VS Code is not installed, run ./setup-code.sh without -i first"
fi

if ! incremental; then
    if ! command -v code >/dev/null 2>&1; then
        say "VS Code not found -- installing from the Microsoft apt repo"
        sudo apt update
        sudo apt install -y wget gpg
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
            | sudo gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg
        sudo rm -f /etc/apt/sources.list.d/vscode.list
        sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
        sudo apt update
        sudo apt install -y code
    else
        say "VS Code already installed: $(command -v code)"
    fi

    command -v code >/dev/null 2>&1 || { warn "code still not on PATH -- aborting"; exit 1; }

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
    openai.chatgpt
    redhat.vscode-xml
    redhat.vscode-yaml
    smilerobotics.urdf
    streetsidesoftware.code-spell-checker
    tomoki1207.pdf
    vue.volar
)

    say "Installing ${#EXTENSIONS[@]} extensions (already-present ones are skipped)"

    INSTALLED="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    FAILED=()

    for ext in "${EXTENSIONS[@]}"; do
        if echo "$INSTALLED" | grep -qx "$(echo "$ext" | tr '[:upper:]' '[:lower:]')"; then
            echo "    = $ext (already installed)"
            continue
        fi
        echo "    + $ext"
        code --install-extension "$ext" --force >/dev/null 2>&1 || FAILED+=("$ext")
    done

    if [ ${#FAILED[@]} -gt 0 ]; then
        warn "These extensions failed to install (marketplace availability may differ):"
        for f in "${FAILED[@]}"; do echo "      $f"; done
    else
        say "All extensions installed"
    fi
fi

# ----------------------------- User config ------------------------------------
    mkdir -p "$USER_DIR"

    backup() {
        [ -f "$1" ] && cp "$1" "$1.bak.$STAMP" && say "Backed up $(basename "$1")"
    }
    RENDERED="$(mktemp)"
    trap 'rm -f "$RENDERED"' EXIT
    CONFIG_CHANGED=0
    for f in settings.json keybindings.json argv.json; do
        [ -f "$CONFIG_SRC/$f" ] || { warn "vscode/$f not found next to this script"; continue; }
        sed "s#__HOME__#$HOME#g" "$CONFIG_SRC/$f" > "$RENDERED"
        if [ -f "$USER_DIR/$f" ] && cmp -s "$RENDERED" "$USER_DIR/$f"; then
            continue
        fi
        backup "$USER_DIR/$f"
        cp "$RENDERED" "$USER_DIR/$f"
        say "$f copied"
        CONFIG_CHANGED=1
    done
    [ "$CONFIG_CHANGED" -eq 1 ] || say "config already matches vscode/, nothing copied"

    mkdir -p "$USER_DIR/snippets"

if ! incremental; then

# -------------------------------- Formatter ----------------------------------

    if command -v pip3 >/dev/null 2>&1; then
        say "Installing clang-format, black and ruff into ~/.local/bin"
        pip3 install --user --upgrade clang-format black ruff \
            || warn "pip install failed -- install clang-format/black/ruff by hand"
    else
        warn "pip3 not found -- skipping. Install python3-pip, then:"
        warn "    pip3 install --user clang-format black ruff"
    fi

    for t in clang-format black ruff; do
        if [ -x "$HOME/.local/bin/$t" ]; then
            echo "    ok  $HOME/.local/bin/$t"
        else
            warn "missing: $HOME/.local/bin/$t (settings.json expects it here)"
        fi
    done
fi

echo
echo "Restart VS Code to pick up the new extensions and settings."
if ! incremental; then
    echo
    echo " Installation is complete."
fi
