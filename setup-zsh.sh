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

source "$SCRIPT_DIR/lib/log.sh"

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

if incremental; then
    title "Update ZSH Setup"
    command -v zsh >/dev/null 2>&1 \
        || warn "zsh is not installed, run ./setup-zsh.sh without -i first"
else
    title "Full-Fledged ZSH Setup"
fi

if ! incremental; then

    # ------------------------------- Base packages --------------------------------
    apt_install zsh git curl wget bat sshpass xdg-utils nano python3-argcomplete

    # Ubuntu/Debian ship bat as `batcat`.
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    fi

    # Register zsh as a valid login shell
    ZSH_BIN="$(command -v zsh)"
    if [ -n "$ZSH_BIN" ] && ! grep -qx "$ZSH_BIN" /etc/shells 2>/dev/null; then
        sudo_init
        echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
    fi

    # ---------------------------- Oh My Zsh -----------------------------------
    install_omz() {
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            "" --unattended --keep-zshrc
    }
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        run "Installing Oh My Zsh" install_omz
    fi

    # ------------------------- Plugins and Theme ------------------------------
    clone_if_missing() {
        local name="$1" repo="$2" dest="$3"
        if [ ! -d "$dest" ]; then
            run "Installing $name" git clone --depth=1 "$repo" "$dest"
        fi
    }

    mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"

    # fzf-tab: the only non-builtin plugin the live .zshrc loads
    clone_if_missing fzf-tab https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"

    # Spaceship prompt
    clone_if_missing "Spaceship prompt" https://github.com/spaceship-prompt/spaceship-prompt.git \
        "$ZSH_CUSTOM/themes/spaceship-prompt"
    if [ ! -e "$ZSH_CUSTOM/themes/spaceship.zsh-theme" ]; then
        ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" \
            "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
    fi

    # --------------------------------- fzf ------------------------------------
    install_fzf() {
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --all --no-fish
    }
    update_fzf() {
        git -C "$HOME/.fzf" pull --ff-only
        "$HOME/.fzf/install" --all --no-fish
    }
    if [ ! -d "$HOME/.fzf" ]; then
        run "Installing fzf" install_fzf
    else
        run "Updating fzf" update_fzf
    fi
fi

# ------------------------------- Install ~/.zshrc -----------------------------

ZSHRC_SRC="$SCRIPT_DIR/zsh/.zshrc"

if [ ! -f "$ZSHRC_SRC" ]; then
    fail "zsh/.zshrc not found next to this script (looked in $ZSHRC_SRC)"
    exit 1
fi

if [ -f "$HOME/.zshrc" ] && cmp -s "$ZSHRC_SRC" "$HOME/.zshrc"; then
    ok "~/.zshrc up to date"
else
    if [ -f "$HOME/.zshrc" ]; then
        backup="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
        cp "$HOME/.zshrc" "$backup"
        ok "Updated ~/.zshrc, the old one is kept as ${backup/#$HOME/\~}"
    else
        ok "Installed ~/.zshrc"
    fi
    cp "$ZSHRC_SRC" "$HOME/.zshrc"
fi

git config --global core.pager 'less -FRX'

if ! incremental && [ "$SHELL" != "$ZSH_BIN" ]; then
    info "Setting zsh as the login shell"
    if chsh -s "$ZSH_BIN"; then
        ok "zsh is now the login shell"
    else
        warn "chsh failed, run 'chsh -s $ZSH_BIN' manually"
    fi
fi

title "Done"
info "Open a new terminal to start using zsh."
