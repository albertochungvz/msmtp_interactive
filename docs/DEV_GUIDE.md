# 🛡 Development Guide – Guardrails for Major Changes

This guide defines the **guardrails** to follow when making large-scale changes to the SMTP Toolkit.  
They ensure architectural consistency, maintainability, and smooth onboarding for new contributors.

---

## 1️⃣ Structure & Organization
- Keep these top-level folders:
  - `docs/` → documentation and diagrams.
  - `modules/` → reusable shell modules (no docs here).
  - `test/` → test and validation scripts (e.g., `quick_test.sh`, `test_send_mail.sh`).
  - `env-accounts/` → per-account `.env` files.
  - Root → entry-point scripts (`install_msmtp_armored.sh`, `README.md`, optional `.env` global).
  - `config/` → base configuration templates (e.g., `msmtprc.template`).
  - `dev-env/` → Docker-based development environment (with `docker-compose.yml`, `Dockerfile`, helper scripts).
- Do **not** mix code and documentation in the same folder.
- Use consistent naming: scripts and modules in `snake_case`, functions in `lowerCamelCase` or `snake_case`.

+### 📂 Directory Structure Diagram

```plaintext
.
├── config/                  # Base configuration templates
│   └── msmtprc.template
│
├── dev-env/                 # Docker-based development environment
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── msmtp_dev_env.sh
│   └── README.md
│
├── docs/                    # Documentation (English + translations)
│   ├── *.md
│   └── es/
│       ├── *.md
│
├── env-accounts/            # Per-account .env files
│   ├── account1.env
│   └── ...
│
├── modules/                 # Reusable shell modules
│   ├── utils.sh
│   ├── config_generator.sh
│   ├── smtp_audit.sh
│   ├── smtp_test.sh
│   ├── smtp_presets.sh
│   ├── smtp_presets_validator.sh
│   ├── account_duplicates_validator.sh
│   ├── apparmor.sh
│   └── pkg_install.sh
│
├── test/                    # Test and validation scripts
│   ├── quick_test.sh
│   ├── test_send_mail.sh
│   └── README.md
│
├── .env                      # Optional global environment file
├── install_msmtp_armored.sh  # Main secure installation script
├── README.md                 # Main documentation entry point
└── (other root-level docs: LICENSE, CHANGELOG.md, CONTRIBUTING.md, etc.)
```

---

## 2️⃣ Code Standards
- Always include:
    ```bash
    set -Eeuo pipefail
    ```

- Load modules with:
    ```bash
    source "$SCRIPT_DIR/modules/<module>.sh"
    ```
- Centralize shared logic in modules to avoid duplication.
- Document environment variables in `docs/` and use them consistently.

## 3️⃣ Automated Validation
- Lint:
    ```bash
    shellcheck modules/*.sh install_msmtp_armored.sh test/*.sh
    ```
- Format:
    ```bash
    shfmt -d
    ```
- Dry-run tests:
    ```bash
    DRY_RUN=1 ./modules/config_generator.sh
    ./modules/smtp_audit.sh --json
    ```

- JSON schema check: ensure `/tmp/smtp_audit_report.json` contains required fields:

    - `account`, `status`, `host`, `port`, `tls`, `auth`, `preset`.

## 4️⃣ Output & Error Handling
- Every major flow must produce:
    - Human-readable table.
    - Machine-readable JSON for CI/CD.

- Accumulate errors and report them at the end.
- Exit with code `1` if any audit entry has `"status":"error"`.


## 5️⃣ Documentation Sync
Update `docs/Quick_start.md` and diagrams in the same commit as code changes.

Note in `README` or changelog if flags, variables, or usage change.

Maintain flow diagrams for main scripts (`quick_test.sh`, `install_msmtp_armored.sh`).


## 6️⃣ Commit & Versioning
- Use clear, contextual commit messages (Conventional Commits recommended).
- For major milestones:
    - Create a semantic version tag (`vX.Y.Z`).
    - Optionally create a descriptive alias tag (e.g., `modular-architecture`).
- Include a high-level summary of changes and their impact.

Tip: Run `test/quick_test.sh` before committing to ensure the toolkit passes a full dry-run audit and test cycle.