# AppArmor Usage Guide for msmtp

This document explains how to use `msmtp` once installed and configured with the script in this repository, as well as testing and diagnostic commands.

---

## 📬 Basic Email Sending

To send a simple email from the terminal:

```bash
echo -e "Subject: Test Subject\n\nMessage Body" | msmtp -a default -t recipient@mail.com
```

-a default → Use the account named default in `/etc/msmtprc`.

-t → Tells msmtp to read recipients from the To: header or the command line.

---

## 📂 Sending with Multiple Accounts
If you have multiple accounts configured in `/etc/msmtprc`:

```bash
echo -e "Subject: Test site1\n\nMessage" | msmtp -a site1 -t recipient@mail.com
```

---

## 🧪 Sending Test with Debugging
To see connection and authentication details:

```bash
echo -e "Subject: Debug\n\nTest" | msmtp -a default -t recipient@mail.com --debug
```

This will show:

- DNS resolution of the SMTP server.
- TLS negotiation.
- Server response to each SMTP command.

---

## 📜 Log Review

- If you use the log in `/var/log/msmtp/msmtp.log`:

```bash
sudo tail -f /var/log/msmtp/msmtp.log
```

- If you use syslog:
```bash
sudo tail -f /var/log/mail.log
# or with journalctl
sudo journalctl -t msmtp -f
```

---
## 🔍 Troubleshooting Common Problems
1. TLS Certificate Error
Message: `Certificate verification failed`

    Solution:

    - Verify that `/etc/ssl/certs/ca-certificates.crt` exists and is not empty. Run:
    ```bash
    sudo update-ca-certificates
    ```
    - Check the system time and date.

2. Log Permission Error
Message: `Cannot log to /var/log/msmtp/msmtp.log: cannot open: Permission denied`

    Solution:

    - Make sure the user running `msmtp` has write permissions.
    - Verify that AppArmor allows the path (see docs/APPARMOR.md).

3. Authentication Failed
Message: `Authentication failed`

    Solution:

    - Verify username and password.
    - If the provider uses MFA, generate an App Password.
    - Check that `passwordeval` points to the correct file.

---

## 📌 Usage Tips

- Automation: You can use msmtp in backup scripts, cronjobs, or system alerts.
- PHP-FPM: Set `sendmail_path` in the pool to use a specific account.
- Log rotation: Add a rule in `/etc/logrotate.d/msmtp` to prevent unlimited growth.
Example *logrotate* rule:

```bash
/var/log/msmtp/msmtp.log {
weekly
rotate 12
compress
missingok
notifempty
create 640 root adm 
}
```

---

## 📚 References

- [Official msmtp manual](https://marlam.de/msmtp/msmtp.html)
- [AppArmor documentation on Ubuntu](https://documentation.ubuntu.com/server/how-to/security/apparmor/)