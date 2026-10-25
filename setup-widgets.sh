#!/usr/bin/env bash
#
# setup-widgets.sh
#
# Puts the desktop back the way it is here: the conky clock/date and day-name
# widgets on the built-in display, started at login and restarted on every
# monitor change, plus the Dash to Panel bottom dock on every monitor. All of
# it is kept in home/:

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${SCRIPT_DIR}/home"
WIDGET_DIR="${HOME}/Documents/widget"
AUTOSTART_DIR="${HOME}/.config/autostart"
FONT_DIR="${HOME}/.local/share/fonts"
D2P_UUID="dash-to-panel@jderose9.github.com"
D2P_PATH="/org/gnome/shell/extensions/dash-to-panel/"
STAMP="$(date +%Y%m%d%H%M%S)"

source "${SCRIPT_DIR}/lib/log.sh"

usage() {
    cat <<'EOF'
usage: setup-widgets.sh [--inc | --full]

  --full, -f          install conky and Dash to Panel, then copy the config (default)
  --inc, -i           only copy changed files from home/ and reload the widgets
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

[[ -d "${CONFIG_SRC}" ]] || {
    fail "home/ not found next to this script (looked in ${CONFIG_SRC})"
    exit 1
}

if incremental; then
    title "Update Widgets Setup"
    command -v conky >/dev/null 2>&1 \
        || warn "conky is not installed, run ./setup-widgets.sh without -i first"
else
    title "Full-Fledged Widgets Setup"
fi

# ----------------------------- installation -----------------------------------
# Picks the Dash to Panel release matching this GNOME Shell from
# extensions.gnome.org. It is only active after logging out and back in.
install_dash_to_panel() {
    local shell_version info url zip
    shell_version="$(gnome-shell --version | grep -oE '[0-9]+' | head -n 1)"
    info="https://extensions.gnome.org/extension-info/?uuid=${D2P_UUID}&shell_version=${shell_version}"
    url="$(wget -qO- "${info}" | python3 -c 'import json, sys; print(json.load(sys.stdin)["download_url"])')"
    zip="$(mktemp --suffix=.zip)"
    wget -q "https://extensions.gnome.org${url}" -O "${zip}"
    gnome-extensions install --force "${zip}"
    rm -f "${zip}"
}

if ! incremental; then
    # libglib2.0-bin gives gdbus, which the widget watcher listens with, and
    # x11-xserver-utils gives xrandr, which it turns TearFree on with
    apt_install conky-all libglib2.0-bin x11-xserver-utils wget python3
    if ! gnome-extensions info "${D2P_UUID}" >/dev/null 2>&1; then
        try "Install Dash to Panel from https://extensions.gnome.org/extension/1160/dash-to-panel/" \
            "Installing Dash to Panel" install_dash_to_panel
    fi
    if gnome-extensions info "${D2P_UUID}" >/dev/null 2>&1; then
        try "Enable it in the Extensions app after logging back in" \
            "Enabling Dash to Panel" gnome-extensions enable "${D2P_UUID}"
    fi
fi

# --------------------------- the configuration --------------------------------
# copy_changed src dest   copies src over dest when it is missing or differs,
# keeping the replaced file as <dest>.bak.<timestamp>.
CONFIG_CHANGED=0
copy_changed() {
    local src="${1}" dest="${2}"
    if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
        return 1
    fi
    [[ -f "${dest}" ]] && cp "${dest}" "${dest}.bak.${STAMP}"
    mkdir -p "$(dirname "${dest}")"
    cp "${src}" "${dest}"
    ok "Updated ${dest/#"${HOME}"/\~}"
    CONFIG_CHANGED=1
    return 0
}

WIDGETS_CHANGED=0
for f in conkyrc_time Hermoso_Rc script; do
    copy_changed "${CONFIG_SRC}/${f}" "${WIDGET_DIR}/${f}" && WIDGETS_CHANGED=1
done
chmod +x "${WIDGET_DIR}/script"

# The autostart entry needs the absolute path of the launcher.
RENDERED="$(mktemp)"
sed "s#__HOME__#${HOME}#g" "${CONFIG_SRC}/script.desktop" >"${RENDERED}"
copy_changed "${RENDERED}" "${AUTOSTART_DIR}/script.desktop" || true
rm -f "${RENDERED}"

FONTS_CHANGED=0
while IFS= read -r -d '' font; do
    copy_changed "${font}" "${FONT_DIR}/$(basename "${font}")" && FONTS_CHANGED=1
done < <(find "${CONFIG_SRC}/fonts" -type f \( -name '*.ttf' -o -name '*.otf' \) -print0)
((FONTS_CHANGED)) && run "Refreshing the font cache" fc-cache -f "${FONT_DIR}"

# Anurati is free for personal use only, so it is not kept in this repo.
fc-list : family | grep -i anurati >/dev/null \
    || warn "Anurati font missing, the day name falls back to another font. Get it from https://www.dafont.com/anurati.font into ${FONT_DIR}"

# ------------------------------ Dash to Panel ---------------------------------
# available-monitors is written by the extension itself, so it is left out of
# both sides of the comparison.
load_dash_to_panel() {
    mkdir -p "${HOME}/.config/d2p-backup"
    dconf dump "${D2P_PATH}" >"${HOME}/.config/d2p-backup/dash-to-panel.${STAMP}.ini"
    dconf load "${D2P_PATH}" <"${CONFIG_SRC}/dash-to-panel.ini"
}

if ! command -v dconf >/dev/null 2>&1; then
    warn "dconf not found, Dash to Panel settings were not applied"
elif ! cmp -s <(dconf dump "${D2P_PATH}" | grep -v '^available-monitors=') \
    "${CONFIG_SRC}/dash-to-panel.ini"; then
    run "Applying Dash to Panel settings" load_dash_to_panel
    CONFIG_CHANGED=1
fi

((CONFIG_CHANGED)) || ok "Config up to date"

# Restarts conky and its monitor watcher so the new config shows up now. The
# watcher runs in its own session, so killing that whole group also stops its
# gdbus child, which would otherwise keep holding the watcher lock.
restart_widgets() {
    local pid
    for pid in $(pgrep -f "${WIDGET_DIR}/script --watch" || true); do
        kill -- "-${pid}" 2>/dev/null || true
    done
    "${WIDGET_DIR}/script"
}

if ((WIDGETS_CHANGED || FONTS_CHANGED)) && [[ -n "${DISPLAY:-}" ]]; then
    run "Restarting the widgets" restart_widgets
fi

title "Done"
incremental || info "Log out and back in if Dash to Panel was just installed."
