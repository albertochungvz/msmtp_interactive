#!/usr/bin/env bash
# ============================================================
# smtp_test.sh - Send test emails using msmtp accounts
# ============================================================
# Features:
# - Loads msmtprc (real or preview)
# - Optionally runs smtp_audit.sh before sending
# - Sends test email(s) to a target address
# - Supports testing all accounts or a specific one
# - Integrates with STRICT_VALIDATION
# - Optional JSON report (--json)
# - Records results in set_state
# ============================================================

# Resolve this script's directory and load utilities
SCRIPT_DIR="$(get_script_dir)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/list_accounts.sh"

send_test_email() {
    local account="$1"
    local to_addr="$2"
    local config_file="$3"

    log_info "smtp_test: sending test email using account '$account' to '$to_addr'"

    local subject="SMTP Test from $account @ $(hostname)"
    local body="This is a test email sent on $(date) from account '$account'."

    if ! echo -e "Subject: $subject\n\n$body" \
        | msmtp --file="$config_file" --account="$account" "$to_addr" >/dev/null 2>&1; then
        log_error "smtp_test: failed to send test email with account '$account'"
        return 1
    fi

    log_info "smtp_test: test email sent successfully with account '$account'"
    return 0
}

smtp_test_main() {
    section "SMTP Test"

    load_env_file

    local strict="${STRICT_VALIDATION:-1}"
    local config_file="${ACCOUNT_CONFIG_FILE:-/etc/msmtprc}"
    local target_email="${SMTP_TEST_TO:-}"
    local specific_account="${SMTP_TEST_ACCOUNT:-}"
    local json_out=0
    local run_audit=1

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --account) specific_account="$2"; shift 2 ;;
            --to) target_email="$2"; shift 2 ;;
            --json) json_out=1; shift ;;
            --no-audit) run_audit=0; shift ;;
            *) shift ;;
        esac
    done

    if [[ "$DRY_RUN" == "1" && -f "/tmp/msmtprc.preview" ]]; then
        config_file="/tmp/msmtprc.preview"
        log_info "smtp_test: using preview config $config_file"
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "smtp_test: configuration file not found at $config_file"
        return 1
    fi

    if [[ -z "$target_email" ]]; then
        read -rp "Enter target email address for test: " target_email
    fi

    if ! [[ "$target_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        log_error "smtp_test: invalid target email address: $target_email"
        return 1
    fi

    # Auditoría previa opcional
    if [[ "$run_audit" -eq 1 ]]; then
        log_info "smtp_test: running smtp_audit.sh before sending..."
        if ! ACCOUNT_CONFIG_FILE="$config_file" "$SCRIPT_DIR/smtp_audit.sh" --report; then
            log_error "smtp_test: audit failed — aborting test"
            return 1
        fi
    fi

    # Obtener cuentas usando list_accounts()
    local accounts
    if [[ -n "$specific_account" ]]; then
        accounts=("$specific_account")
    else
        mapfile -t accounts < <(list_accounts)
    fi

    local errors=0
    local json_data="["
    for acc in "${accounts[@]}"; do
        if ! send_test_email "$acc" "$target_email" "$config_file"; then
            ((errors++))
            json_data+="{\"account\":\"$acc\",\"status\":\"fail\"},"
            if [[ "$strict" -eq 1 ]]; then
                log_error "smtp_test: strict mode enabled — aborting on first failure"
                set_state "smtp_test" "fail"
                [[ "$json_out" -eq 1 ]] && echo "${json_data%,}]"
                return 1
            fi
        else
            json_data+="{\"account\":\"$acc\",\"status\":\"ok\"},"
        fi
    done
    json_data="${json_data%,}]"

    set_state "smtp_test_total" "${#accounts[@]}"
    set_state "smtp_test_errors" "$errors"

    if (( errors > 0 )); then
        set_state "smtp_test" "fail"
    else
        set_state "smtp_test" "ok"
    fi

    [[ "$json_out" -eq 1 ]] && echo "$json_data"

    (( errors > 0 )) && return 1 || return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if ! smtp_test_main "$@"; then
        exit 1
    fi
fi
