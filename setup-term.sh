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

source "${SCRIPT_DIR}/lib/log.sh"

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

[[ -f "${CONFIG_SRC}/config" ]] || {
    fail "terminator/config not found next to this script (looked in ${CONFIG_SRC})"
    exit 1
}

if incremental; then
    title "Update Terminator Setup"
    command -v terminator >/dev/null 2>&1 \
        || warn "Terminator is not installed, run ./setup-term.sh without -i first"
else
    title "Full-Fledged Terminator Setup"
fi

# ----------------------------- installation -----------------------------------
download_themes() {
    mkdir -p "${TERM_CONFIG}/plugins"
    wget -q "${THEMES_URL}" -O "${TERM_CONFIG}/plugins/terminator-themes.py"
}

if ! incremental; then
    apt_install terminator python3-pip wget
    run "Upgrading pip" python3 -m pip install --user --upgrade pip
    # TerminatorThemes needs requests
    if ! python3 -c 'import requests' 2>/dev/null; then
        run "Installing requests" python3 -m pip install --user --upgrade requests
    fi
    try "The copy in terminator/plugins is used instead" \
        "Downloading the TerminatorThemes plugin" download_themes
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
        ok "Updated ${rel}"
        CONFIG_CHANGED=1
    done < <(find "${CONFIG_SRC}" -type f -not -path '*/__pycache__/*' -print0)
}

mkdir -p "${TERM_CONFIG}"
copy_config_changed
((CONFIG_CHANGED)) || ok "Config up to date"

title "Done"
info "Close every Terminator window and open a new one so the config takes effect."
