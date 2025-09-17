#!/usr/bin/env bash
set -Eeuo pipefail

# ========= Security and error handling utilities =========
abort() {
  echo "ERROR: $*" >&2
  exit 1
}
trap 'abort "Failed on line $LINENO (command: $BASH_COMMAND)"' ERR

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    abort "Run this script as root (sudo)."
  fi
}

prompt() {
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

prompt_secret_to_file() {
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

ensure_pkg() {
  local pkgs=("$@")
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
}

ensure_apparmor_enforce() {
  systemctl is-enabled apparmor >/dev/null 2>&1 || systemctl enable apparmor
  systemctl is-active apparmor >/dev/null 2>&1 || systemctl start apparmor
  if command -v aa-enforce >/dev/null 2>&1 && [[ -e /usr/bin/msmtp ]]; then
    aa-enforce /usr/bin/msmtp || true
  fi
}

msmtp_supports_from_fields() {
  local v
  v="$(msmtp --version | awk 'NR==1{print $2}')" || echo "0.0.0"
  dpkg --compare-versions "$v" ge "1.8.8"
}

# ===================== Main flow =====================
require_root

echo "==> Installing required packages"
ensure_pkg ca-certificates msmtp msmtp-mta mailutils apparmor apparmor-utils

echo "==> Checking CA bundle"
if [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
  echo "CA bundle missing or empty. Reinstalling..."
  apt-get install -y --reinstall ca-certificates
  update-ca-certificates
fi

echo "==> Enabling AppArmor for msmtp (enforce)"
ensure_apparmor_enforce

echo "==> Preparing AppArmor-compatible log directory and file"
install -d -m 750 -o root -g adm /var/log/msmtp
touch /var/log/msmtp/msmtp.log
chown root:adm /var/log/msmtp/msmtp.log
chmod 640 /var/log/msmtp/msmtp.log

# ========= Collect configuration data =========
echo "==> Collecting default SMTP account parameters"
prompt SMTP_HOST      "SMTP server (host)" "smtp.example.com"
prompt SMTP_PORT      "SMTP port" "587"
prompt FROM_ADDR      "Default From address" "no-reply@midominio.com"
prompt FROM_NAME      "Sender's full name (From Full Name)" "Notifications Midominio"
prompt SMTP_USER      "SMTP user" "$FROM_ADDR"

TLS_MODE="starttls"
if [[ "$SMTP_PORT" == "465" ]]; then
  TLS_MODE="smtps"
fi

echo "==> Defining location of the secure password file"
prompt SECRET_FILE "Name of password file (without path)" "default.pw"
SECRET_PATH="/etc/msmtp/$SECRET_FILE"
prompt_secret_to_file "$SECRET_PATH" "Enter SMTP password (or App Password)"

# ========= Generate /etc/msmtprc =========
echo "==> Generating /etc/msmtprc with secure template"
umask 177
{
  echo "# ========================="
  echo "# Global configuration"
  echo "# ========================="
  echo "defaults"
  echo "auth                 on"
  echo "tls                  on"
  if [[ "$TLS_MODE" == "starttls" ]]; then
    echo "tls_starttls         on"
  else
    echo "tls_starttls         off"
  fi
  echo "tls_trust_file       /etc/ssl/certs/ca-certificates.crt"
  echo "tls_certcheck        on"
  echo "logfile              /var/log/msmtp/msmtp.log"
  echo "aliases              /etc/aliases"
  if msmtp_supports_from_fields; then
    echo "set_from_header      on"
  fi
  echo
  echo "# ========================="
  echo "# Default account"
  echo "# ========================="
  echo "account              default"
  echo "host                 $SMTP_HOST"
  echo "port                 $SMTP_PORT"
  echo "from                 $FROM_ADDR"
  if msmtp_supports_from_fields; then
    echo "from_full_name       \"$FROM_NAME\""
  fi
  echo "user                 $SMTP_USER"
  echo "passwordeval         \"cat $SECRET_PATH\""
} > /etc/msmtprc

chown root:root /etc/msmtprc
chmod 600 /etc/msmtprc

# ========= Integrated send test =========
echo "==> Performing integrated send test"
read -r -p "Enter the recipient email for the test: " TEST_RECIPIENT
TEST_LOG="/var/log/msmtp/test_send_mail.log"
TMPMSG="$(mktemp /tmp/msmtp-test.XXXXXX)"

{
  echo "To: $TEST_RECIPIENT"
  echo "Subject: msmtp test - $(hostname)"
  echo
  echo "Hello,"
  echo
  echo "This is a test message sent with msmtp."
  echo "Date: $(date -Is)"
  echo "Host: $(hostname -f 2>/dev/null || hostname)"
  echo
  echo "If you receive this message, the configuration is correct."
} > "$TMPMSG"

if msmtp --debug -a default -t < "$TMPMSG" 2>&1 | tee "$TEST_LOG"; then
  echo "==> Message sent. Check the mailbox of $TEST_RECIPIENT"
else
  echo "ERROR: Sending failed. Check $TEST_LOG for details."
fi

rm -f "$TMPMSG"
echo "==> Test log saved to: $TEST_LOG"

echo "==> Installation and testing completed."
