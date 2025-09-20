#!/usr/bin/env bash
# ============================================================
# account_duplicates_validator.sh - Detect duplicate accounts
# ============================================================
# Checks for duplicate (host, port, user) combinations in:
# - /etc/msmtprc (default)
# - /tmp/msmtprc.preview if DRY_RUN=1 and file exists
# - Or a provided config file via ACCOUNT_CONFIG_FILE env var
# ============================================================

set -Eeuo pipefail

#source "$(dirname "$0")/utils.sh"
# Resolve this script's directory and load utilities
SCRIPT_DIR="$(get_script_dir)"
source "$SCRIPT_DIR/utils.sh"

validate_account_duplicates() {
    section "Validating duplicate accounts (host, port, user)"

    load_env_file

    local strict="${STRICT_VALIDATION:-1}"
    local config_file="${ACCOUNT_CONFIG_FILE:-/etc/msmtprc}"

    # Auto-detect preview file in DRY_RUN
    if [[ "$DRY_RUN" == "1" && -f "/tmp/msmtprc.preview" ]]; then
        config_file="/tmp/msmtprc.preview"
        log_info "account_duplicates_validator: using preview config $config_file"
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "account_duplicates_validator: configuration file not found at $config_file"
        return 1
    fi

    declare -A triples
    declare -A duplicates_map
    local duplicates=0
    local total=0

    local current_account="" host="" port="" user=""

    printf "\n%-20s %-30s %-6s %-25s %-10s\n" "ACCOUNT" "HOST" "PORT" "USER" "DUPLICATE"
    printf "%-20s %-30s %-6s %-25s %-10s\n" "-------" "----" "----" "----" "---------"

    while IFS= read -r line; do
        case "$line" in
            account\ *)
                current_account=$(echo "$line" | awk '{print $2}')
                # Ignorar "account default"
                if [[ "$current_account" == "default" ]]; then
                    current_account=""
                fi
                ;;
            host\ *)
                host=$(echo "$line" | awk '{print $2}')
                ;;
            port\ *)
                port=$(echo "$line" | awk '{print $2}')
                ;;
            user\ *)
                user=$(echo "$line" | awk '{print $2}')
                if [[ -n "$current_account" && -n "$host" && -n "$port" && -n "$user" ]]; then
                    ((total++))
                    local key="${host}:${port}:${user}"
                    if [[ -n "${triples[$key]:-}" ]]; then
                        log_warn "Duplicate: '$current_account' and '${triples[$key]}' share (host=$host, port=$port, user=$user)"
                        duplicates_map["$current_account"]=1
                        duplicates_map["${triples[$key]}"]=1
                        ((duplicates++))
                        printf "%-20s %-30s %-6s %-25s %-10s\n" "$current_account" "$host" "$port" "$user" "yes"
                    else
                        triples[$key]="$current_account"
                        printf "%-20s %-30s %-6s %-25s %-10s\n" "$current_account" "$host" "$port" "$user" "no"
                    fi
                    # Reset para siguiente cuenta
                    host=""
                    port=""
                    user=""
                fi
                ;;
        esac
    done < "$config_file"

    # Guardar en set_state
    set_state "account_duplicates_count" "$duplicates"
    set_state "account_total_count" "$total"
    if (( duplicates > 0 )); then
        set_state "account_duplicates_list" "$(IFS=,; echo "${!duplicates_map[*]}")"
        set_state "account_duplicates_validation" "fail"
        if [[ "$strict" -eq 1 && "$DRY_RUN" != "1" ]]; then
            return 1
        fi
    else
        set_state "account_duplicates_list" ""
        set_state "account_duplicates_validation" "ok"
    fi

    log_info "account_duplicates_validator: $duplicates duplicate(s) found out of $total accounts."
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if ! validate_account_duplicates; then
        exit 1
    fi
fi
