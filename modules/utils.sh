#!/usr/bin/env bash
# ============================================================
# utils.sh - Common utility functions for the installer
# ============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -Eeuo pipefail
fi


# ----- Verbosity & modes -----
: "${VERBOSE:=1}"          # 1 = verbose, 0 = quiet
: "${DEBUG:=0}"            # 1 = debug logs enabled
: "${NON_INTERACTIVE:=0}"  # 1 = no prompts, auto-yes

# ----- Color setup -----
if [[ -z "${NO_COLOR:-}" ]]; then
    COLOR_RESET="\033[0m"
    COLOR_RED="\033[31m"
    COLOR_GREEN="\033[32m"
    COLOR_YELLOW="\033[33m"
    COLOR_BLUE="\033[34m"
else
    COLOR_RESET=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
fi

# ----- Logging functions -----
log_info()  { [[ "$VERBOSE" -eq 1 ]] && echo -e "${COLOR_BLUE}ℹ️  $*${COLOR_RESET}"; log_to_file "INFO: $*"; }
log_warn()  { echo -e "${COLOR_YELLOW}⚠️  $*${COLOR_RESET}" >&2; log_to_file "WARN: $*"; }
log_error() { echo -e "${COLOR_RED}❌ $*${COLOR_RESET}" >&2; log_to_file "ERROR: $*"; }
log_debug() { [[ "$DEBUG" -eq 1 ]] && echo -e "🐛 $*"; log_to_file "DEBUG: $*"; }

# ----- Optional log to file -----
log_to_file() {
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

# ----- Abort with error -----
abort () {
    log_error "$*"
    exit 1
}

# ----- Abort with custom exit code -----
die() {
    local code="$1"; shift
    log_error "$*"
    exit "$code"
}

# ----- Global error handler -----
error_trap () {
    local exit_code=$?
    local line_no=$1
    local cmd="$2"
    abort "Failed on line $line_no (command: $cmd) [exit code: $exit_code]"
}

# ----- Require root privileges -----
require_root () {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        abort "This script must be run as root (sudo)."
    fi
}

# ----- Require a command to be available -----
require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || abort "Required command '$cmd' not found."
}

# ----- Require a writable directory -----
require_writable_dir() {
    local dir="$1"
    [[ -d "$dir" && -w "$dir" ]] || abort "Directory '$dir' is not writable."
}

# ----- Prompt with optional default -----
prompt () {
    local var="$1" msg="$2" def="${3-}"
    local input
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        [[ -n "$def" ]] || abort "Non-interactive mode: no default provided for $var"
        printf -v "$var" '%s' "$def"
        return
    fi
    if [[ -n "$def" ]]; then
        read -r -p "$msg [$def]: " input || abort "Input canceled"
        input="${input:-$def}"
    else
        read -r -p "$msg: " input || abort "Input canceled"
    fi
    [[ -n "$input" ]] || abort "Value cannot be empty."
    printf -v "$var" '%s' "$input"
}

# ----- Prompt using env var if available -----
prompt_env_or_ask() {
    local var="$1" msg="$2" def="${3-}"
    if [[ -n "${!var:-}" ]]; then
        printf -v "$var" '%s' "${!var}"
    else
        prompt "$var" "$msg" "$def"
    fi
}

# ----- Prompt for a password/secret for a specific account -----
prompt_secret_for_account () {
    local account="$1"
    local secrets_dir="/etc/msmtp.secrets"
    local dest="$secrets_dir/${account}.passwd"

    install -d -m 700 -o root -g root "$secrets_dir"

    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        abort "Non-interactive mode: cannot prompt for password of account '$account'"
    fi

    local HIST_WAS_ON=1
    if set -o | grep -q 'history[[:space:]]\+on'; then
        set +o history
    else
        HIST_WAS_ON=0
    fi

    local secret=''
    while true; do
        read -r -s -p "Enter password for account '$account': " secret || abort "Input canceled"
        echo
        [[ -n "$secret" ]] && break
        log_warn "Value cannot be empty."
    done

    umask 177
    printf '%s' "$secret" > "$dest"
    chown root:root "$dest"
    chmod 600 "$dest"

    secret=''
    unset secret

    if [[ $HIST_WAS_ON -eq 1 ]]; then
        set -o history
    fi
}

