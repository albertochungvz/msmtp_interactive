# 📚 SMTP Toolkit – Technical README

## Overview

This toolkit provides a modular, reproducible, and secure way to generate, validate, audit, and test msmtp configurations. It is designed for collaborative environments, with optional strict validation and dry-run support.

---

## 📂 Modules

| Script                          	| Purpose                                        	| Key Inputs                                           	| Key Outputs                                       	|
|---------------------------------	|------------------------------------------------	|------------------------------------------------------	|---------------------------------------------------	|
| config_generator.sh             	| Generates /etc/msmtprc or /tmp/msmtprc.preview 	| .env global + per-account env files, smtp_presets.sh 	| Ready-to-use msmtp config                         	|
| smtp_presets_validator.sh       	| Validates smtp_presets.sh integrity            	| smtp_presets.sh                                      	| ok / fail                                         	|
| account_duplicates_validator.sh 	| Detects duplicate (host, port, user) accounts  	| msmtprc file                                         	| ok / fail, duplicate list                         	|
| smtp_audit.sh                   	| Audits config against presets & best practices 	| msmtprc file, smtp_presets.sh                        	| Table or JSON report, /tmp/smtp_audit_report.json 	|
| smtp_test.sh                    	| Sends test emails                              	| msmtprc file, account(s), target email               	| Per-account ok / fail                             	|
| list_accounts.sh                	| Lists configured accounts                      	| msmtprc file                                         	| Text or JSON list                                 	|

---

## ⚙️ Recommended Workflow

1. Generate configuration
```bash
./modules/config_generator.sh
```

- Loads `.env` global and `env-accounts/<account>.env`
- Validates `smtp_presets.sh`
- In strict mode, forces selection of `port`/`tls/auth` from predefined lists
- Runs `account_duplicates_validator.sh`
- Runs `smtp_audit.sh --report`
- Optionally runs `smtp_test.sh`

2. Audit configuration
```bash
./modules/smtp_audit.sh --json
```
- Validates `host`, `port`, `tls`, `auth`, `from`
- Detects unused presets
- Integrates `account_duplicates_validator.sh`
- Saves JSON to `/tmp/smtp_audit_report.json`

3. Send test email(s)
```bash
SMTP_TEST_TO=recipient@example.com ./modules/smtp_test.sh --json
```

- Tests all or specific accounts (`--account`)
- Optionally runs `smtp_audit.sh` before sending
- JSON output for CI/CD

4. List accounts
```bash
./modules/list_accounts.sh --json
```

- Single source of truth for account listing
- Respects `DRY_RUN` and `ACCOUNT_CONFIG_FILE`

--- 

## 🔑 Key Environment Variables

|     **Variable**     	|                      **Description**                      	|             **Example**            	|
|:--------------------	|:---------------------------------------------------------	    |:----------------------------------	|
| DRY_RUN              	| If 1, writes /tmp/msmtprc.preview instead of /etc/msmtprc 	| DRY_RUN=1                          	|
| STRICT_VALIDATION    	| If 1, applies strict validation rules                     	| STRICT_VALIDATION=1                	|
| ACCOUNT_CONFIG_FILE  	| Alternate msmtprc path                                    	| /path/to/msmtprc                   	|
| SMTP_TEST_TO         	| Target email for test sends                               	| SMTP_TEST_TO=recipient@example.com 	|
| SMTP_TEST_ACCOUNT    	| Specific account to test                                  	| SMTP_TEST_ACCOUNT=gmail            	|
| SMTP_AUDIT_TEST      	| If 1, tests connectivity during audit                     	| SMTP_AUDIT_TEST=1                  	|
| SMTP_AUDIT_JSON_FILE 	| Path to save audit JSON                                   	| /tmp/audit.json                    	|

--- 

## 📊 Module Interaction Diagram

