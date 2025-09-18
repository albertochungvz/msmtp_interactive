# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/), and this project follows [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]
### Added
- N/A

### Changed
- N/A

### Fixed
- N/A

### Removed
- N/A

# Changelog

## [v0.4] – 2025-09-18
### 🚀 Major Refactor & Modular Architecture
This release marks a complete redesign of the toolkit’s architecture, introducing a fully modular structure, centralized logic, and improved maintainability.

#### ✨ Added
- **Modular architecture**: split monolithic scripts into dedicated modules under `modules/`:
  - `utils.sh`, `pkg_install.sh`, `apparmor.sh`
  - `config_generator.sh`, `smtp_audit.sh`, `smtp_test.sh`, `list_accounts.sh`
  - `smtp_presets.sh`, `smtp_presets_validator.sh`, `account_duplicates_validator.sh`
- **`install_msmtp_armored.sh`**: secure, end-to-end installation script with:
  - Dependency installation
  - AppArmor profile enablement
  - Config generation
  - Audit with JSON + table output
  - Conditional SMTP tests
  - Final summary
- **`docs/DEV_GUIDE.md`**: guardrails for major changes, coding standards, and directory structure.
- **`docs/Quick_start.md`**: updated with new install flow, diagrams, and usage examples.
- **`config/`** directory for base templates (`msmtprc.template`).
- **`dev-env/`** directory for Docker-based development environment.

#### 🔄 Changed
- **Repository structure**:
  - Moved `Quick_start.md` from `modules/` to `docs/`.
  - Renamed `tests/` to `test/` for consistency.
  - Centralized shared logic to avoid duplication.
- **`quick_test.sh`**: aligned with new architecture and error accumulation workflow.
- Updated documentation to reflect new directory layout and workflows.
- Improved audit and test scripts to produce both human-readable tables and machine-readable JSON.

#### 🛠 Fixed
- Consistent handling of `.env` files (global and per-account).
- Improved error accumulation and exit codes for CI/CD integration.
- Removed unused or obsolete scripts from previous architecture.

#### 📄 Documentation
- Added flow diagrams for `install_msmtp_armored.sh` and `quick_test.sh`.
- Expanded usage examples and tips in `Quick_start.md`.
- Added Spanish translations for key docs in `docs/es/`.

---

**Tag(s)**:  
- `v0.4` – semantic version tag for this release.  
- `modular-architecture` – alias tag marking the major architectural redesign.


## [0.3] - 2025-09-17
### Added
- Development environment files and documentation

### Changed
- N/A

### Fixed
- N/A

### Removed
- N/A

## [0.2] - 2025-09-16
### Added
- Spanish documentation

### Changed
- Inline documentation was changed to english for global support.

### Fixed
- N/A

### Removed
- N/A


## [0.1] - 2025-09-16
### Added
- Initial repository structure with `config/`, `docs/`, and `test/` folders.
- Main script `install_msmtp_armored.sh` with:
- Secure installation of msmtp and dependencies.
- Configuration via the `config/msmtprc.template` template.
- Integration with AppArmor.
- Integrated send testing with separate logging.
- Documentation:
- `README.md` with installation and usage guide.
- `docs/USAGE.md` with examples and diagnostics.
- `docs/SECURITY.md` with security measures.
- `docs/APPARMOR.md` with configuration and overrides.
- Auxiliary scripts:
- `test/test_send_mail.sh` for standalone testing.
- Control files:
- `.gitignore` adapted to avoid uploading credentials and logs.
- `.gitattributes` to normalize line endings and protect templates.
- Bilingual MIT LICENSE (official English + Spanish translation).