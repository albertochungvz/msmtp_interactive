#!/usr/bin/env bash
# set -Eeuo pipefail
set -Eeo pipefail

# Bootstrap fase: solving installer directory for loading utils.sh
INSTALLER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Load utils.sh from installer directory
source "$INSTALLER_DIR/modules/utils.sh"

if [[ "${DEBUG:-0}" -eq 1 ]]; then
    section "DEBUG INFO"
    { log_debug "Installer dir      : $INSTALLER_DIR" || true; }
    { log_debug "Modules dir        : $(get_script_dir || echo '<error>')" || true; }
    { log_debug "Script invoked as  : $0" || true; }
    { log_debug "Current user       : $(id -u -n 2>/dev/null || echo '<error>') (UID $(id -u 2>/dev/null || echo '<error>'))" || true; }
    { log_debug "Shell              : ${SHELL:-<unknown>}" || true; }
    { log_debug "Bash version       : $BASH_VERSION" || true; }
    { log_debug "Working directory  : $(pwd || echo '<error>')" || true; }
    { log_debug "Environment vars   : DRY_RUN=${DRY_RUN:-0}, NON_INTERACTIVE=${NON_INTERACTIVE:-0}, VERBOSE=${VERBOSE:-1}, DEBUG=${DEBUG:-0}" || true; }
    { log_debug "PATH               : $PATH" || true; }
    if command -v apt-get >/dev/null 2>&1; then
        { log_debug "apt-get found at   : $(command -v apt-get || echo '<error>')" || true; }
    else
        { log_warn "apt-get not found in PATH" || true; }
    fi
fi

# get_script_dir points to modules/
MODULES_DIR="$(get_script_dir)"

# Load modules
source "$MODULES_DIR/pkg_install.sh"
source "$MODULES_DIR/apparmor.sh"
source "$MODULES_DIR/config_generator.sh"
source "$MODULES_DIR/smtp_audit.sh"
source "$MODULES_DIR/list_accounts.sh"
source "$MODULES_DIR/smtp_test.sh"

# Main flow
require_root

section "Installing dependencies"
install_dependencies
check_ca_bundle

section "Configuring AppArmor"
# enable_apparmor
ensure_apparmor_profile

section "Generating msmtp configuration (DRY_RUN=0)"
# generate_msmtp_config
generate_msmtprc

section "Auditing configuration"
AUDIT_JSON="/tmp/smtp_audit_report.json"
SMTP_AUDIT_JSON_FILE="$AUDIT_JSON" \
    smtp_audit --report --json > "$AUDIT_JSON"

log_info "Audit JSON saved to $AUDIT_JSON"

log_info "Audit summary (table view):"
jq -r '
    (["ACCOUNT","HOST","PORT","TLS","AUTH","STATUS","PRESET"]),
    (["-------","----","----","---","----","------","------"]),
    (.[] | [ .account, .host, .port, .tls, .auth, .status, .preset ])
    | @tsv
' "$AUDIT_JSON" | column -t

# Validate audit JSON: fail if any account has status=error
if jq -e '.[] | select_option(.status=="error")' "$AUDIT_JSON" >/dev/null; then
    log_error "Audit detected one or more accounts with errors."
    jq -r '.[] | select_option(.status=="error") | " - \(.account) (\(.host):\(.port))"' "$AUDIT_JSON"
    exit 1
else
    log_info "Audit passed: no accounts with status=error."
fi

section "Running SMTP test"
accounts=$(list_accounts)
for acc in $accounts; do
    SMTP_TEST_TO="${SMTP_TEST_TO:-test@example.com}" \
    SMTP_TEST_ACCOUNT="$acc" \
    smtp_test --json --no-audit || true
done

section "Installation and configuration summary"
show_summary
