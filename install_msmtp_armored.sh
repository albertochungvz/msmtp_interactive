#!/usr/bin/env bash
set -Eeuo pipefail

# Define SCRIPT_DIR early so it's always set
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ========= Security and error handling utilities =========

abort () {
    echo "ERROR: $*" >&2
    exit 1
}

trap 'abort "Failed on line $LINENO (command: $BASH_COMMAND)"' ERR

require_root () {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        abort "Run this script as root (sudo)."
    fi
}

prompt () {
    local var="$1" msg="$2" def="${3-}"
    local input
    if [[ -n "$def" ]]; then
        read -r -p "$msg [$def]: " input || abort "Input canceled"
        input="${input:-$def}"
    else
        read -r -p "$msg: " input || abort "Input canceled"
    fi
    [[ -n "$input" ]] || abort "Value cannot be empty."
    printf -v "$var" '%s' "$input"
}

prompt_secret_to_file () {
    local dest="$1"
    local prompt_msg="$2"

    install -d -m 700 -o root -g root "$(dirname "$dest")"

    local HIST_WAS_ON=1
    if set -o | grep -q 'history[[:space:]]\+on'; then
        set +o history
    else
        HIST_WAS_ON=0
    fi

    local secret=''
    while true; do
        read -r -s -p "$prompt_msg: " secret || abort "Input canceled"
        echo
        [[ -n "$secret" ]] && break
        echo "Value cannot be empty."
    done

    umask 177
    printf '%s' "$secret" > "$dest"
    chown root:root "$dest"
    chmod 600 "$dest"
    secret=''

    if [[ $HIST_WAS_ON -eq 1 ]]; then
        set -o history
    fi
}

ensure_pkg () {
    local pkgs=("$@")
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
}

# ========= Improved AppArmor handling =========

ensure_apparmor_enforce () {
    echo "==> Checking AppArmor availability..."

    APPARMOR_STATUS="skipped"

    if ! command -v aa-status >/dev/null 2>&1; then
        echo "⚠️  AppArmor is not installed on this system. Skipping configuration."
        APPARMOR_STATUS="not_installed"
        return 0
    fi

    if ! aa-status >/dev/null 2>&1; then
        echo "⚠️  AppArmor kernel module is not available in this environment."
        echo "ℹ️  This is common in Docker containers without AppArmor support."
        echo "➡️  Skipping service start, continuing with the rest of the installation."
        APPARMOR_STATUS="kernel_unavailable"
        return 0
    fi

    echo "==> Enabling and starting AppArmor..."
    if ! systemctl is-enabled apparmor >/dev/null 2>&1; then
        if ! systemctl enable apparmor; then
            echo "❌  Failed to enable AppArmor."
            APPARMOR_STATUS="enable_failed"
            return 1
        fi
    fi

    if ! systemctl is-active apparmor >/dev/null 2>&1; then
        if ! systemctl start apparmor; then
            echo "❌  Failed to start AppArmor service. Check system configuration."
            APPARMOR_STATUS="start_failed"
            return 1
        fi
    fi

    if command -v aa-enforce >/dev/null 2>&1 && [ -e /usr/bin/msmtp ]; then
        echo "==> Applying AppArmor profile for msmtp..."
        if aa-enforce /usr/bin/msmtp; then
            APPARMOR_STATUS="profile_applied"
        else
            echo "⚠️  Failed to apply msmtp profile."
            APPARMOR_STATUS="profile_failed"
        fi
    else
        APPARMOR_STATUS="service_started"
    fi

    echo "✅  AppArmor enabled and profile applied successfully."
}

# --- Version parsing patch ---
get_msmtp_version () {
    local raw out
    if ! raw="$(msmtp --version 2>/dev/null)"; then
        echo "0.0.0"
        return 0
    fi
    out="$(printf '%s\n' "$raw" | head -n1 | grep -Eo '[0-9]+(\.[0-9]+){1,2}' | head -n1)"
    [[ -n "$out" ]] && echo "$out" || echo "0.0.0"
}

msmtp_supports_from_fields () {
    local v
    v="$(get_msmtp_version)"
    if [[ "$v" =~ ^[0-9] ]]; then
        dpkg --compare-versions "$v" ge "1.8.8"
    else
        return 1
    fi
}

