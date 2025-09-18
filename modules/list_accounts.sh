#!/usr/bin/env bash
# ============================================================
# list_accounts.sh - List all configured msmtp accounts
# ============================================================
# Features:
# - Respects DRY_RUN and ACCOUNT_CONFIG_FILE
# - Excludes 'default' alias from the list
# - Uses consistent logging from utils.sh
# - Optional JSON output (--json)
# - Provides list_accounts() function for reuse in other modules
# ============================================================

source "$(dirname "$0")/utils.sh"

load_env_file() {
    local env_file=""
    if [[ -f "$(dirname "$0")/.env" ]]; then
        env_file="$(dirname "$0")/.env"
    elif [[ -f ".env" ]]; then
        env_file=".env"
    fi
    if [[ -n "$env_file" ]]; then
        log_info "list_accounts: loading environment variables from $env_file"
        set -a
        source "$env_file"
        set +a
    fi
}

# --- Core function to get accounts as plain list ---
list_accounts() {
    local config_file="${ACCOUNT_CONFIG_FILE:-/etc/msmtprc}"

    if [[ "$DRY_RUN" == "1" && -f "/tmp/msmtprc.preview" ]]; then
        config_file="/tmp/msmtprc.preview"
        log_info "list_accounts: using preview config $config_file"
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "list_accounts: configuration file not found at $config_file"
        return 1
    fi

    grep -E '^account ' "$config_file" | awk '{print $2}' | grep -v '^default$'
}

# --- CLI entry point ---
list_accounts_main() {
    section "Listing configured msmtp accounts"

    load_env_file

    local json_out=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json_out=1; shift ;;
            *) shift ;;
        esac
    done

    local accounts
    accounts=$(list_accounts) || return 1

    if [[ -z "$accounts" ]]; then
        log_warn "No accounts found"
        [[ "$json_out" -eq 1 ]] && echo "[]"
        return 0
    fi

    if [[ "$json_out" -eq 1 ]]; then
        local json="["
        while read -r acc; do
            json+="{\"account\":\"$acc\"},"
        done <<< "$accounts"
        json="${json%,}]"
        echo "$json"
    else
        printf "\n%-20s\n" "ACCOUNT"
        printf "%-20s\n" "-------"
        echo "$accounts" | while read -r acc; do
            printf "%-20s\n" "$acc"
        done
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    list_accounts_main "$@"
fi
