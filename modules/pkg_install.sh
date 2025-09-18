#!/usr/bin/env bash
# ============================================================
# pkg_install.sh - Install and verify required packages (Ubuntu Server)
# ============================================================
# Features:
# - Loads optional .env for configurable package list
# - Supports DRY_RUN=1 to preview actions without applying
# - Uses consistent logging and state recording
# ============================================================

source "$(dirname "$0")/utils.sh"

# Minimum msmtp version required (optional check)
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
        log_info "pkg_install: loading environment variables from $env_file"
        set -a
        source "$env_file"
        set +a
    fi
}

check_connectivity() {
    section "Checking internet connectivity"
    if ping -c1 -W2 archive.ubuntu.com >/dev/null 2>&1; then
        log_info "pkg_install: Internet connectivity OK."
        set_state "connectivity" "ok"
    else
        log_warn "pkg_install: No connectivity to archive.ubuntu.com. apt-get update may fail."
        set_state "connectivity" "fail"
    fi
}

is_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

install_dependencies() {
    section "Installing required packages"

    # Load .env to allow overriding package list
    load_env_file

    # Default package list, can be overridden by PKG_LIST in .env
    local packages=(${PKG_LIST:-msmtp msmtp-mta mailutils ca-certificates apparmor})

    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "DRY_RUN enabled — would install packages: ${packages[*]}"
        set_state "dependencies_list" "${packages[*]}"
        return 0
    fi

    safe_run "update package index" apt-get update -y

    for pkg in "${packages[@]}"; do
        if is_package_installed "$pkg"; then
            log_info "pkg_install: Package '$pkg' already installed."
        else
            safe_run "install $pkg" apt-get install -y "$pkg"
            log_info "pkg_install: Package '$pkg' installed."
        fi
    done

    require_command msmtp
    require_command mail

    set_state "dependencies" "installed"
    set_state "dependencies_list" "${packages[*]}"
}

check_ca_bundle() {
    section "Verifying CA certificates bundle"

    local ca_bundle="/etc/ssl/certs/ca-certificates.crt"

    if [[ ! -f "$ca_bundle" ]]; then
        log_warn "pkg_install: CA bundle not found at $ca_bundle. Attempting to reinstall ca-certificates."
        [[ "$DRY_RUN" != "1" ]] && apt-get install -y ca-certificates || log_info "DRY_RUN: would install ca-certificates"
    fi

    if [[ -f "$ca_bundle" ]]; then
        log_info "pkg_install: CA certificates bundle verified at $ca_bundle"
        set_state "ca_bundle" "ok"
    else
        abort "pkg_install: CA bundle still missing after installation. Cannot proceed."
    fi
}

check_msmtp_version() {
    section "Checking msmtp version"
    local current_version
    current_version=$(msmtp --version | awk 'NR==1{print $2}')
    log_info "pkg_install: Detected msmtp version: $current_version"

    if [[ "$(printf '%s\n' "$MIN_MSMTP_VERSION" "$current_version" | sort -V | head -n1)" != "$MIN_MSMTP_VERSION" ]]; then
        log_warn "pkg_install: msmtp version ($current_version) is older than required ($MIN_MSMTP_VERSION). Some features may not work."
        set_state "msmtp_version" "old"
    else
        set_state "msmtp_version" "ok"
    fi
}

check_apparmor_status() {
    section "Checking AppArmor status"

    if ! command -v apparmor_status >/dev/null 2>&1; then
        log_warn "pkg_install: apparmor_status command not found. AppArmor may not be supported in this environment."
        set_state "apparmor" "unsupported"
        return 0
    fi

    if ! systemctl is-active --quiet apparmor; then
        log_warn "pkg_install: AppArmor service is not active."
        set_state "apparmor" "inactive"
    else
        log_info "pkg_install: AppArmor service is active."
        set_state "apparmor" "active"
    fi

    if ! apparmor_status | grep -q "msmtp"; then
        log_warn "pkg_install: No AppArmor profile found for msmtp."
        set_state "apparmor_profile" "missing"
    else
        log_info "pkg_install: AppArmor profile for msmtp is loaded."
        set_state "apparmor_profile" "loaded"
    fi
}

pkg_install_summary() {
    section "Package installation summary"
    log_info "Connectivity: $(get_state connectivity)"
    log_info "Dependencies: $(get_state dependencies)"
    log_info "CA bundle:    $(get_state ca_bundle)"
    log_info "msmtp ver:    $(get_state msmtp_version)"
    log_info "AppArmor:     $(get_state apparmor)"
    log_info "Profile:      $(get_state apparmor_profile)"
    log_info "Pkg list:     $(get_state dependencies_list)"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_connectivity
    install_dependencies
    check_ca_bundle
    check_msmtp_version
    check_apparmor_status
    pkg_install_summary
fi
