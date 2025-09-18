#!/usr/bin/env bash
# ============================================================
# config_generator.sh - Generate /etc/msmtprc configuration
# ============================================================
# Features:
# - Loads global .env and per-account env-accounts/<account>.env or .env.<account>
# - Validates smtp_presets.sh integrity before use
# - Normalizes TLS/Auth values to 'on'/'off'
# - Adds extended comment in /etc/msmtprc indicating preset origin
# - Supports DRY_RUN=1 to preview configuration without applying
# - Works in interactive and non-interactive modes
# - Uses consistent logging and state recording
# - In STRICT_VALIDATION=1, forces selection of port/tls/auth from predefined lists
# - Validates duplicate accounts (host, port, user) before finalizing
# - Runs smtp_audit.sh and optionally smtp_test.sh at the end
# ============================================================

source "$(dirname "$0")/utils.sh"
source "$(dirname "$0")/smtp_presets.sh"

MIN_MSMTP_VERSION="1.8.0"

# --- Load .env global if present ---
load_env_file() {
    local env_file=""
    if [[ -f "$(dirname "$0")/.env" ]]; then
        env_file="$(dirname "$0")/.env"
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

# --- Load per-account env file if present ---
load_env_for_account() {
    local account_name="$1"
    local env_file=""
    if [[ -f "$(dirname "$0")/../env-accounts/${account_name}.env" ]]; then
        env_file="$(dirname "$0")/../env-accounts/${account_name}.env"
    elif [[ -f "env-accounts/${account_name}.env" ]]; then
        env_file="env-accounts/${account_name}.env"
    elif [[ -f "$(dirname "$0")/.env.${account_name}" ]]; then
        env_file="$(dirname "$0")/.env.${account_name}"
    elif [[ -f ".env.${account_name}" ]]; then
        env_file=".env.${account_name}"
    fi
    if [[ -n "$env_file" ]]; then
        log_info "Loading environment variables for account '$account_name' from $env_file"
        set -a
        source "$env_file"
        set +a
    fi
}

# --- Validate smtp_presets.sh integrity ---
validate_smtp_presets() {
    log_info "Validating smtp_presets.sh integrity..."
    local keys_missing=0
    local base_keys
    base_keys=$(printf "%s\n" "${!SMTP_PRESETS[@]}" | sed 's/_[^_]*$//' | sort -u)
    for base in $base_keys; do
        for suffix in host port tls auth; do
            if [[ -z "${SMTP_PRESETS[${base}_${suffix}]:-}" ]]; then
                log_error "Preset '$base' missing key '${base}_${suffix}'"
                keys_missing=1
            fi
        done
    done
    if [[ $keys_missing -ne 0 ]]; then
        log_error "smtp_presets.sh integrity check failed."
        exit 1
    fi
}

# --- Normalize TLS/Auth values ---
normalize_on_off() {
    local val="$1"
    val=$(echo "$val" | tr '[:upper:]' '[:lower:]')
    [[ "$val" != "on" && "$val" != "off" ]] && val="on"
    echo "$val"
}

# --- Option selector ---
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

# --- Main generator ---
generate_msmtprc() {
    section "Generating msmtp configuration"

    load_env_file
    validate_smtp_presets

    local config_file="/etc/msmtprc"
    local secrets_dir="/etc/msmtp.secrets"

    require_root
    require_writable_dir "/etc"
    install -d -m 700 -o root -g root "$secrets_dir"

    if [[ "$DRY_RUN" != "1" ]]; then
        backup_file "$config_file"
    else
        config_file="/tmp/msmtprc.preview"
        log_info "DRY_RUN enabled — writing preview to $config_file"
    fi

    {
        echo "# msmtp configuration generated on $(date)"
        echo "defaults"
        echo "auth           on"
        echo "tls            on"
        echo "tls_trust_file /etc/ssl/certs/ca-certificates.crt"
        echo
    } > "$config_file"

    local count="${COUNT:-1}"
    [[ "$NON_INTERACTIVE" != "1" ]] && prompt_env_or_ask count "How many SMTP accounts do you want to configure?" "$count"
    validate_regex "$count" '^[0-9]+$' "Invalid number of accounts"

    declare -a accounts

    for ((i=1; i<=count; i++)); do
        section "Configuring account $i"

        local account preset host port tls auth from user passwd_file preset_origin
        local env_prefix="ACCOUNT_${i}_"

        account="${!env_prefix"NAME"}"
        [[ -z "$account" || "$NON_INTERACTIVE" != "1" ]] && prompt_env_or_ask account "Account name (e.g. gmail, work)" "account$i"

        load_env_for_account "$account"

        local preset_options
        preset_options="$(printf "%s\n" "${!SMTP_PRESETS[@]}" | sed 's/_[^_]*$//' | sort -u | tr '\n' ' ' | sed 's/ $//')"

        preset="${!env_prefix"PRESET"}"
        [[ -z "$preset" || "$NON_INTERACTIVE" != "1" ]] && prompt_env_or_ask preset "Choose provider (${preset_options} custom)" "custom"

        if [[ "$preset" != "custom" && -n "${SMTP_PRESETS[${preset}_host]}" ]]; then
            preset_origin="official"
            if [[ "$preset" == "amazonses" ]]; then
                local aws_region="${!env_prefix"AWS_REGION"}"
                [[ -z "$aws_region" || "$NON_INTERACTIVE" != "1" ]] && prompt_env_or_ask aws_region "Enter AWS SES region (e.g. us-east-1)" "us-east-1"
                host="email-smtp.${aws_region}.amazonaws.com"
                port="${SMTP_PRESETS[${preset}_port]}"
                tls="${SMTP_PRESETS[${preset}_tls]}"
                auth="${SMTP_PRESETS[${preset}_auth]}"
            else
                host="${SMTP_PRESETS[${preset}_host]}"
                port="${SMTP_PRESETS[${preset}_port]}"
                tls="${SMTP_PRESETS[${preset}_tls]}"
                auth="${SMTP_PRESETS[${preset}_auth]}"
            fi
        else
            preset_origin="custom"
            prompt_env_or_ask host "SMTP host for '$account'" "${!env_prefix"HOST"}"
            validate_regex "$host" '^([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$' "Invalid SMTP host"

            if [[ "${STRICT_VALIDATION:-1}" -eq 1 ]]; then
                local ports=("25" "465" "587" "2525")
                select_option "Select SMTP port:" ports port
                local tls_opts=("on" "off")
                select_option "Use TLS?" tls_opts tls
                local auth_opts=("on" "off")
                select_option "Use authentication?" auth_opts auth
            else
                prompt_env_or_ask port "SMTP port for '$account'" "${!env_prefix"PORT"}"
                validate_regex "$port" '^[0-9]{2,5}$' "Invalid SMTP port"
                prompt_env_or_ask tls "Use TLS? (on/off)" "${!env_prefix"TLS"}"
                prompt_env_or_ask auth "Use authentication? (on/off)" "${!env_prefix"AUTH"}"
            fi
        fi

        tls=$(normalize_on_off "$tls")
        auth=$(normalize_on_off "$auth")

        prompt_env_or_ask from "Email address for '$account'" "${!env_prefix"FROM"}"
        prompt_env_or_ask user "SMTP username for '$account'" "${!env_prefix"USER"}"

