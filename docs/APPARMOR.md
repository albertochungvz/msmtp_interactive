# Configuring AppArmor for msmtp

This document explains how to keep `msmtp` confined with AppArmor and allow logging to secure paths.

---

## 📍 Profile Status

To check if `msmtp` is confined:

```bash
sudo aa-status | grep msmtp
```

Expected Output:

```bash
msmtp
msmtp//helpers
```

---

## 📂 Default Allowed Paths

The `/etc/apparmor.d/usr.bin.msmtp` profile allows:

- Log files in the user's `$HOME` (`~/.msmtp*.log`).

- The `/var/log/msmtp/` directory (not individual files in `/var/log`).

---

## ➕ Add permissions for logs
It is recommended to log to `/var/log/msmtp/msmtp.log` instead of `$HOME`, to preserve the security and integrity of the logs:

1. Create a local override:

```bash
sudo mkdir -p /etc/apparmor.d/local
sudo nano /etc/apparmor.d/local/usr.bin.msmtp
```

2. Add rules:

```bash
/var/log/msmtp/ rw,
/var/log/msmtp/msmtp.log rwk,
```

3. Reload profile:

```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.bin.msmtp
```

---

## 🛠 Operation modes

* Enforce: Blocks disallowed access and logs them.

```bash
sudo aa-enforce /usr/bin/msmtp
```

* Complain: Allows access but logs violations (useful for debugging).

```bash
sudo aa-complain /usr/bin/msmtp
```

---

## 📌 Tips

* Keep `msmtp` in enforce mode in production.

* Use local overrides to customize paths without modifying the main profile.

* Check for denials with:

```bash
sudo journalctl -k | grep -i apparmor | grep msmtp
```

---

## 📚 References

* [Official msmtp manual](https://marlam.de/msmtp/msmtp.html)

* [AppArmor documentation on Ubuntu](https://documentation.ubuntu.com/server/how-to/security/apparmor/)