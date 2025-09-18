# Configuración segura de msmtp con AppArmor en Ubuntu Server

Este proyecto proporciona un **script Bash reproducible e interactivo** para instalar y configurar `msmtp` en **Ubuntu Server** con:

- **AppArmor** habilitado y ajustado para logs seguros.
- **TLS** y validación de certificados.
- **Gestión segura de contraseñas** con `passwordeval`.
- **Plantilla `msmtprc`** lista para producción.
- **Prueba de envío** automática.

---

## 🚀 Características

- Instalación de `msmtp`, `msmtp-mta`, `mailutils`, `ca-certificates`, dependencias y utilidades de AppArmor.
- Verificación y reinstalación del bundle de CA si es necesario.
- Habilita AppArmor en modo *enforce* para `msmtp`
- Creación de directorio y archivo de log en `/var/log/msmtp/` con permisos compatibles con AppArmor.
- Generación de `/etc/msmtprc` seguro y compatible.
- Solicitud interactiva de credenciales sin exponerlas en historial ni procesos.
- Envío de correo de prueba y almacenamiento del log en `/var/log/msmtp/test_send_mail.log`.

---

## 📦 Requisitos

- Ubuntu Server 20.04 o superior.
- Acceso root (`sudo`).
- Conexión a internet para instalar paquetes.
- Credenciales SMTP válidas (usuario, contraseña o App Password).

---

## 📂 Estructura del repositorio

```bash
msmtp-setup/
├── config/
│   └── msmtprc.template            # Plantilla con variables esperadas
│
├── dev-env/                        # Configura un entorno de desarrollo usando Docker
│       ├── docker-compose.yml
│       ├── Dockerfile
│       ├── msmtp_dev_env.sh
│       └── README.md
│
├── docs/
│   ├── USAGE.md                    # Guía de uso en inglés
│   ├── SECURITY.md                 # Notas de seguridad en inglés
│   ├── APPARMOR.md                 # Configuración de AppArmor en inglés
│   │
│   └── es/                         # Traducciones oficiales al español
│       ├── APPARMOR.md             # Configuración de AppArmor en español
│       ├── CHANGELOG.md            # Indicaciones para el control de cambios
│       ├── CONTRIBUTING.md
│       ├── README.md
│       ├── SECURITY.md             # Notas de seguridad en español
│       └── USAGE.md                # Guía de uso en español
│
├── test/
│   └── test_send_mail.sh           # Script de prueba independiente con encabezado comentado
├── .gitattributes                  # Normaliza finales de línea, marca binarios
├── .gitignore                      # Ignora credenciales, logs, temporales
├── CHANGELOG.md                    # Historial de cambios (v0.1 inicial)
├── CONTRIBUTING.md                 # Guía de contribución
├── LICENSE                         # MIT bilingüe (inglés oficial + traducción)
├── README.md                       # Principal en inglés, enlace a docs/es/README.md
└── install_msmtp_armored.sh         # Script principal con instalación segura y prueba integrada
```

---

## 🔧 Instalación

Clona el repositorio y ejecuta el script:

```bash
git clone https://github.com/albertochungvz/msmtp_interactive.git
cd msmtp-setup
chmod +x install_msmtp_armored.sh
sudo ./install_msmtp_armored.sh
```

Durante la ejecución, el script te pedirá:

- Servidor SMTP y puerto.
- Dirección y nombre del remitente.
- Usuario SMTP.
- Archivo y valor de la contraseña (guardado de forma segura).
- Correo de prueba.

---

## 🛡 Seguridad

- No se guardan contraseñas en texto plano en el historial ni en procesos.
- El log se almacena en /var/log/msmtp/msmtp.log con permisos restrictivos.
- AppArmor se mantiene en modo enforce para msmtp.
- Se valida el certificado TLS del servidor SMTP.

Consulta [SECURITY.md](SECURITY.md) para más detalles.

---

## 🧪 Prueba de envío
El script enviará un correo de prueba al finalizar. Puedes enviar manualmente con:

```bash
echo -e "Subject: Test\n\nHola" | msmtp -a default -t destinatario@correo.com
```

---

## 📜 Licencia
Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](../../LICENSE) para más información.

---

## 🤝 Contribuciones
Las contribuciones son bienvenidas. Por favor, abre un issue o envía un pull request con mejoras o correcciones.

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) para más detalles.


> ⚠ Advertencia: No subas a este repositorio archivos con credenciales reales (*.pw) ni logs con información sensible.

