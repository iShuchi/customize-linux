#!/usr/bin/env bash

# Installs Terminator, the TerminatorThemes plugin and its Python dependency,
# then copies the config and plugins kept in the terminator/ folder next to
# this script into ~/.config/terminator.
#
#   ./setup-term.sh                 full install, then copy the config (the default)
#   ./setup-term.sh -i              only copy terminator/ changes into ~/.config/terminator
#
# Close every Terminator window afterwards, it only reads its config at start.

set -euo pipefail

THEMES_URL="https://git.io/v5Zww"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${SCRIPT_DIR}/terminator"
TERM_CONFIG="${HOME}/.config/terminator"

info() { printf '\n\033[1;34m==>\033[0m %s\n' "${1}"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "${1}"; }
skip() { printf '\033[1;32m[skip]\033[0m %s\n' "${1}"; }

usage() {
    cat <<'EOF'
usage: setup-term.sh [--incremental | --full]

  --full, -f          install Terminator, pip, requests and the plugin, then copy the config (default)
  --inc, -i           only copy changed files from terminator/ into ~/.config/terminator
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

# -------------------------- dependency check ----------------------------------
require() {
    command -v "${1}" >/dev/null 2>&1 || {
        warn "missing '${1}', install it first"
        exit 1
    }
}

[[ -f "${CONFIG_SRC}/config" ]] || {
    warn "terminator/config not found next to this script (looked in ${CONFIG_SRC})"
    exit 1
}

if incremental; then
    info "Incremental:: skipping installs, syncing config only"
    command -v terminator >/dev/null 2>&1 \
        || warn "terminator is not installed, run ./setup-term.sh without -i first"
else
    info "Full:: Terminator, pip, requests and the themes plugin are installed"
fi

# ----------------------------- installation -----------------------------------
if ! incremental; then
    require sudo

    info "Installing Terminator"
    sudo apt-get update
    sudo apt-get install -y terminator python3-pip wget

    info "Upgrading pip3 to the latest version"
    python3 -m pip install --user --upgrade pip

    info "Installing requests (TerminatorThemes needs it)"
    python3 -m pip install --user --upgrade requests

    info "Downloading the TerminatorThemes plugin"
    mkdir -p "${TERM_CONFIG}/plugins"
    wget -q "${THEMES_URL}" -O "${TERM_CONFIG}/plugins/terminator-themes.py" \
        || warn "download failed, the copy in terminator/plugins is used instead"
fi

# --------------------------- the configuration --------------------------------
# Copies every file from terminator/ that is missing or differs. An existing
# config that is about to be replaced is kept as config.bak.<timestamp>.
CONFIG_CHANGED=0
copy_config_changed() {
    local src rel dest
    while IFS= read -r -d '' src; do
        rel="${src#"${CONFIG_SRC}"/}"
        dest="${TERM_CONFIG}/${rel}"
        if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
            continue
        fi
        if [[ "${rel}" == "config" && -f "${dest}" ]]; then
            cp "${dest}" "${dest}.bak.$(date +%Y%m%d%H%M%S)"
        fi
        mkdir -p "$(dirname "${dest}")"
        cp "${src}" "${dest}"
        printf '    updated %s\n' "${rel}"
        CONFIG_CHANGED=1
    done < <(find "${CONFIG_SRC}" -type f -not -path '*/__pycache__/*' -print0)
}

info "Syncing terminator/ into ${TERM_CONFIG}"
mkdir -p "${TERM_CONFIG}"
copy_config_changed
((CONFIG_CHANGED)) || skip "config already matches terminator/, nothing copied"

info "Done."
cat <<'EOF'

Close every Terminator window and open a new one so the config takes effect.

EOF
