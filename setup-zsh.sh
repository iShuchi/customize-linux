#!/usr/bin/env bash
#
# setup-zsh.sh
#
# Migrates a machine from bash to zsh and reproduces this exact zsh
# environment: Oh My Zsh, Spaceship prompt, fzf with fzf-tab, bat previews,
# ROS 2 argcomplete bridging, and the tuned ~/.zshrc kept in zsh/.zshrc.
#
#   ./setup-zsh.sh                  full install, then copy the config (the default)
#   ./setup-zsh.sh -i               only copy zsh/.zshrc changes into ~/.zshrc
#

set -uo pipefail

# ------------------------------Configuration ----------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

say()  { echo "--> $*"; }
warn() { echo "!!! $*" >&2; }

usage() {
    cat <<'EOF'
usage: setup-zsh.sh [--inc | --full]

  --full, -f          install zsh, Oh My Zsh, plugins and fzf
  --inc, -i           copy zsh/.zshrc into ~/.zshrc if it changed
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

echo "=== zsh environment setup starting ==="

if incremental; then
    say "Incremental:: skipping installs, syncing .zshrc only"
    command -v zsh >/dev/null 2>&1 \
        || warn "zsh is not installed, run ./setup-zsh.sh without -i first"
fi

if ! incremental; then

    # ------------------------------- Base packages --------------------------------

    APT_PKGS=(zsh git curl wget bat sshpass xdg-utils nano python3-argcomplete)

    MISSING=()
    for p in "${APT_PKGS[@]}"; do
        dpkg -s "$p" >/dev/null 2>&1 || MISSING+=("$p")
    done

    if [ ${#MISSING[@]} -gt 0 ]; then
        say "Installing: ${MISSING[*]}"
        sudo apt update
        sudo apt install -y "${MISSING[@]}" || warn "some packages failed to install"
    else
        say "All base packages already present"
    fi

    # Ubuntu/Debian ship bat as `batcat`.
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
        say "Linked bat -> batcat in ~/.local/bin"
    fi

    # Register zsh as a valid login shell
    ZSH_BIN="$(command -v zsh)"
    if [ -n "$ZSH_BIN" ] && ! grep -qx "$ZSH_BIN" /etc/shells 2>/dev/null; then
        echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
        say "Registered $ZSH_BIN in /etc/shells"
    fi

    # ---------------------------- Oh My Zsh -----------------------------------
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        say "Installing Oh My Zsh"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended --keep-zshrc
    else
        say "Oh My Zsh already installed, skipping"
    fi

    # ------------------------- Plugins and Theme ------------------------------
    clone_if_missing() {
        local repo="$1" dest="$2"
        if [ ! -d "$dest" ]; then
            say "Cloning $(basename "$dest")"
            git clone --depth=1 "$repo" "$dest" || warn "failed to clone $repo"
        else
            say "$(basename "$dest") already present, skipping"
        fi
    }

    mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"

    # fzf-tab: the only non-builtin plugin the live .zshrc loads
    clone_if_missing https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"

    # Spaceship prompt
    clone_if_missing https://github.com/spaceship-prompt/spaceship-prompt.git \
    "$ZSH_CUSTOM/themes/spaceship-prompt"
    if [ ! -e "$ZSH_CUSTOM/themes/spaceship.zsh-theme" ]; then
        ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" \
        "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
        say "Linked spaceship.zsh-theme"
    fi

    # --------------------------------- fzf ------------------------------------
    if [ ! -d "$HOME/.fzf" ]; then
        say "Installing fzf from source"
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" \
        && "$HOME/.fzf/install" --all --no-fish
    else
        say "fzf already installed -- updating"
        git -C "$HOME/.fzf" pull --ff-only >/dev/null 2>&1 \
        && "$HOME/.fzf/install" --all --no-fish >/dev/null 2>&1
    fi
fi

# ------------------------------- Install ~/.zshrc -----------------------------

ZSHRC_SRC="$SCRIPT_DIR/zsh/.zshrc"

if [ ! -f "$ZSHRC_SRC" ]; then
    warn "zsh/.zshrc not found next to this script (looked in $ZSHRC_SRC)"
    exit 1
fi

if [ -f "$HOME/.zshrc" ] && cmp -s "$ZSHRC_SRC" "$HOME/.zshrc"; then
    say ".zshrc already matches zsh/.zshrc, nothing copied"
else
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
        say "Existing .zshrc backed up"
    fi
    cp "$ZSHRC_SRC" "$HOME/.zshrc"
    say "zsh/.zshrc copied to $HOME/.zshrc"
fi

git config --global core.pager 'less -FRX'

if ! incremental; then
    if [ "$SHELL" != "$ZSH_BIN" ]; then
        say "Setting zsh as the default shell (may prompt for your password)"
        chsh -s "$ZSH_BIN" || warn "chsh failed -- run 'chsh -s $ZSH_BIN' manually"
    else
        say "zsh is already the login shell"
    fi
fi

echo
echo "ZSH Setup is Complete"
