# Guía de Uso de msmtp con AppArmor

Este documento explica cómo utilizar `msmtp` una vez instalado y configurado con el script de este repositorio, así como comandos de prueba y diagnóstico.

---

## 📬 Envío básico de correo

Para enviar un correo simple desde la terminal:

```bash
echo -e "Subject: Asunto de prueba\n\nCuerpo del mensaje" | msmtp -a default -t destinatario@correo.com
```

-a default → usa la cuenta llamada default en `/etc/msmtprc`.

-t → indica a msmtp que lea los destinatarios de la cabecera To: o de la línea de comando.

---

## 📂 Envío con múltiples cuentas
Si tienes varias cuentas configuradas en `/etc/msmtprc`:

```bash
echo -e "Subject: Prueba sitio1\n\nMensaje" | msmtp -a sitio1 -t destinatario@correo.com
```

---

## 🧪 Prueba de envío con depuración
Para ver el detalle de la conexión y autenticación:

```bash
echo -e "Subject: Debug\n\nTest" | msmtp -a default -t destinatario@correo.com --debug
```

Esto mostrará:

- Resolución DNS del servidor SMTP.
- Negociación TLS.
- Respuesta del servidor a cada comando SMTP.

---

## 📜 Revisión de logs


- Si usas el log en `/var/log/msmtp/msmtp.log`:

    ```bash
    sudo tail -f /var/log/msmtp/msmtp.log
    ```

- Si usas syslog:
    ```bash
    sudo tail -f /var/log/mail.log
    # o con journalctl
    sudo journalctl -t msmtp -f
    ```

---

## 🔍 Diagnóstico de problemas comunes
1. Error de certificado TLS
Mensaje: `Certificate verification failed`

    Solución:

    - Verifica que `/etc/ssl/certs/ca-certificates.crt` existe y no está vacío. Ejecuta:
        ```bash
        sudo update-ca-certificates
        ```
    - Comprueba la hora y fecha del sistema.

2. Error de permisos en log
Mensaje: `Cannot log to /var/log/msmtp/msmtp.log: cannot open: Permission denied`

    Solución:

    - Asegúrate de que el usuario que ejecuta `msmtp` tenga permisos de escritura.
    - Verifica que AppArmor permite la ruta (ver docs/APPARMOR.md).

3. Autenticación fallida
Mensaje: `Authentication failed`

    Solución:

    - Verifica usuario y contraseña.
    - Si el proveedor usa MFA, genera un App Password.
    - Comprueba que `passwordeval` apunta al archivo correcto.


---

## 📌 Consejos de uso

- Automatización: puedes usar msmtp en scripts de backup, cronjobs o alertas del sistema.
- PHP-FPM: configura `sendmail_path` en el pool para usar una cuenta específica.
- Rotación de logs: añade una regla en `/etc/logrotate.d/msmtp` para evitar crecimiento ilimitado.
Ejemplo de regla de *logrotate*:

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

## 📚 Referencias

- [Manual oficial de msmtp](https://marlam.de/msmtp/msmtp.html)
- [Documentación de AppArmor en Ubuntu](https://documentation.ubuntu.com/server/how-to/security/apparmor/)