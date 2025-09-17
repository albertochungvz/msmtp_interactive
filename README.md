# Securely Configuring msmtp with AppArmor on Ubuntu Server

This project provides a reproducible and interactive Bash script to install and configure `msmtp` on Ubuntu Server with:

- AppArmor enabled and tuned for secure logging.
- TLS and certificate validation.
- Secure password management with `passwordeval`.
- Production-ready msmtprc template.
- Automatic push testing.

---

## 🚀 Features

- Installation of `msmtp`, `msmtp-mta`, `mailutils`, `ca-certificates`, `AppArmor` dependencies, and utilities.
- Verification and reinstallation of the CA bundle if necessary.
- Enable AppArmor in *enforce* mode for `msmtp`
- Create a directory and log file in `/var/log/msmtp/` with AppArmor-compatible permissions.
- Generate a secure and compatible `/etc/msmtprc`.
- Interactively request credentials without exposing them to history or processes.
- Send test emails and save the log to `/var/log/msmtp/test_send_mail.log`.

---

## 📦 Requirements

- Ubuntu Server 20.04 or higher.
- Root access (`sudo`).
- Internet connection to install packages.
- Valid SMTP credentials (username, password, or App Password).

---

## 📂 Repository structure

```bash
msmtp-setup/
├── config/
│ └── msmtprc.template # Template with expected variables
│
├── docs/
│ ├── USAGE.md 
│ ├── SECURITY.md 
│ ├── APPARMOR.md 
│ │
│ └── es/                   # Official Spanish translations
│       ├── APPARMOR.md     # Spanish AppArmor configuration
│       ├── CHANGELOG.md
│       ├── CONTRIBUTING.md
│       ├── README.md
│       ├── SECURITY.md     # Spanish security notes
│       └── USAGE.md        # Spanish usage guide
│
├── tests/
│ └── test_send_mail.sh     # Standalone test script with commented header
├── .gitattributes          # Normalizes line endings, marks binaries
├── .gitignore              # Ignores credentials, logs, and temps
├── CHANGELOG.md            # Changelog (initial v0.1)
├── CONTRIBUTING.md         # Guide contribution
├── LICENSE                 # Bilingual MIT (official English + translation)
├── README.md               # Main script in English, link to docs/es/README.md
└── install_msmtp_armored.sh # Main script with secure installation and integrated testing
```

---

## 🔧 Installation

Clone the repository and run the script:

```bash
git clone https://github.com/albertochungvz/msmtp_interactive.git
cd msmtp-setup
chmod +x install_msmtp_armored.sh
sudo ./install_msmtp_armored.sh
```

During execution, the script will prompt you for:

- SMTP server and port.
- Sender address and name.
- SMTP username.
- Password file and value (stored securely).
- Test email.

---

## 🛡 Security

- Plain text passwords are not saved in the history or across processes.
- The log is stored in `/var/log/msmtp/msmtp.log` with restrictive permissions.
- AppArmor is kept in *enforce mode* for `msmtp`.
- The SMTP server's TLS certificate is validated.

See [SECURITY.md](/docs/SECURITY.md) for more details.

---

## 🧪 Test Send
The script will send a test email upon completion. You can send it manually with:

```bash
echo -e "Subject: Test\n\nHello" | msmtp -a default -t recipient@mail.com
```

---

## 📜 License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.

---

## 🤝 Contributions
Contributions are welcome. Please open an issue or submit a pull request with improvements or corrections.

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

> ⚠ Warning: Do not upload files with real credentials (*.pw) or logs with sensitive information to this repository.