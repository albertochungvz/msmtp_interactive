#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# Configuration
# =========================
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ACCOUNT="default"   # Account name in /etc/msmtprc
LOGDIR="/var/log/msmtp"
LOGFILE="$LOGDIR/test_send_mail.log"
TMPMSG="$(mktemp /tmp/msmtp-test.XXXXXX)"

# =========================
# Functions
# =========================
abort() {
  echo "ERROR: $*" >&2
  exit 1
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

# =========================
# Pre-flight checks
# =========================
command -v msmtp >/dev/null 2>&1 || abort "msmtp not found. Please install it first."
[[ -f /etc/msmtprc ]] || abort "/etc/msmtprc not found. Run install_msmtp_armored.sh first."

# Ensure log directory exists
install -d -m 750 -o root -g mail "$LOGDIR"

# =========================
# Request data
# =========================
prompt RECIPIENT "Destination email for the test"

# =========================
# Prepare message
# =========================
{
  echo "To: $RECIPIENT"
  echo "Subject: msmtp test - $(hostname)"
  echo
  echo "Hi,"
  echo
  echo "This is a test message sent with msmtp."
  echo "Date: $(date -Is)"
  echo "Host: $(hostname -f 2>/dev/null || hostname)"
  echo
  echo "If you receive this message, the configuration is correct."
} > "$TMPMSG"

# =========================
# Sending message
# =========================
echo "==> Sending test message..."
if msmtp --debug -a "$ACCOUNT" -t < "$TMPMSG" 2>&1 | tee "$LOGFILE"; then
  echo "✅ Message sent. Check the inbox of $RECIPIENT"
else
  abort "Failed to send message. Check $LOGFILE for details."
fi

# =========================
# Cleanup
# =========================
rm -f "$TMPMSG"

# =========================
# Summary
# =========================
echo "==> Test log saved to: $LOGFILE"
echo "==> End of test."
