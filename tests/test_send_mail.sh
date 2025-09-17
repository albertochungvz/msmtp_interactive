#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# Configuración
# =========================
ACCOUNT="default"   # Nombre de la cuenta en /etc/msmtprc
LOGFILE="/var/log/msmtp/test_send_mail.log"
TMPMSG="$(mktemp /tmp/msmtp-test.XXXXXX)"

# =========================
# Funciones
# =========================
abort() {
  echo "ERROR: $*" >&2
  exit 1
}

prompt() {
  local var="$1" msg="$2" def="${3-}"
  local input
  if [[ -n "$def" ]]; then
    read -r -p "$msg [$def]: " input || abort "Entrada cancelada"
    input="${input:-$def}"
  else
    read -r -p "$msg: " input || abort "Entrada cancelada"
  fi
  printf -v "$var" '%s' "$input"
}

# =========================
# Solicitar datos
# =========================
prompt RECIPIENT "Correo de destino para la prueba"

# =========================
# Preparar mensaje
# =========================
{
  echo "To: $RECIPIENT"
  echo "Subject: Prueba msmtp - $(hostname)"
  echo
  echo "Hola,"
  echo
  echo "Este es un mensaje de prueba enviado con msmtp."
  echo "Fecha: $(date -Is)"
  echo "Host: $(hostname -f 2>/dev/null || hostname)"
  echo
  echo "Si recibes este mensaje, la configuración es correcta."
} > "$TMPMSG"

# =========================
# Envío
# =========================
echo "==> Enviando mensaje de prueba..."
if msmtp --debug -a "$ACCOUNT" -t < "$TMPMSG" 2>&1 | tee "$LOGFILE"; then
  echo "==> Mensaje enviado. Revisa el buzón de $RECIPIENT"
else
  abort "Fallo en el envío. Revisa $LOGFILE para más detalles."
fi

# =========================
# Limpieza
# =========================
rm -f "$TMPMSG"

echo "==> Log de prueba guardado en: $LOGFILE"
echo "==> Fin de la prueba."