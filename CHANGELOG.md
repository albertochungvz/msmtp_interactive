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
- Initial repository structure with `config/`, `docs/`, and `tests/` folders.
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
- `tests/test_send_mail.sh` for standalone testing.
- Control files:
- `.gitignore` adapted to avoid uploading credentials and logs.
- `.gitattributes` to normalize line endings and protect templates.
- Bilingual MIT LICENSE (official English + Spanish translation).