# ===================== Main flow =====================

require_root

echo "==> Installing required packages"
ensure_pkg ca-certificates msmtp msmtp-mta mailutils apparmor apparmor-utils

echo "==> Checking CA bundle"
if [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
    echo "CA bundle missing or empty. Running update-ca-certificates..."
    update-ca-certificates
fi

echo "==> Enabling AppArmor for msmtp (enforce)"
ensure_apparmor_enforce

echo "==> Creating log directory and file for msmtp"
install -d -m 750 -o root -g mail /var/log/msmtp
touch /var/log/msmtp/msmtp.log
chown root:mail /var/log/msmtp/msmtp.log
chmod 640 /var/log/msmtp/msmtp.log

echo "==> Configuring msmtp"
prompt "SMTP_SERVER" "Enter SMTP server"
prompt "SMTP_PORT" "Enter SMTP port (common: 465 for SSL/TLS, 587 for STARTTLS)"
prompt "SMTP_USER" "Enter SMTP username"
prompt_secret_to_file "/etc/msmtp.passwd" "Enter SMTP password"

# TLS mode validation
if [[ "$SMTP_PORT" == "465" ]]; then
    TLS_MODE="on"
    echo "ℹ️  Port 465 detected, forcing TLS mode 'on'."
else
    TLS_MODE="on"
fi

# Ask for full name if msmtp supports 'from' fields
if msmtp_supports_from_fields; then
    echo "==> msmtp supports 'from' fields with full name."
    prompt "SMTP_FROM_NAME" "Enter full name for 'From' field" "$SMTP_USER"
    SMTP_FROM="$SMTP_FROM_NAME <$SMTP_USER>"
else
    SMTP_FROM="$SMTP_USER"
fi

# Generate /etc/msmtprc from ./config/msmtprc.template
TEMPLATE_PATH="./config/msmtprc.template"
if [[ -f "$TEMPLATE_PATH" ]]; then
    echo "==> Generating /etc/msmtprc from template at $TEMPLATE_PATH"
    sed \
        -e "s|{{SMTP_SERVER}}|$SMTP_SERVER|g" \
        -e "s|{{SMTP_PORT}}|$SMTP_PORT|g" \
        -e "s|{{SMTP_USER}}|$SMTP_USER|g" \
        -e "s|{{SMTP_FROM}}|$SMTP_FROM|g" \
        -e "s|{{TLS_MODE}}|$TLS_MODE|g" \
        "$TEMPLATE_PATH" > /etc/msmtprc
else
    abort "msmtprc.template not found at $TEMPLATE_PATH"
fi

chmod 600 /etc/msmtprc
chown root:root /etc/msmtprc

# Test email sending
TEST_SCRIPT="$SCRIPT_DIR/tests/test_send_mail.sh"
if [[ -f "$TEST_SCRIPT" ]]; then
    chmod +x "$TEST_SCRIPT"
    echo "==> Sending test email"
    TEST_LOG="/var/log/msmtp/test_send_mail.log"
    mkdir -p "$(dirname "$TEST_LOG")"
    "$TEST_SCRIPT" | tee "$TEST_LOG"
else
    echo "⚠️  Test script not found at: $TEST_SCRIPT"
    echo "    Skipping test email."
fi

# ===== Final summary =====
echo
echo "===== INSTALLATION SUMMARY ====="
case "$APPARMOR_STATUS" in
    not_installed)
        echo "AppArmor: Not installed - skipped."
        ;;
    kernel_unavailable)
        echo "AppArmor: Kernel module unavailable - skipped."
        ;;
    enable_failed)
        echo "AppArmor: Failed to enable service."
        ;;
    start_failed)
        echo "AppArmor: Failed to start service."
        ;;
    profile_failed)
        echo "AppArmor: Service started, but profile application failed."
        ;;
    profile_applied)
        echo "AppArmor: Service started and profile applied successfully."
        ;;
    service_started)
        echo "AppArmor: Service started successfully."
        ;;
    skipped|*)
        echo "AppArmor: Skipped."
        ;;
esac
echo "================================"
echo "msmtp configuration completed."