<!-- [![](https://mermaid.ink/img/pako:eNp9UstugzAQ_BW0Z4IggRB8qNSENqfeqh4KFXLBgCWwkR99Jfn3mkcSmkN92vHM7qzXe4CcFwQQlA3_zGsslPUcp8wy5z7JOStplVWEEYEVF46s36zF4s7aJrJVXdYJIomS2QduaHEWTMmDbpfgPOeaqazQXUNzrMg_6nisinVB1ZWLB-4haahU2VRO3tK7OXj8092Ny5F3inKGm6O1H3Wmp5ndfrSbgVnGNBmp3yuBu9p6OT9FjkR_ttdw6oqwAmyoBC0AKaGJDS0RLe4hHHpJCqomLUkBmbAgJdaNSiFlJ5PWYfbKeXvOFFxXNaASN9Ig3Rl3ElNs2mkvt8IYErHrBwXIc1dDEUAH-AK0WjpR4HnhOvRC3w_dILDhG1AUOeulH0VrL3CDjR_4Jxt-BlvX2YRGQ8yfcPE07sqwMqdfApiykA?type=png)](https://mermaid.live/edit#pako:eNp9UstugzAQ_BW0Z4IggRB8qNSENqfeqh4KFXLBgCWwkR99Jfn3mkcSmkN92vHM7qzXe4CcFwQQlA3_zGsslPUcp8wy5z7JOStplVWEEYEVF46s36zF4s7aJrJVXdYJIomS2QduaHEWTMmDbpfgPOeaqazQXUNzrMg_6nisinVB1ZWLB-4haahU2VRO3tK7OXj8092Ny5F3inKGm6O1H3Wmp5ndfrSbgVnGNBmp3yuBu9p6OT9FjkR_ttdw6oqwAmyoBC0AKaGJDS0RLe4hHHpJCqomLUkBmbAgJdaNSiFlJ5PWYfbKeXvOFFxXNaASN9Ig3Rl3ElNs2mkvt8IYErHrBwXIc1dDEUAH-AK0WjpR4HnhOvRC3w_dILDhG1AUOeulH0VrL3CDjR_4Jxt-BlvX2YRGQ8yfcPE07sqwMqdfApiykA) -->


Full interaction diagram

```Mermaid
flowchart TD
    A["modules/config_generator.sh"] -->|validates| V["smtp_presets_validator.sh"]
    A -->|checks duplicates| W["account_duplicates_validator.sh"]
    A -->|writes config| X{DRY_RUN?}
    X -- Yes --> P["/tmp/msmtprc.preview"]
    X -- No --> Q["/etc/msmtprc"]
    A -->|audit after write --report| D["smtp_audit.sh"]

    D -->|lists accounts| E["list_accounts.sh"]
    D -->|uses presets catalog| F["smtp_presets.sh"]
    D -->|also checks duplicates| W
    D -->|optional connectivity and TLS expiry| Z["Network checks"]
    D -->|JSON output when --json| R["/tmp/smtp_audit_report.json"]

    A -->|optional prompt| G["smtp_test.sh"]

    G -->|lists accounts| E
    G -->|optional pre-audit| D
    G -->|send via msmtp| M["msmtp"]
    M --> P
    M --> Q

    subgraph Config artifacts
        P
        Q
        R
    end

    subgraph Validators
        V
        W
    end

```
Key clarifications:

- The global `.env` lives either at the project root or inside `modules/. env-accounts/` is only for per-account files.
- `config_generator.sh` orchestrates: validates presets, checks duplicates, writes the config (preview or real), then runs `smtp_audit.sh --report`, and optionally triggers `smtp_test.sh`.
- `smtp_audit.sh` uses `list_accounts.sh` and `smtp_presets.sh`, can perform connectivity/TLS checks, and writes JSON to `/tmp/smtp_audit_report.json` when requested.
- `smtp_test.sh` can optionally run `smtp_audit.sh` before sending, and always uses `list_accounts.sh` to resolve accounts.

--- 
  

Quick flow diagram

```Mermaid
flowchart TD
    A[Start] --> B["Set globals in .env <br> (root or modules/)"]
    B --> C["Add per-account files<br>env-accounts /<<account>account>.env"]
    C --> D{Dry run?}
    D -- Yes --> E["Run config_generator.sh<br>writes /tmp/msmtprc.preview"]
    D -- No --> F["Run config_generator.sh<br>writes <br> /etc/msmtprc"]
    E --> G["Run smtp_audit.sh --report"]
    F --> G
    G --> H{Send test email now?}
    H -- Yes --> I["Run smtp_test.sh with SMTP_TEST_TO"]
    H -- No --> J[End]
    I --> J

```