# ----- Retrieve stored secret for a specific account -----
get_secret_for_account() {
    local account="$1"
    local secrets_dir="/etc/msmtp.secrets"
    local file="$secrets_dir/${account}.passwd"
    [[ -f "$file" ]] || abort "Secret file for account '$account' not found."
    cat "$file"
}

# ----- Confirm action -----
confirm() {
    local prompt_msg="$1"
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        return 0
    fi
    read -r -p "$prompt_msg [y/N]: " reply
    case "${reply,,}" in
        y|yes) return 0 ;;
        *)     return 1 ;;
    esac
}

# ----- Backup file with timestamp -----
backup_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -p "$file" "${file}.bak_${ts}"
    log_info "Backup created: ${file}.bak_${ts}"
}

# ----- Get absolute path -----
abs_path() {
    local path="$1"
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd -P)
    else
        echo "$(cd "$(dirname "$path")" && pwd -P)/$(basename "$path")"
    fi
}

# ----- Get the absolute directory of the current script -----
get_script_dir() {
    local src="${BASH_SOURCE[0]}"
    while [ -h "$src" ]; do
        local dir
        dir="$(cd -P -- "$(dirname -- "$src")" && pwd)"
        src="$(readlink -- "$src")"
        [[ $src != /* ]] && src="$dir/$src"
    done
    cd -P -- "$(dirname -- "$src")" && pwd
}


# ----- Safe run of a command with description -----
safe_run() {
    local desc="$1"; shift
    "$@" || abort "Failed to $desc"
}

# ----- Section header -----
section() {
    echo -e "\n${COLOR_GREEN}==> $*${COLOR_RESET}"
}

# ----- Validate value against regex -----
validate_regex() {
    local value="$1" pattern="$2" errmsg="$3"
    [[ "$value" =~ $pattern ]] || abort "$errmsg"
}

# ----- Create a secure temporary file -----
make_temp_file() {
    local tmp
    tmp=$(mktemp /tmp/msmtp_installer.XXXXXX)
    echo "$tmp" >> "${TMP_FILES_TRACKER:-/tmp/msmtp_installer.tmpfiles}"
    echo "$tmp"
}

# ----- State management -----
STATE_FILE="/tmp/msmtp_installer.state"

set_state() {
    local key="$1" value="$2"
    grep -v "^${key}=" "$STATE_FILE" 2>/dev/null > "${STATE_FILE}.tmp" || true
    echo "${key}=${value}" >> "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

get_state() {
    local key="$1"
    grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2-
}

# ----- Cleanup handler for signals -----
cleanup_on_exit() {
    log_info "Cleaning up before exit..."
    # Remove tracked temp files
    if [[ -f "${TMP_FILES_TRACKER:-/tmp/msmtp_installer.tmpfiles}" ]]; then
        while read -r tmp; do
            [[ -f "$tmp" ]] && rm -f "$tmp"
        done < "${TMP_FILES_TRACKER:-/tmp/msmtp_installer.tmpfiles}"
        rm -f "${TMP_FILES_TRACKER:-/tmp/msmtp_installer.tmpfiles}"
    fi
    # Remove state file
    [[ -f "$STATE_FILE" ]] && rm -f "$STATE_FILE"
    log_info "Cleanup complete."
}

select_option() {
    local prompt="$1"
    local -n options=$2
    local -n result=$3

    echo "$prompt"
    local i=1
    for opt in "${options[@]}"; do
        echo "  $i) $opt"
        ((i++))
    done

    local choice
    while true; do
        read -rp "Select an option [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            result="${options[$((choice-1))]}"
            break
        else
            echo "Invalid selection."
        fi
    done
}

# --- Load .env global if present ---
load_env_file() {
    local env_file=""
    local script_dir
    script_dir="$(get_script_dir)"

    if [[ -f "$script_dir/.env" ]]; then
        env_file="$script_dir/.env"
    elif [[ -f ".env" ]]; then
        env_file=".env"
    fi

    if [[ -n "$env_file" ]]; then
        log_info "Loading environment variables from $env_file"
        set -a
        source "$env_file"
        set +a
    fi
}
