#!/usr/bin/env bash
set -Eeuo pipefail

# ========= utilidades de seguridad y manejo de errores =========
abort() {
  echo "ERROR: $*" >&2
  exit 1
}
trap 'abort "Fallo en la línea $LINENO (comando: $BASH_COMMAND)"' ERR

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    abort "Ejecuta este script como root (sudo)."
  fi
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
  [[ -n "$input" ]] || abort "El valor no puede estar vacío."
  printf -v "$var" '%s' "$input"
}

prompt_secret_to_file() {
  local dest="$1"
  local prompt_msg="$2"

  install -d -m 700 -o root -g root "$(dirname "$dest")"

  local HIST_WAS_ON=1
  if set -o | grep -q 'history[[:space:]]\+on'; then
    set +o history
  else
    HIST_WAS_ON=0
  fi

  local secret=''
  while true; do
    read -r -s -p "$prompt_msg: " secret || abort "Entrada cancelada"
    echo
    [[ -n "$secret" ]] && break
    echo "El valor no puede estar vacío."
  done

  umask 177
  printf '%s' "$secret" > "$dest"
  chown root:root "$dest"
  chmod 600 "$dest"
  secret=''

  if [[ $HIST_WAS_ON -eq 1 ]]; then
    set -o history
  fi
}

ensure_pkg() {
  local pkgs=("$@")
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
}

ensure_apparmor_enforce() {
  systemctl is-enabled apparmor >/dev/null 2>&1 || systemctl enable apparmor
  systemctl is-active apparmor >/dev/null 2>&1 || systemctl start apparmor
  if command -v aa-enforce >/dev/null 2>&1 && [[ -e /usr/bin/msmtp ]]; then
    aa-enforce /usr/bin/msmtp || true
  fi
}

msmtp_supports_from_fields() {
  local v
  v="$(msmtp --version | awk 'NR==1{print $2}')" || echo "0.0.0"
  dpkg --compare-versions "$v" ge "1.8.8"
}

# ===================== flujo principal =====================
require_root

echo "==> Instalando paquetes requeridos"
ensure_pkg ca-certificates msmtp msmtp-mta mailutils apparmor apparmor-utils

echo "==> Verificando bundle de CA"
if [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
  echo "Bundle de CA ausente o vacío. Reinstalando..."
  apt-get install -y --reinstall ca-certificates
  update-ca-certificates
fi

echo "==> Habilitando AppArmor para msmtp (enforce)"
ensure_apparmor_enforce

echo "==> Preparando directorio y archivo de log compatibles con AppArmor"
install -d -m 750 -o root -g adm /var/log/msmtp
touch /var/log/msmtp/msmtp.log
chown root:adm /var/log/msmtp/msmtp.log
chmod 640 /var/log/msmtp/msmtp.log

# ========= recopilar datos de configuración =========
echo "==> Recopilando parámetros de la cuenta SMTP por defecto"
prompt SMTP_HOST      "Servidor SMTP (host)" "smtp.example.com"
prompt SMTP_PORT      "Puerto SMTP" "587"
prompt FROM_ADDR      "Dirección From por defecto" "no-reply@midominio.com"
prompt FROM_NAME      "Nombre completo del remitente (From Full Name)" "Midominio Notificaciones"
prompt SMTP_USER      "Usuario SMTP" "$FROM_ADDR"

TLS_MODE="starttls"
if [[ "$SMTP_PORT" == "465" ]]; then
  TLS_MODE="smtps"
fi

echo "==> Definiendo ubicación de la contraseña segura"
prompt SECRET_FILE "Nombre de archivo de contraseña (sin ruta)" "default.pw"
SECRET_PATH="/etc/msmtp/$SECRET_FILE"
prompt_secret_to_file "$SECRET_PATH" "Introduce la contraseña (o App Password) SMTP"

# ========= generar /etc/msmtprc =========
echo "==> Generando /etc/msmtprc con plantilla segura"
umask 177
{
  echo "# ========================="
  echo "# Configuración global"
  echo "# ========================="
  echo "defaults"
  echo "auth                 on"
  echo "tls                  on"
  if [[ "$TLS_MODE" == "starttls" ]]; then
    echo "tls_starttls         on"
  else
    echo "tls_starttls         off"
  fi
  echo "tls_trust_file       /etc/ssl/certs/ca-certificates.crt"
  echo "tls_certcheck        on"
  echo "logfile              /var/log/msmtp/msmtp.log"
  echo "aliases              /etc/aliases"
  if msmtp_supports_from_fields; then
    echo "set_from_header      on"
  fi
  echo
  echo "# ========================="
  echo "# Cuenta por defecto"
  echo "# ========================="
  echo "account              default"
  echo "host                 $SMTP_HOST"
  echo "port                 $SMTP_PORT"
  echo "from                 $FROM_ADDR"
  if msmtp_supports_from_fields; then
    echo "from_full_name       \"$FROM_NAME\""
  fi
  echo "user                 $SMTP_USER"
  echo "passwordeval         \"cat $SECRET_PATH\""
} > /etc/msmtprc

chown root:root /etc/msmtprc
chmod 600 /etc/msmtprc

# ========= prueba de envío integrada =========
echo "==> Realizando prueba de envío integrada"
read -r -p "Introduce el correo de destino para la prueba: " TEST_RECIPIENT
TEST_LOG="/var/log/msmtp/test_send_mail.log"
TMPMSG="$(mktemp /tmp/msmtp-test.XXXXXX)"

{
  echo "To: $TEST_RECIPIENT"
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

if msmtp --debug -a default -t < "$TMPMSG" 2>&1 | tee "$TEST_LOG"; then
  echo "==> Mensaje enviado. Revisa el buzón de $TEST_RECIPIENT"
else
  echo "ERROR: Fallo en el envío. Revisa $TEST_LOG para más detalles."
fi

rm -f "$TMPMSG"
echo "==> Log de prueba guardado en: $TEST_LOG"

echo "==> Instalación y prueba completadas."
