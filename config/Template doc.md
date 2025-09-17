# msmtprc.template

## 🔹 Cómo usar esta plantilla

- El script `install_msmtp_secure.sh` puede copiar esta plantilla a `/etc/msmtprc` y reemplazar las variables `{{...}}` con los valores introducidos por el usuario.
- Si configuras manualmente:
    1. Copia `config/msmtprc.template` a `/etc/msmtprc`.
    2. Sustituye las variables por valores reales.
    3. Crea el archivo de contraseña en `/etc/msmtp/` con permisos `600` y propietario `root:root`.
    4. Prueba el envío con:
        ```bash
        echo -e "Subject: Test\n\nHola" | msmtp -a default -t tu@correo.com --debug
        ```
