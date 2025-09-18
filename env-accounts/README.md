# 📂 env-accounts – Per‑Account Environment Files

This directory contains **one `.env` file per SMTP account**.  
Each file defines the variables needed to generate and validate its `msmtp` configuration.

---

## 📄 File Naming

- The filename **must match** the account name you want to use in `config_generator.sh`.
- Example:
  - `gmail.env` → `ACCOUNT_NAME=gmail`
  - `work.env` → `ACCOUNT_NAME=work`

---

## 🛠 File Structure

Each `.env` file should contain:

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `ACCOUNT_NAME` | ✅ | Unique account identifier (matches filename) | `gmail` |
| `ACCOUNT_PRESET` | ✅ | Preset name from `smtp_presets.sh` or `custom` | `gmail` |
| `ACCOUNT_FROM` | ✅ | Email address used in the `From:` header | `user@gmail.com` |
| `ACCOUNT_USER` | ✅ | SMTP username | `user@gmail.com` |
| `ACCOUNT_SECRET` | ✅ | Path to password file (stored securely) | `/etc/msmtp.secrets/gmail.passwd` |
| `ACCOUNT_HOST` | ⚠️ Only if `ACCOUNT_PRESET=custom` | SMTP server hostname | `smtp.example.com` |
| `ACCOUNT_PORT` | ⚠️ Only if `ACCOUNT_PRESET=custom` | SMTP server port | `587` |
| `ACCOUNT_TLS` | ⚠️ Only if `ACCOUNT_PRESET=custom` | `on` or `off` | `on` |
| `ACCOUNT_AUTH` | ⚠️ Only if `ACCOUNT_PRESET=custom` | `on` or `off` | `on` |

---

## 📌 Examples

### Gmail account using preset
```bash
ACCOUNT_NAME=gmail
ACCOUNT_PRESET=gmail
ACCOUNT_FROM=user@gmail.com
ACCOUNT_USER=user@gmail.com
ACCOUNT_SECRET=/etc/msmtp.secrets/gmail.passwd
```

### Work account with custom settings
```bash
ACCOUNT_NAME=work
ACCOUNT_PRESET=custom
ACCOUNT_HOST=smtp.company.com
ACCOUNT_PORT=587
ACCOUNT_TLS=on
ACCOUNT_AUTH=on
ACCOUNT_FROM=user@company.com
ACCOUNT_USER=user@company.com
ACCOUNT_SECRET=/etc/msmtp.secrets/work.passwd
```

---

## 🔒 Security Notes

- Never commit password files to version control.
- Store secrets in `/etc/msmtp.secrets` with `chmod 600`.
- `.env` files in this folder may contain sensitive usernames and should be excluded from public repositories.

---

## 🔄 How They’re Used

- `config_generator.sh` loads the global `.env` (root or `modules/`) and each account’s `.env` from `env-accounts/`.
- The generator merges these values with presets from `smtp_presets.sh`.
- The resulting configuration is validated, audited, and optionally tested.

---

## ✅ Best Practices

- Keep variable names consistent across all accounts.
- Use `ACCOUNT_PRESET` whenever possible to avoid duplicating host/port/tls/auth values.
- For `custom` accounts, ensure all required fields are present.
- Run:
```bash
./modules/smtp_audit.sh --report
```
after adding or modifying accounts to verify correctness.

---

## 📊 How env-accounts/ Fits in the Workflow

```Mermaid
flowchart TD
    subgraph User Setup
        A["Global .env<br>(root or modules/)"]
        B["Per-account .env files<br>env-accounts/ <<a>account>.env"]
    end

    subgraph Generator
        C["config_generator.sh"]
    end

    subgraph Validation & Audit
        D["smtp_presets_validator.sh"]
        E["account_duplicates_validator.sh"]
        F["smtp_audit.sh"]
    end

    subgraph Output
        G["/etc/msmtprc or /tmp/msmtprc.preview"]
        H["/tmp/smtp_audit_report.json"]
    end

    A --> C
    B --> C
    C --> D
    C --> E
    C --> G
    C --> F
    F --> H
```

How to read it:

- User Setup: You define global settings in `.env` and account-specific settings in `env-accounts/`.
- Generator: `config_generator.sh` merges both sources, applies presets, and writes the config.
- Validation & Audit: Presets are validated, duplicates checked, and the config audited.
- Output: You get a ready-to-use `msmtprc` (or preview in dry-run) and, if requested, a JSON audit report.