# Security Guide for Configuring msmtp

This document describes the security measures implemented in this project and recommendations for maintaining a secure environment when using `msmtp` on Ubuntu Server.

---

## 🔒 Key Principles

1. **Defense in Depth**
- Use AppArmor in `enforce` mode to confine `msmtp`.
- Strict TLS certificate validation (`tls_certcheck on`).

2. **Credential Protection**
- Use `passwordeval` to read passwords from files with `600` permissions and `root:root`.
- Store secrets in a `/etc/msmtp/` directory with `700` permissions.
- Recommended: Use *App Passwords* instead of master passwords.

3. **Secure Logs**
- Logging to `/var/log/msmtp/msmtp.log` with restrictive permissions (`640`) and a controlled owner.
- A `/var/log/msmtp/` folder with `750` permissions, compatible with AppArmor.
- Alternative: Use of `syslog LOG_MAIL` to centralize in `/var/log/mail.log`.

4. **TLS and Encryption**
- Use of secure ports: `587` (STARTTLS) or `465` (SMTPS).
- `tls_trust_file` pointing to the `/etc/ssl/certs/ca-certificates.crt` system bundle.
- Ability to harden ciphers with `tls_priorities`.

5. **Permissions and Isolation**
- Avoid sensitive logs or files in `$HOME` in multi-user environments.
- One password file per SMTP account, with minimal permissions.
- Separate system accounts for services that send email.

---

## 🚫 Practices to Avoid

- Saving passwords in plain text in `msmtprc`.
- Disabling `tls_certcheck` in production.
- Using lax permissions (`777`) on directories or configuration files.
- Disabling AppArmor without a solid technical justification.

---

## 📌 References

- [Official msmtp manual](https://marlam.de/msmtp/msmtp.html)
- [AppArmor documentation on Ubuntu](https://documentation.ubuntu.com/server/how-to/security/apparmor/)