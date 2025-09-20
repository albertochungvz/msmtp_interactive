#!/usr/bin/env bash
# ============================================================
# smtp_presets.sh - Predefined SMTP server configurations
# Fuentes: Official documentation of each supplier (accessed September 2025)
# ============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -Eeuo pipefail
fi


declare -A SMTP_PRESETS=(
    # Amazon SES (ajustar <region> según la cuenta)
    [amazonses_host]="email-smtp.<region>.amazonaws.com"
    [amazonses_port]="587"
    [amazonses_tls]="on"
    [amazonses_auth]="on"

    # Brevo (antes Sendinblue)
    [brevo_host]="smtp-relay.brevo.com"
    [brevo_port]="587"
    [brevo_tls]="on"
    [brevo_auth]="on"

    # Gmail
    [gmail_host]="smtp.gmail.com"
    [gmail_port]="587"
    [gmail_tls]="on"
    [gmail_auth]="on"

    # Google Workspace
    [googleworkspace_host]="smtp-relay.gmail.com"
    [googleworkspace_port]="587"
    [googleworkspace_tls]="on"
    [googleworkspace_auth]="on"

    # Mailchimp
    [mailchimp_host]="smtp.mailchimp.com"
    [mailchimp_port]="587"
    [mailchimp_tls]="on"
    [mailchimp_auth]="on"

    # MailerSend
    [mailersend_host]="smtp.mailersend.net"
    [mailersend_port]="587"
    [mailersend_tls]="on"
    [mailersend_auth]="on"

    # Mailgun
    [mailgun_host]="smtp.mailgun.org"
    [mailgun_port]="587"
    [mailgun_tls]="on"
    [mailgun_auth]="on"

    # Mailjet
    [mailjet_host]="in-v3.mailjet.com"
    [mailjet_port]="587"
    [mailjet_tls]="on"
    [mailjet_auth]="on"

    # MailPulse
    [mailpulse_host]="smtp.mailpulse.com"
    [mailpulse_port]="587"
    [mailpulse_tls]="on"
    [mailpulse_auth]="on"

    # Microsoft 365
    [m365_host]="smtp.office365.com"
    [m365_port]="587"
    [m365_tls]="on"
    [m365_auth]="on"

    # Outlook.com
    [outlook_host]="smtp-mail.outlook.com"
    [outlook_port]="587"
    [outlook_tls]="on"
    [outlook_auth]="on"

    # Postmark
    [postmark_host]="smtp.postmarkapp.com"
    [postmark_port]="587"
    [postmark_tls]="on"
    [postmark_auth]="on"

    # SendGrid
    [sendgrid_host]="smtp.sendgrid.net"
    [sendgrid_port]="587"
    [sendgrid_tls]="on"
    [sendgrid_auth]="on"

    # SMTP2GO
    [smtp2go_host]="mail.smtp2go.com"
    [smtp2go_port]="587"
    [smtp2go_tls]="on"
    [smtp2go_auth]="on"

    # Zoho Mail
    [zoho_host]="smtp.zoho.com"
    [zoho_port]="587"
    [zoho_tls]="on"
    [zoho_auth]="on"
)

# Note: Some providers may require additional configurations such as OAuth2 authentication, allowed IPs, etc. Consult each service's official documentation for specific details.