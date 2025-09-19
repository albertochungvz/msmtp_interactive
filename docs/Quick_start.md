# 🚀 Quick‑Start Command Cheat Sheet - SMTP Toolkit

This guide provides the most common commands to get started with the SMTP Toolkit, including configuration generation, auditing, testing, and quick CI/CD checks.

---

## 🛠 Initial Installation (Secure Setup)

For a first-time installation with dependencies, AppArmor configuration, and initial `msmtp` setup, use:

```bash
sudo ./install_msmtp_armored.sh
```

### What it does

- Installs required packages and checks CA bundle.
- Enables AppArmor profile for `msmtp`.
- Generates `msmtp` configuration (`/etc/`msmtp`rc`).
- Audits configuration (`smtp_audit.sh --report --json`) and shows a human-readable table.
- Validates audit JSON and stops if any account has `status=error`.
- Runs SMTP tests for all accounts (dry-run or real send depending on configuration).
- Shows a final installation and configuration summary.

**Tip:** Run this script with `sudo` as it needs to install packages and write to system directories.

### Workflow

![Flowchart showing the secure installation process: dependency setup, config generation, audit, SMTP tests, and final summary](img/install_flow_lr.svg)

<details markdown="block">
<summary>Show Mermaid flowchart</summary>

```Mermaid
flowchart TD
    A["install_`msmtp`_armored.sh start"] --> B["require_root()"]
    B --> C["install_dependencies()"]
    C --> D["check_ca_bundle()"]
    D --> E["enable_apparmor()"]
    E --> F["generate_`msmtp`_config()"]
    F --> G["smtp_audit.sh --report --json<br>(save /tmp/smtp_audit_report.json)"]
    G --> H["Show audit table from JSON"]
    H --> I{"Any status=error?"}
    I -- Yes --> J["Show failing accounts + exit 1"]
    I -- No --> K["list_accounts.sh"]
    K --> L["Loop over accounts"]
    L --> M["smtp_test.sh --json --no-audit"]
    M --> N["show_summary()"]
    J --> Z[End]
    N --> Z
```

</details>

### Explanation

The `install_`msmtp`_armored.sh` script performs a secure, end‑to‑end setup of `msmtp` with AppArmor protection and built‑in configuration validation. It begins by ensuring the script is run as root, then installs all required dependencies and verifies the system’s CA bundle. AppArmor is enabled to confine `msmtp` within a strict security profile.

Next, the script generates the `msmtp` configuration file using the current environment and account definitions. Once the configuration is in place, it runs a full audit (`smtp_audit.sh --report --json`) to check for preset mismatches, duplicate accounts, and optional network/TLS issues. The audit results are saved as JSON for CI/CD use and displayed as a human‑readable table.

If the audit detects any accounts with `status=error`, the script lists them and exits immediately. If the audit passes, it retrieves all configured accounts and runs `smtp_test.sh` for each one to verify sending capability (in JSON mode without re‑auditing). Finally, it calls `show_summary` to present a concise overview of the installation and configuration status.

This approach ensures that installation, configuration, validation, and testing are all performed in a single, consistent workflow, producing both machine‑readable and human‑friendly outputs.

---

## 1️. Generate Configuration

Generate ``msmtp`rc` from global `.env` and per-account `.env` files in `env-accounts/`.

- Standard generation (writes /etc/`msmtp`rc)

    ```bash
    ./modules/config_generator.sh
    ```

- Dry-run mode (writes /tmp/`msmtp`rc.preview)

    ```bash
    DRY_RUN=1 ./modules/config_generator.sh
    ```

---

## 2. Audit configuration

- Table output

    ```bash
    ./modules/smtp_audit.sh
    ```

- JSON output + save to /tmp/smtp_audit_report.json

    ```bash
    ./modules/smtp_audit.sh --json
    ```

- Audit + connectivity test

    ```bash
    SMTP_AUDIT_TEST=1 ./modules/smtp_audit.sh --test
    ```

---

## 3. Send test email(s)

- Test all accounts

    ```bash
    SMTP_TEST_TO=recipient@example.com ./modules/smtp_test.sh
    ```

- Test specific account

    ```bash
    SMTP_TEST_TO=recipient@example.com ./modules/smtp_test.sh --account gmail
    ```

- JSON output

    ```bash
    SMTP_TEST_TO=recipient@example.com ./modules/smtp_test.sh --json
    ```

---

## 4. List configured accounts

- Text output

    ```bash
    ./modules/list_accounts.sh
    ```

- JSON output

    ```bash
    ./modules/list_accounts.sh --json
    ```

---

## 5. Validate Presets and Duplicates

- Validate `smtp_presets.sh`

```bash
./modules/smtp_presets_validator.sh
```

- Check for duplicate accounts

```bash
./modules/account_duplicates_validator.sh
```

---

## 6. Quick End-to-End Test (CI/CD Friendly)

Run a full dry-run generation, audit, JSON validation, and optional SMTP tests. Fails immediately if the audit detects any account with `"status":"error"`.

```bash
./test/quick_test.sh
```

**What it does:**

- Generates config in `DRY_RUN` mode.
- Runs `smtp_audit.sh --report --json` and saves `/tmp/smtp_audit_report.json`.
- Shows a human-readable table from the JSON.
- Fails if any account has `status=error`.
- Runs `smtp_test.sh` in dry-run mode for all accounts if audit passes.

---

## 7. Dry-run mode (preview config without applying)

```bash
DRY_RUN=1 ./modules/config_generator.sh
```

---

## 🔹 Tips

- Global `.env`: Place in project root or `modules/.
- Per-account `.env`: Place in `env-accounts/` (one file per account).
- Secrets: Store passwords in `/etc/`msmtp`.secrets` with `chmod 600`.
- Always run in `DRY_RUN=1` first to preview changes safely.

## 📊 Quick Flow Diagram

![Flowchart of the quick_test.sh workflow for validating msmtp accounts: loads config, checks dependencies, runs audit, tests accounts, and summarizes results](img/quick_test_flow_LR.svg)

<details markdown="block">
<summary>Show Quick Test flowchart</summary>

```Mermaid
flowchart TD
    A["Set globals in .env<br>(root or modules/)"] --> B["Add per-account .env files<br>env-accounts/ <<a>account>.env"]
    B --> C["Run config_generator.sh<br>(DRY_RUN=1 recommended first)"]
    C --> D["Run smtp_audit.sh --report<br>(optional: --json, --test)"]
    D --> E{"Audit OK?"}
    E -- No --> F["Fix issues in .env files or presets"]
    E -- Yes --> G["Run smtp_test.sh<br>(optional: --account, --json)"]
    G --> H["Ready to apply config<br>(DRY_RUN=0)"]
```

</details>
