#!/usr/bin/env bash
# ============================================================
# smtp_audit.sh - Audit msmtp configuration against presets
# ============================================================
# Features:
# - Loads smtp_presets.sh and msmtprc
# - Uses list_accounts.sh to get accounts
# - Validates host/port/tls/auth/from per account
# - Checks against standard ports
# - Detects unused presets
# - Marks custom accounts
# - Optionally tests SMTP connectivity (--test or SMTP_AUDIT_TEST=1)
# - Optionally checks TLS certificate expiry
# - Summarizes results in table or JSON (--json)
# - Saves JSON to file if --json (default /tmp/smtp_audit_report.json)
# - Integrates with account_duplicates_validator.sh
# - Report mode (--report) never fails the process
# ============================================================

set -euo pipefail

source "$(dirname "$0")/utils.sh"
source "$(dirname "$0")/smtp_presets.sh"
source "$(dirname "$0")/list_accounts.sh"

load_env_file() {
    local env_file=""
    if [[ -f "$(dirname "$0")/.env" ]]; then
        env_file="$(dirname "$0")/.env"
    elif [[ -f ".env" ]]; then
        env_file=".env"
    fi
    if [[ -n "$env_file" ]]; then
        log_info "smtp_audit: loading environment variables from $env_file"
        set -a
        source "$env_file"
        set +a
    fi
}

test_smtp_connectivity() {
    local account="$1" host="$2" port="$3" tls="$4"
    log_info "Testing SMTP connectivity for account '$account' ($host:$port, TLS=$tls)"

    if command -v msmtp >/dev/null 2>&1; then
        if ! msmtp --serverinfo --host="$host" --port="$port" --tls="$tls" --timeout=5 >/dev/null 2>&1; then
            log_error "Connectivity test failed for '$account' via msmtp"
            return 1
        fi
    elif command -v openssl >/dev/null 2>&1; then
        local proto_arg=""
        [[ "${tls,,}" == "on" ]] && proto_arg="-starttls smtp"
        if ! echo QUIT | openssl s_client -connect "${host}:${port}" $proto_arg -crlf -ign_eof -quiet >/dev/null 2>&1; then
            log_error "Connectivity test failed for '$account' via openssl"
            return 1
        fi
    else
        log_warn "No msmtp or openssl available for connectivity test"
        return 0
    fi

    log_info "Connectivity test passed for '$account'"
    return 0
}

check_tls_expiry() {
    local host="$1" port="$2"
    if ! command -v openssl >/dev/null 2>&1; then
        log_warn "openssl not available for TLS expiry check"
        return 0
    fi
    local expiry
    expiry=$(echo | openssl s_client -connect "${host}:${port}" -starttls smtp 2>/dev/null \
             | openssl x509 -noout -enddate 2>/dev/null \
             | cut -d= -f2 || true)
    if [[ -n "$expiry" ]]; then
        local exp_ts now_ts days_left
        exp_ts=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
        now_ts=$(date +%s)
        if (( exp_ts > 0 )); then
            days_left=$(( (exp_ts - now_ts) / 86400 ))
            if (( days_left < 0 )); then
                log_error "TLS certificate for $host:$port has expired ($expiry)"
                return 1
            elif (( days_left < 30 )); then
                log_warn "TLS certificate for $host:$port expires soon ($expiry)"
            fi
        fi
    fi
    return 0
}

unique_bases_from_presets() {
    printf "%s\n" "${!SMTP_PRESETS[@]}" | sed 's/_[^_]*$//' | sort -u
}

audit_smtp_config() {
    section "Auditing msmtp configuration"

    load_env_file

    local strict="${STRICT_VALIDATION:-1}"
    local do_test="${SMTP_AUDIT_TEST:-0}"
    local json_out=0
    local report_mode=0
    local json_file="${SMTP_AUDIT_JSON_FILE:-/tmp/smtp_audit_report.json}"

    for arg in "$@"; do
        [[ "$arg" == "--test" ]] && do_test=1
        [[ "$arg" == "--json" ]] && json_out=1
        [[ "$arg" == "--report" ]] && report_mode=1
    done

    local config_file="${ACCOUNT_CONFIG_FILE:-/etc/msmtprc}"
    if [[ "${DRY_RUN:-0}" == "1" && -f "/tmp/msmtprc.preview" ]]; then
        config_file="/tmp/msmtprc.preview"
        log_info "smtp_audit: using preview config $config_file"
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "smtp_audit: configuration file not found at $config_file"
        return 1
    fi

    local errors=0 warnings=0 total=0
    local json_data="["
    declare -A used_presets_map=()

    if [[ "$json_out" -ne 1 ]]; then
        printf "\n%-20s %-30s %-6s %-5s %-5s %-10s %-8s\n" "ACCOUNT" "HOST" "PORT" "TLS" "AUTH" "STATUS" "PRESET"
        printf "%-20s %-30s %-6s %-5s %-5s %-10s %-8s\n" "-------" "----" "----" "---" "----" "------" "------"
    fi

    local accounts
    if ! accounts=$(list_accounts); then
        log_error "smtp_audit: unable to obtain account list"
        return 1
    fi

    for acc in $accounts; do
        local host port tls auth from
        host=$(awk -v a="$acc" '$1=="account" && $2==a {f=1;next} f && $1=="host"{print $2;f=0}' "$config_file")
        port=$(awk -v a="$acc" '$1=="account" && $2==a {f=1;next} f && $1=="port"{print $2;f=0}' "$config_file")
        tls=$(awk -v a="$acc" '$1=="account" && $2==a {f=1;next} f && $1=="tls"{print $2;f=0}' "$config_file")
        auth=$(awk -v a="$acc" '$1=="account" && $2==a {f=1;next} f && $1=="auth"{print $2;f=0}' "$config_file")
        from=$(awk -v a="$acc" '$1=="account" && $2==a {f=1;next} f && $1=="from"{print $2;f=0}' "$config_file")

        ((total++))
        local status="ok"
        local preset_match="custom"

        for p in $(unique_bases_from_presets); do
            if [[ "$host" == "${SMTP_PRESETS[${p}_host]:-}" && "$port" == "${SMTP_PRESETS[${p}_port]:-}" ]]; then
                preset_match="$p"
                used_presets_map["$p"]=1
                break
            fi
        done

        if ! [[ "$port" =~ ^[0-9]{2,5}$ ]]; then
            log_error "Account '$acc' has invalid port: $port"
            status="error"; ((errors++))
        elif [[ ! "$port" =~ ^(25|465|587|2525)$ ]]; then
            if [[ "$strict" -eq 1 ]]; then
                log_error "Account '$acc' uses non-standard port: $port"
                status="error"; ((errors++))
            else
                log_warn "Account '$acc' uses non-standard port: $port"
                ((warnings++))
            fi
        fi

        for key in tls auth; do
            local val=$(eval echo \$$key | tr '[:upper:]' '[:lower:]')
            if [[ "$val" != "on" && "$val" != "off" ]]; then
                log_error "Account '$acc' has invalid $key value: $val"
                status="error"; ((errors++))
            fi
        done

        if ! [[ "$from" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            log_error "Account '$acc' has invalid from address: ${from:-<empty>}"
            status="error