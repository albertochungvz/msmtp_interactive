# Changelog
Todas las modificaciones notables de este proyecto se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/), y este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]
### Added
- N/A

### Changed
- N/A

### Fixed
- N/A

### Removed
- N/A


## [0.2] - 16/09/2025
### Añadido
- Documentación en español

### Modificado
- La documentación en línea se cambió a inglés para ofrecer soporte global.

### Corregido
- N/D

### Eliminado
- N/D


## [0.1] - 2025-09-16
### Añadido
- Estructura inicial del repositorio con carpetas `config/`, `docs/` y `tests/`.
- Script principal `install_msmtp_secure.sh` con:
  - Instalación segura de msmtp y dependencias.
  - Configuración vía plantilla `config/msmtprc.template`.
  - Integración con AppArmor.
  - Prueba de envío integrada con log separado.
- Documentación:
  - `README.md` con guía de instalación y uso.
  - `docs/USAGE.md` con ejemplos y diagnóstico.
  - `docs/SECURITY.md` con medidas de seguridad.
  - `docs/APPARMOR.md` con configuración y overrides.
- Scripts auxiliares:
  - `tests/test_send_mail.sh` para pruebas independientes.
- Archivos de control:
  - `.gitignore` adaptado para evitar subir credenciales y logs.
  - `.gitattributes` para normalizar finales de línea y proteger plantillas.
  - `LICENSE` MIT bilingüe (inglés oficial + traducción al español).

### Modificado
- N/D

### Corregido
- N/D

### Eliminado
- N/D