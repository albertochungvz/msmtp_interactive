#!/usr/bin/env bash
# ============================================================
# quick_test.sh - Fast end-to-end check of the SMTP toolkit
# ============================================================

set -Eeuo pipefail

# Load utils and list_accounts
source "$(dirname "$0")/../modules/utils.sh"
source "$(dirname "$0")/../modules/list_accounts.sh"

# Optional: load global .env if present
if [[ -f "$(dirname "$0")/../.env" ]]; then
    set -a
    source "$(dirname "$0")/../.env"
    set +a
fi

section "Quick Test - SMTP Toolkit"

# 1. Generate config in DRY_RUN mode
log_info "Generating config in DRY_RUN mode..."
DRY_RUN=1 "$(dirname "$0")/../modules/config_generator.sh"

# 2. Audit config (report mode, JSON output)
log_info "Auditing generated config..."
AUDIT_JSON="/tmp/smtp_audit_report.json"
SMTP_AUDIT_JSON_FILE="$AUDIT_JSON" \
    "$(dirname "$0")/../modules/smtp_audit.sh" --report --json > "$AUDIT_JSON"

log_info "Audit JSON saved to $AUDIT_JSON"

# 3. Show human-readable summary from JSON
log_info "Audit summary (table view):"
jq -r '
    (["ACCOUNT","HOST","PORT","TLS","AUTH","STATUS","PRESET"]),
    (["-------","----","----","---","----","------","------"]),
    (.[] | [ .account, .host, .port, .tls, .auth, .status, .preset ])
    | @tsv
' "$AUDIT_JSON" | column -t

# 4. Validate audit JSON: fail if any account has status=error
if jq -e '.[] | select(.status=="error")' "$AUDIT_JSON" >/dev/null; then
    log_error "Audit detected one or more accounts with errors."
    jq -r '.[] | select(.status=="error") | " - \(.account) (\(.host):\(.port))"' "$AUDIT_JSON"
    exit 1
else
    log_info "Audit passed: no accounts with status=error."
fi

# 5. List accounts using central function
log_info "Listing accounts..."
accounts=$(list_accounts)
echo "$accounts" | while read -r acc; do
    echo " - $acc"
done

# 6. Run SMTP test for each account (dry-run mode)
log_info "Running SMTP test (dry-run)..."
for acc in $accounts; do
    SMTP_TEST_TO="${SMTP_TEST_TO:-test@example.com}" \
    SMTP_TEST_ACCOUNT="$acc" \
    DRY_RUN=1 \
    "$(dirname "$0")/../modules/smtp_test.sh" --json --no-audit || true
done

section "Quick Test Completed"
