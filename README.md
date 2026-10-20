# DenuPe (PMV1)

Aplicación móvil de **denuncias ciudadanas** (versión PMV1 / registro de denuncias).
Los vecinos crean una cuenta, reportan un problema de su distrito y hacen
seguimiento del estado de su denuncia con notificaciones.

> **Rama:** `feature/pmv1-registro-denuncias` · Flutter sobre InsForge (Postgres BaaS)

---

## Funcionalidades de esta versión

### Cuenta de usuario
- **Registro** con nombre, correo y contraseña, con **verificación por código**
  enviado al correo.
- **Inicio y cierre de sesión**; la sesión se restaura al volver a abrir la app.

### Registrar una denuncia
- Formulario con:
  - **Categoría** (alumbrado, seguridad, limpieza, agua, etc.).
  - **Título** y **descripción** del problema.
  - **Dirección o referencia** (opcional).
  - **Ubicación** con el GPS del teléfono (opcional).
- Al enviar, la denuncia se guarda con estado inicial **Recibida**.

### Seguimiento
- **Mis denuncias**: lista de todas tus denuncias con su estado actual.
- **Detalle de la denuncia**: descripción, categoría, ubicación, fecha e
  **historial de cambios de estado**.
- **Alertas**: notificaciones in-app que se actualizan en tiempo real cuando tu
  denuncia cambia de estado (Recibida → En revisión → En proceso → Resuelta).

---

## Descarga e instalación

### APK de esta versión
El APK de la rama PMV1 está disponible en el repositorio como
**`denupe-pmv1.apk`**.

1. Descarga `denupe-pmv1.apk`.
2. En el teléfono Android, abre el archivo descargado.
3. Si el sistema lo pide, permite la instalación desde **"Orígenes desconocidos"**
   o **"Instalar esta app"** para este instalador.
4. Confirma la instalación y abre **DenuPe**.

---

## Requisitos
- Android 8.0 (API 26) o superior.
- Conexión a internet (la app usa un backend en la nube).

## Soporte
Reporta incidencias o ideas en
[https://github.com/Zarabia-22/denupe/issues](https://github.com/Zarabia-22/denupe/issues).