# Guía de Seguridad para Configuración de msmtp

Este documento describe las medidas de seguridad implementadas en este proyecto y las recomendaciones para mantener un entorno seguro al usar `msmtp` en Ubuntu Server.


## 🔒 Principios clave

1. **Defensa en profundidad**  
   - Uso de AppArmor en modo `enforce` para confinar `msmtp`.
   - Validación estricta de certificados TLS (`tls_certcheck on`).

2. **Protección de credenciales**  
   - Uso de `passwordeval` para leer contraseñas desde archivos con permisos `600` y propietario `root:root`.
   - Directorio `/etc/msmtp/` con permisos `700` para almacenar secretos.
   - Recomendado: usar *App Passwords* en lugar de contraseñas principales.

3. **Logs seguros**  
   - Registro en `/var/log/msmtp/msmtp.log` con permisos restrictivos (`640`) y propietario controlado.
   - Carpeta `/var/log/msmtp/` con permisos `750`, compatible con AppArmor.
   - Alternativa: uso de `syslog LOG_MAIL` para centralizar en `/var/log/mail.log`.

4. **TLS y cifrado**  
   - Uso de puertos seguros: `587` (STARTTLS) o `465` (SMTPS).
   - `tls_trust_file` apuntando al bundle del sistema `/etc/ssl/certs/ca-certificates.crt`.
   - Posibilidad de endurecer cifrados con `tls_priorities`.

5. **Permisos y aislamiento**  
   - Evitar logs o archivos sensibles en `$HOME` en entornos multiusuario.
   - Un archivo de contraseña por cuenta SMTP, con permisos mínimos.
   - Cuentas de sistema separadas para servicios que envían correo.


## 🚫 Prácticas a evitar

- Guardar contraseñas en texto plano en `msmtprc`.
- Desactivar `tls_certcheck` en producción.
- Usar permisos laxos (`777`) en directorios o archivos de configuración.
- Deshabilitar AppArmor sin una justificación técnica sólida.


## 📌 Referencias

- [Manual oficial de msmtp](https://marlam.de/msmtp/msmtp.html)
- [Documentación de AppArmor en Ubuntu](https://documentation.ubuntu.com/server/how-to/security/apparmor/)
