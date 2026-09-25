# Shared logging for the setup-*.sh scripts. Source it, do not run it.

LOG_FILE="${TMPDIR:-/tmp}/$(basename "${0}" .sh).log"
: >"${LOG_FILE}"

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_TITLE=$'\033[1;34m'
    C_OK=$'\033[32m'
    C_WARN=$'\033[33m'
    C_FAIL=$'\033[31m'
    C_DIM=$'\033[2m'
else
    C_RESET="" C_TITLE="" C_OK="" C_WARN="" C_FAIL="" C_DIM=""
fi

title() { printf '%s%s%s\n' "${C_TITLE}" "$*" "${C_RESET}"; }
info() { printf '  %s\n' "$*"; }
ok() { printf '  %s%s%s\n' "${C_OK}" "$*" "${C_RESET}"; }
warn() { printf '  %s%s%s\n' "${C_WARN}" "$*" "${C_RESET}" >&2; }
fail() { printf '  %s%s%s\n' "${C_FAIL}" "$*" "${C_RESET}" >&2; }

# Restores the cursor and stops the sudo keep-alive however the script ends.
_log_cleanup() {
    [[ -t 1 ]] && printf '\033[?25h'
    local pids
    mapfile -t pids < <(jobs -p)
    ((${#pids[@]})) && kill "${pids[@]}" 2>/dev/null
    return 0
}
trap _log_cleanup EXIT
trap 'exit 130' INT TERM

# run "label" cmd...   runs cmd quietly behind animated dots, then prints the
# label green or red. Call it bare, never as `run ... || x` or inside an `if`:
# bash turns set -e off inside a checked command, so a multi-step function
# would carry on past its first failure. Use try for optional steps.
run() {
    local label="${1}" pid rc=0 i=0 start
    shift
    printf '\n==> %s\n' "${label}" >>"${LOG_FILE}"
    start=$(($(wc -l <"${LOG_FILE}") + 1))

    (set -e; "$@") </dev/null >>"${LOG_FILE}" 2>&1 &
    pid=$!
    if [[ -t 1 ]]; then
        printf '\033[?25l'
        while kill -0 "${pid}" 2>/dev/null; do
            printf '\r\033[K  %s%s%.*s%s' "${label}" "${C_DIM}" $((i % 3 + 1)) "..." "${C_RESET}"
            i=$((i + 1))
            sleep 0.3
        done
        printf '\r\033[K\033[?25h'
    fi
    wait "${pid}" || rc=$?

    if ((rc == 0)); then
        ok "${label}"
    else
        fail "${label} failed, full output in ${LOG_FILE}"
        tail -n +"${start}" "${LOG_FILE}" | grep -v '^[[:space:]]*$' | tail -n 5 \
            | sed "s/^/    ${C_DIM}/; s/\$/${C_RESET}/" >&2
    fi
    return "${rc}"
}

# try "fallback warning" "label" cmd...   like run, but a failure only warns
# and the script carries on.
try() {
    local warning="${1}" rc=0
    shift
    local -
    set +e
    run "$@"
    rc=$?
    ((rc == 0)) || warn "${warning}"
    return 0
}

# Asks for the sudo password once, in the foreground, then keeps the
# credentials fresh so steps running behind the dots never need to prompt.
sudo_init() {
    [[ -n "${_SUDO_READY:-}" ]] && return 0
    command -v sudo >/dev/null 2>&1 || {
        fail "sudo is required"
        exit 1
    }
    sudo -v || {
        fail "sudo authentication failed"
        exit 1
    }
    (while kill -0 "$$" 2>/dev/null; do
        sudo -n true
        sleep 50
    done) >/dev/null 2>&1 &
    _SUDO_READY=1
}

_apt_install() {
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

apt_install() {
    local missing=() p
    for p in "$@"; do
        dpkg-query -W -f='${Status}' "${p}" 2>/dev/null | grep -q "install ok installed" \
            || missing+=("${p}")
    done
    ((${#missing[@]})) || return 0
    sudo_init
    run "Installing ${missing[*]}" _apt_install "${missing[@]}"
}
