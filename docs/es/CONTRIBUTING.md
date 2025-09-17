# Guía de Contribución

¡Gracias por tu interés en contribuir a este proyecto!  
Tu ayuda es valiosa para mantener y mejorar este script seguro de instalación y configuración de **msmtp**.

---

## 📜 Código de Conducta
Este proyecto sigue un **Código de Conducta** basado en el respeto, la inclusión y la colaboración constructiva.  
Al participar, aceptas cumplirlo en todo momento.

---

## 🛠 Tipos de contribuciones
Puedes contribuir de varias formas:

- **Reportando errores**: abre un *issue* con una descripción clara, pasos para reproducirlo y entorno.
- **Sugerencias de mejora**: describe la funcionalidad propuesta y su beneficio.
- **Documentación**: corrige errores, amplía ejemplos o añade guías.
- **Código**: corrige bugs, añade funciones o mejora la seguridad.

---

## 📂 Flujo de trabajo para contribuir

1. **Haz un fork** del repositorio.
2. **Crea una rama** para tu cambio:
   ```bash
   git checkout -b fix/nombre-descriptivo
   ```

3. Realiza tus cambios siguiendo las guías de estilo.
4. Ejecuta las pruebas (`tests/test_send_mail.sh`) y verifica que todo funciona.
5. Actualiza la documentación si es necesario.
6. Actualiza el `CHANGELOG.md`:
    - Añade tus cambios en la sección [Unreleased] bajo la categoría orrespondiente (Added, Changed, Fixed, Removed).
7. Haz commit siguiendo la convención de mensajes (ver abajo).
8. Envía un Pull Request describiendo claramente el cambio.

---

## 🖋 Convención de commits

Usamos el formato [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/):  

```bash
<tipo>: <descripción breve>

[cuerpo opcional]
```

Tipos comunes:

- `**feat**`: nueva funcionalidad.
- `**fix**`: corrección de error.
- `**docs**`: cambios en documentación.
- `**chore**`: tareas de mantenimiento.
- `**refactor**`: cambios de código sin alterar funcionalidad.
- `**test**`: añadir o modificar pruebas.

Ejemplo:

```bash
feat: añadir validación de versión de msmtp en script principal

- Detecta automáticamente si la versión soporta set_from_header
- Muestra aviso si es antigua
```

---

🔍 Estilo de código

- Scripts en Bash con `set -Eeuo pipefail`.
- Indentación con 2 espacios.
- Variables en mayúsculas para constantes y parámetros de entorno.
- No exponer credenciales en logs ni en el historial.
- Mantener compatibilidad con AppArmor.

---

✅ Pruebas

Antes de enviar cambios:

- Ejecuta `tests/test_send_mail.sh` para validar el envío.
- Verifica que no se rompa la instalación en limpio.
- Comprueba que los permisos y rutas cumplen las guías de seguridad.

---

📦 Publicación de versiones

- Las versiones siguen **Semantic Versioning**.
- Cada nueva versión debe:
    - Mover cambios de `[Unreleased]` a la nueva versión en `CHANGELOG.md`.
    - Crear etiqueta (`git tag -a vX.Y.Z -m "Descripción"`).
    - Subir etiqueta a remoto (`git push origin --tags`).

¡Gracias por ayudar a que este proyecto sea más seguro y útil para todos!