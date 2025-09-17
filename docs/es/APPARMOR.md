# Configuración de AppArmor para msmtp

Este documento explica cómo mantener `msmtp` confinado con AppArmor y permitir el registro en rutas seguras.

---

## 📍 Estado del perfil

Para verificar si `msmtp` está confinado:

```bash
sudo aa-status | grep msmtp
```

Salida esperada:

```bash
msmtp
msmtp//helpers
```

---

## 📂 Rutas permitidas por defecto

El perfil `/etc/apparmor.d/usr.bin.msmtp` permite:

- Archivos de log en `$HOME` del usuario (`~/.msmtp*.log`).

- Directorio `/var/log/msmtp/` (no archivos sueltos en `/var/log`).

---

## ➕ Añadir permisos para logs
Se recomienda registrar en `/var/log/msmtp/msmtp.log` en vez de en el `$HOME`, a fin de preservar la seguridad e integridad de los registros:

1. Crear override local:

    ```bash
    sudo mkdir -p /etc/apparmor.d/local
    sudo nano /etc/apparmor.d/local/usr.bin.msmtp
    ```

2. Añadir reglas:

    ```bash
    /var/log/msmtp/ rw,
    /var/log/msmtp/msmtp.log rwk,
    ```

3. Recargar perfil:

    ```bash
    sudo apparmor_parser -r /etc/apparmor.d/usr.bin.msmtp
    ```

---

## 🛠 Modos de operación

* Enforce: bloquea accesos no permitidos y los registra.

```bash
sudo aa-enforce /usr/bin/msmtp
```

* Complain: permite accesos pero registra violaciones (útil para depuración).

```bash
sudo aa-complain /usr/bin/msmtp
```

---

## 📌 Consejos

* Mantener `msmtp` en modo enforce en producción.

* Usar overrides locales para personalizar rutas sin modificar el perfil principal.

* Revisar denegaciones con:

```bash
sudo journalctl -k | grep -i apparmor | grep msmtp
```

---

## 📚 Referencias

* [Manual oficial de msmtp](https://marlam.de/msmtp/msmtp.html)

* [Documentación de AppArmor en Ubuntu](https://documentation.ubuntu.com/server/how-to/security/apparmor/)