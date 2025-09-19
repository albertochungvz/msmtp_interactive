#!/usr/bin/env bash
# ============================================================
# smtp_presets_validator.sh - Validate smtp_presets.sh integrity
# ============================================================
# Validates:
# - Required keys: host, port, tls, auth
# - Preset name format: [a-z0-9_-]+
# - Port in standard list (25, 465, 587, 2525)
# - tls/auth values are 'on' or 'off'
# - Summary table and counts
# ============================================================

# Resolve this script's directory and load utilities
SCRIPT_DIR="$(get_script_dir)"
source "$SCRIPT_DIR/utils.sh"

validate_smtp_presets() {
    section "Validating smtp_presets.sh integrity"

    load_env_file

    local presets_file="${SMTP_PRESETS_FILE:-$SCRIPT_DIR/smtp_presets.sh}"
    local strict="${STRICT_VALIDATION:-1}"
    local errors=0
    local warnings=0
    local valid_count=0
    local invalid_count=0

    if [[ ! -f "$presets_file" ]]; then
        log_error "smtp_presets_validator: presets file not found at $presets_file"
        return 1
    fi

    source "$presets_file"

    local base_keys
    base_keys=$(printf "%s\n" "${!SMTP_PRESETS[@]}" | sed 's/_[^_]*$//' | sort -u)

    printf "\n%-20s %-30s %-6s %-5s %-5s\n" "PRESET" "HOST" "PORT" "TLS" "AUTH"
    printf "%-20s %-30s %-6s %-5s %-5s\n" "------" "----" "----" "---" "----"

    for base in $base_keys; do
        local missing=()
        for suffix in host port tls auth; do
            if [[ -z "${SMTP_PRESETS[${base}_${suffix}]:-}" ]]; then
                missing+=("$suffix")
            fi
        done

        local name_ok=1
        if ! [[ "$base" =~ ^[a-z0-9_-]+$ ]]; then
            log_error "Preset '$base' has invalid name (only [a-z0-9_-] allowed)"
            name_ok=0
        fi

        local host="${SMTP_PRESETS[${base}_host]}"
        local port="${SMTP_PRESETS[${base}_port]}"
        local tls="${SMTP_PRESETS[${base}_tls]}"
        local auth="${SMTP_PRESETS[${base}_auth]}"

        local port_ok=1
        if ! [[ "$port" =~ ^[0-9]{2,5}$ ]]; then
            log_error "Preset '$base' has invalid port: $port"
            port_ok=0
        elif [[ ! "$port" =~ ^(25|465|587|2525)$ ]]; then
            if [[ "$strict" -eq 1 ]]; then
                log_error "Preset '$base' uses non-standard port: $port"
                port_ok=0
            else
                log_warn "Preset '$base' uses non-standard port: $port"
                ((warnings++))
            fi
        fi

        local tls_ok=1
        local auth_ok=1
        for key in tls auth; do
            local val="${SMTP_PRESETS[${base}_${key}]}"
            val=$(echo "$val" | tr '[:upper:]' '[:lower:]')
            if [[ "$val" != "on" && "$val" != "off" ]]; then
                log_error "Preset '$base' has invalid $key value: $val (should be 'on' or 'off')"
                [[ "$key" == "tls" ]] && tls_ok=0
                [[ "$key" == "auth" ]] && auth_ok=0
            fi
        done

        if (( ${#missing[@]} > 0 )) || [[ $name_ok -eq 0 ]] || [[ $port_ok -eq 0 ]] || [[ $tls_ok -eq 0 ]] || [[ $auth_ok -eq 0 ]]; then
            ((errors++))
            ((invalid_count++))
        else
            ((valid_count++))
        fi

        printf "%-20s %-30s %-6s %-5s %-5s\n" "$base" "$host" "$port" "$tls" "$auth"
    done

    set_state "smtp_presets_valid_count" "$valid_count"
    set_state "smtp_presets_invalid_count" "$invalid_count"

    if (( errors > 0 )); then
        log_warn "smtp_presets_validator: $errors issue(s) found in presets."
        set_state "smtp_presets_validation" "fail"
        if [[ "$DRY_RUN" != "1" ]]; then
            return 1
        fi
    else
        log_info "smtp_presets_validator: all presets passed validation."
        set_state "smtp_presets_validation" "ok"
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if ! validate_smtp_presets; then
        exit 1
    fi
fi
