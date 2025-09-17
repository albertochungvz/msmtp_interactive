# test_send_mail.sh doc

## 🔹 Características

- Interactivo: pide el correo de destino.
- Seguro: no expone contraseñas ni modifica `/etc/msmtprc.`
- Debug activado: usa `--debug` para mostrar el flujo SMTP y facilitar diagnóstico.
- Registro separado: guarda la salida en `/var/log/msmtp/test_send_mail.log` para no mezclar con el log de producción.
- Limpieza automática: borra el archivo temporal del mensaje.

## 📌 Uso

```bash
# Hace ejecutable el script
chmod +x tests/test_send_mail.sh
# Ejecuta el script 
sudo ./tests/test_send_mail.sh
```

> 💡 Si el usuario que ejecuta el script no es el mismo que usa msmtp en producción (por ejemplo, www-data), ajusta permisos del log o ejecuta como ese usuario para simular el entorno real.