# Contribution Guidelines

Thank you for your interest in contributing to this project!
Your help is valuable in maintaining and improving this secure **msmtp** installation and configuration script.

---

## 📜 Code of Conduct
This project follows a **Code of Conduct** based on respect, inclusion, and constructive collaboration.
By participating, you agree to abide by it at all times.

---

## 🛠 Types of Contributions
You can contribute in several ways:

- **Reporting Bugs**: Open an *issue* with a clear description, steps to reproduce it, and the environment.
- **Improvement Suggestions**: Describe the proposed functionality and its benefit.
- **Documentation**: Fix bugs, expand examples, or add guides.
- **Code**: Fix bugs, add features, or improve security.

---

## 📂 Contribution Workflow

1. Fork the repository.
2. Create a branch for your change:
bash
git checkout -b fix/friendly-name


3. Make your changes following the style guides.
4. Run the tests (tests/test_send_mail.sh) and verify that everything works.
5. Update the documentation if necessary.
6. Update the CHANGELOG.md:
- Add your changes to the [Unreleased] section under the appropriate category (Added, Changed, Fixed, Removed).
7. Commit following the messaging convention (see below).
8. Send a Pull Request clearly describing the change.

---

## 🖋 Commit Convention

We use the [Conventional Commits](https://www.conventionalcommits.org/v1.0.0/) format:

```bash
<type>: <short description>

[optional body]
```

Common types:

- `**feat**`: New functionality.
- `**fix**`: Bug fix.
- `**docs**`: Documentation changes.
- `**chore**`: Maintenance tasks.
- `**refactor**`: Code changes without altering functionality.
- `**test**`: Add or modify tests.

Example:

```bash
feat: Add msmtp version validation in main script

- Automatically detect if the version supports set_from_header
- Display a warning if it's old
```

---

🔍 Code Style

- Bash scripts with `set -Eeuo pipefail`.
- Indentation with 2 spaces.
- Capitalize variables for constants and environment parameters.
- Do not expose credentials in logs or history.
- Maintain compatibility with AppArmor.

---

✅ Testing

Before submitting changes:

- Run `tests/test_send_mail.sh` to validate the submission.
- Verify that the clean install doesn't break.
- Check that permissions and paths comply with security guidelines.

---

📦 Release Versions

- Releases follow **Semantic Versioning**.
- Each new version must:
- Move changes from `[Unreleased]` to the new version in `CHANGELOG.md`.
- Create a tag (`git tag -a vX.Y.Z -m "Description"`).
- Push a tag to the remote (`git push origin --tags`).

Thanks for helping make this project more secure and useful for everyone!