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

set -Eeuo pipefail

# Resolve this script's directory and load utilities
SCRIPT_DIR="$(get_script_dir)"
source "$SCRIPT_DIR/utils.sh"
# shellcheck source=modules/smtp_presets.sh
source "$SCRIPT_DIR/smtp_presets.sh"

MIN_MSMTP_VERSION="1.8.0"

# ----- Helpers -----

# Safely fetch ACCOUNT_i_* vars via indirection
get_account_env() {
    local idx="$1" key="$2"
    local var="ACCOUNT_${idx}_$key"
    printf '%s' "${!var:-}"
}

# Normalize TLS/Auth to 'on'/'off'
normalize_on_off() {
    local val="${1:-}"
    val="$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')"
    [[ "$val" == "on" || "$val" == "off" ]] || val="on"
    printf '%s' "$val"
}

# Present a menu and store selection in a referenced var
select_option() {
    local prompt="$1"
    local -n options="$2"
    local -n result="$3"

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

# Load per-account .env if present (env-accounts/<account>.env or .env.<account>)
load_env_for_account() {
    local account_name="$1"
    local env_file=""
    local base_dir
    base_dir="$(get_script_dir)"  # robust against CWD and symlinks

    if [[ -f "$base_dir/../env-accounts/${account_name}.env" ]]; then
        env_file="$base_dir/../env-accounts/${account_name}.env"
    elif [[ -f "env-accounts/${account_name}.env" ]]; then
        env_file="env-accounts/${account_name}.env"
    elif [[ -f "$base_dir/.env.${account_name}" ]]; then
        env_file="$base_dir/.env.${account_name}"
    elif [[ -f ".env.${account_name}" ]]; then
        env_file=".env.${account_name}"
    fi

    if [[ -n "$env_file" ]]; then
        log_info "Loading environment variables for account '$account_name' from $env_file"
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
        set +a
    fi
}

# Ensure smtp_presets integrity (expects SMTP_PRESETS associative array)
validate_smtp_presets() {
    log_info "Validating smtp_presets.sh integrity..."
    local keys_missing=0

    # Build base keys by stripping the last _suffix
    local base_keys
    base_keys=$(printf "%s\n" "${!SMTP_PRESETS[@]}" | sed 's/_[^_]*$//' | sort -u)

    local base suffix
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

# ----- Main generator -----
generate_msmtprc() {
    section "Generating msmtp configuration"

    # Load global .env if available
    load_env_file

    # Check msmtp availability and version
    require_command "msmtp"
    if ! version_gte "$(msmtp --version | awk 'NR==1{print $3}')" "$MIN_MSMTP_VERSION"; then
        log_error "msmtp >= $MIN_MSMTP_VERSION is required"
        exit 1
    fi

    validate_smtp_presets

    local config_file="/etc/msmtprc"
    local secrets_dir="/etc/msmtp.secrets"

    require_root
    require_writable_dir "/etc"
    install -d -m 700 -o root -g root "$secrets_dir"

    if [[ "${DRY_RUN:-0}" != "1" ]]; then
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
    if [[ "${NON_INTERACTIVE:-0}" != "1" ]]; then
        prompt_env_or_ask count "How many SMTP accounts do you want to configure?" "$count"
    fi
    validate_regex "$count" '^[0-9]+$' "Invalid number of accounts"

    declare -a accounts=()
    declare -A seen_key=()  # to detect duplicates host|port|user
    local i

    for ((i=1; i<=count; i++)); do
        section "Configuring account $i"

        local account preset host port tls auth from user passwd_file preset_origin
        local env_host env_port env_tls env_auth env_from env_user

        # Pull defaults from env (ACCOUNT_i_*)
        env_host="$(get_account_env "$i" HOST)"
        env_port="$(get_account_env "$i" PORT)"
        env_tls="$(get_account_env "$i" TLS)"
        env_auth="$(get_account_env "$i" AUTH)"
        env_from="$(get_account_env "$i" FROM)"
        env_user="$(get_account_env "$i" USER)"

        account="$(get_account_env "$i" NAME)"
        if [[ -z "$account" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
            prompt_env_or_ask account "Account name (e.g. gmail, work)" "account$i"
        fi
        validate_regex "$account" '^[a-zA-Z0-9._-]+$' "Invalid account name"
        accounts+=("$account")

        load_env_for_account "$account"

        # Determine preset list
        local preset_options
        preset_options="$(printf "%s\n" "${!SMTP_PRESETS[@]}" | sed 's/_[^_]*$//' | sort -u | tr '\n' ' ')"
        preset="$(get_account_env "$i" PRESET)"
        if [[ -z "$preset" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
            prompt_env_or_ask preset "Choose provider (${preset_options} custom)" "custom"
        fi

        if [[ "$preset" != "custom" && -n "${SMTP_PRESETS[${preset}_host]:-}" ]]; then
            preset_origin="official"
            if [[ "$preset" == "amazonses" ]]; then
                local aws_region
                aws_region="$(get_account_env "$i" AWS_REGION)"
                if [[ -z "$aws_region" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
                    prompt_env_or_ask aws_region "Enter AWS SES region (e.g. us-east-1)" "us-east-1"
                fi
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
            if [[ -z "$env_host" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
                prompt_env_or_ask host "SMTP host for '$account'" "$env_host"
            else
                host="$env_host"
            fi
            validate_regex "$host" '^([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$' "Invalid SMTP host"

            if [[ "${STRICT_VALIDATION:-1}" -eq 1 ]]; then
                local ports=("25" "465" "587" "2525")
                select_option "Select SMTP port:" ports port
                local tls_opts=("on" "off")
                select_option "Use TLS?" tls_opts tls
                local auth_opts=("on" "off")
                select_option "Use authentication?" auth_opts auth
            else
                if [[ -z "$env_port" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
                    prompt_env_or_ask port "SMTP port for '$account'" "$env_port"
                else
                    port="$env_port"
                fi
                validate_regex "$port" '^[0-9]{2,5}$' "Invalid SMTP port"

                if [[ -z "$env_tls" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
                    prompt_env_or_ask tls "Use TLS? (on/off)" "$env_tls"
                else
                    tls="$env_tls"
                fi
                if [[ -z "$env_auth" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
                    prompt_env_or_ask auth "Use authentication? (on/off)" "$env_auth"
                else
                    auth="$env_auth"
                fi
            fi
        fi

        tls="$(normalize_on_off "$tls")"
        auth="$(normalize_on_off "$auth")"

        if [[ -z "$env_from" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
            prompt_env_or_ask from "Email address for '$account'" "$env_from"
        else
            from="$env_from"
        fi
        validate_regex "$from" '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' "Invalid email address"

        if [[ -z "$env_user" || "${NON_INTERACTIVE:-0}" != "1" ]]; then
            prompt_env_or_ask user "SMTP username for '$account'" "$env_user"
        else
            user="$env_user"
        fi

        # Duplicate detection
        local sig="${host}|${port}|${user}"
        if [[ -n "${seen_key[$sig]:-}" ]]; then
            log_warn "Duplicate account detected with same host|port|user as '${seen_key[$sig]}'."
        else
            seen_key[$sig]="$account"
        fi

        # Secrets handling: expect PASSWORD or PASS_FILE; store as file under /etc/msmtp.secrets
        local password pass_file
        pass_file="$(get_account_env "$i" PASS_FILE)"
        password="$(get_account_env "$i" PASSWORD)"

        if [[ -z "$pass_file" && -z "$password" && "${NON_INTERACTIVE:-0}" != "1" ]]; then
            prompt_env_or_ask password "Enter SMTP password for '$account' (input will be echoed)" ""
        fi

        if [[ -n "$password" ]]; then
            passwd_file="$secrets_dir/${account}.pass"
            umask 077
            printf '%s' "$password" > "$passwd_file"
            chmod 600 "$passwd_file"
            chown root:root "$passwd_file"
        elif [[ -n "$pass_file" ]]; then
            if [[ ! -r "$pass_file" ]]; then
                log_error "PASS_FILE not readable: $pass_file"
                exit 1
            fi
            passwd_file="$secrets_dir/${account}.pass"
            umask 077
            cat "$pass_file" > "$passwd_file"
            chmod 600 "$passwd_file"
            chown root:root "$passwd_file"
        else
            # Allow accounts without auth if auth=off
            if [[ "$auth" == "on" ]]; then
                log_error "No password provided for '$account' and auth=on"
                exit 1
            fi
            passwd_file=""
        fi

        # Write account section
        {
            echo "# --- account: $account (preset: ${preset:-custom}, origin: ${preset_origin:-custom}) ---"
            echo "account       $account"
            echo "host          $host"
            echo "port          $port"
            echo "tls           $tls"
            echo "auth          $auth"
            echo "from          $from"
            echo "user          $user"
            if [[ "$auth" == "on" && -n "$passwd_file" ]]; then
                echo "passwordeval  cat $passwd_file"
            fi
            echo
        } >> "$config_file"
    done

    # Set default account
    local default_account="${DEFAULT_ACCOUNT:-${accounts[0]}}"
    {
        echo "account default : $default_account"
    } >> "$config_file"

    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        log_info "Preview generated: $config_file"
    else
        chmod 600 "$config_file"
        chown root:root "$config_file"
        log_success "msmtp configuration written to: $config_file"
    fi

    # Post-generation audit and optional test
    if command -v bash >/dev/null 2>&1 && [[ -x "$SCRIPT_DIR/smtp_audit.sh" ]]; then
        log_info "Running SMTP audit..."
        bash "$SCRIPT_DIR/smtp_audit.sh" || log_warn "smtp_audit reported issues"
    fi
    if [[ "${RUN_SMTP_TEST:-0}" == "1" && -x "$SCRIPT_DIR/smtp_test.sh" ]]; then
        log_info "Running SMTP test..."
        bash "$SCRIPT_DIR/smtp_test.sh" || log_warn "smtp_test reported issues"
    fi

    section "Done"
}

# ----- Entry point -----
generate_msmtprc "$@"
