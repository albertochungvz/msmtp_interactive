# 🧪 Test Scripts – SMTP Toolkit

This folder contains helper scripts for testing and validation of the SMTP Toolkit.

---

## 📄 quick_test.sh

Runs a full dry-run generation, audit, JSON validation, and optional SMTP tests.  
Fails immediately if the audit detects any account with `"status":"error"`.

**Usage:**
```bash
./test/quick_test.sh
```

**What it does:**

- Generates config in `DRY_RUN` mode.
- Runs `smtp_audit.sh --report --json` and saves `/tmp/smtp_audit_report.json`.
- Shows a human-readable table from the JSON.
- Fails if any account has `status=error`.
- Runs `smtp_test.sh` in dry-run mode for all accounts if audit passes.

**Environment variables:**

`SMTP_TEST_TO` – target email for test sends (default: `test@example.com`).

---

## 📄 test_send_mail.sh

Sends a real test email using a specific account.

**Usage:**
```bash
SMTP_TEST_TO=recipient@example.com \
SMTP_TEST_ACCOUNT=gmail \
./test/test_send_mail.sh
```

**What it does:**

- Loads the specified account from `msmtprc` (or preview if `DRY_RUN=1`).
- Sends a test email via `msmtp`.
- Prints success/failure status.

**Environment variables:**

- `SMTP_TEST_TO` – required, recipient email address.
- `SMTP_TEST_ACCOUNT` – required, account name to test.
- `DRY_RUN` – if `1`, simulates without sending.

---

## 🔹 Notes

- Always run in `DRY_RUN=1` first to avoid unintended sends.
- These scripts are intended for testing only and should not be used in production workflows.
- For CI/CD, `quick_test.sh` is recommended as it validates configuration before attempting sends.

---

## 📊 Test Scripts Workflow Diagram

**How to read it:**

- `quick_test.sh` orchestrates a complete workflow: it generates the configuration in `DRY_RUN`, validates presets and duplicates, audits, displays the table and JSON, and if everything is OK, runs SMTP tests.
- `test_send_mail.sh` is more straightforward: it calls `smtp_test.sh` to send a real email (or a simulated one if `DRY_RUN=1`) to a specific account.
- Both scripts rely on `list_accounts.sh` to centrally retrieve the list of accounts.

### `quick_test.sh` workflow

```Mermaid
flowchart TD
    A["quick_test.sh start"] --> B["Load .env (if exists) + utils.sh + list_accounts.sh"]

    %% Step 1: Generate config (DRY_RUN)
    B --> C["Run config_generator.sh (DRY_RUN=1)<br>- Internally runs smtp_presets_validator.sh<br>- Internally runs account_duplicates_validator.sh<br>- Writes /tmp/msmtprc.preview"]

    %% Step 2: Audit
    C --> D["Run smtp_audit.sh --report --json<br>- Uses list_accounts.sh<br>- Runs account_duplicates_validator.sh<br>- (Optional) Network/TLS checks<br>- Saves /tmp/smtp_audit_report.json"]

    %% Step 3: Show results
    D --> E["Show human-readable table from JSON"]

    %% Step 4: Validate JSON once
    E --> F{"Any status=error in JSON?"}
    F -- Yes --> G["Show failing accounts<br>Exit 1 (after showing all errors)"]
    F -- No --> H["List accounts via list_accounts.sh"]

    %% Step 5: SMTP tests (only if audit passed)
    H --> I["Loop over accounts"]
    I --> J["Run smtp_test.sh (DRY_RUN=1, --json, --no-audit) for each account"]
    J --> K["(Optional) msmtp send simulation"]

    G --> Z[End]
    K --> Z
```

**🔹 Features of this flow**

- Sequential: Each step waits for the previous one to complete.
- Single validation: `"status":"error"` is only checked after the audit, not after each subprocess.
- Error accumulation: If there are issues in presets, duplicates, or audits, they are all reflected in the JSON and in the - table before slicing.
- SMTP tests: Only run if the audit passes without errors.

### `test_send_mail.sh` workflow

```Mermaid
flowchart TD
    A["test_send_mail.sh"] --> B["Load .env (if exists) + utils.sh + list_accounts.sh"]

    %% Step 1: Prepare
    B --> C{"SMTP_TEST_ACCOUNT set?"}
    C -- No --> D["Exit with error (missing account)"]
    C -- Yes --> E["Run smtp_test.sh (real send unless DRY_RUN=1)"]

    %% Step 2: smtp_test.sh internals
    E --> F["list_accounts.sh (validate account exists)"]
    F --> G["Prepare msmtp command for selected account"]
    G --> H{"DRY_RUN=1?"}
    H -- Yes --> I["Simulate send (no network)"]
    H -- No --> J["Send email via msmtp"]

    D --> Z[End]
    I --> Z
    J --> Z

```


