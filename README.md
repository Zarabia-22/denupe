# DenuPe

Aplicación móvil de **denuncias ciudadanas**: los vecinos reportan problemas de su
distrito (alumbrado, seguridad, limpieza, agua, etc.) y las entidades responsables
(municipalidad, comisaría, serenazgo) los reciben, se asignan y se atienden hasta
su resolución.

> **Versión:** 1.0.0 (beta) · Flutter / InsForge (Postgres BaaS)

---

## Funcionalidades

### Ciudadanos
- **Cuenta y perfil**: registro con verificación de correo, inicio de sesión y
  perfil editable (nombre, DNI, teléfono, distrito). La denuncia se bloquea si el
  perfil está incompleto.
- **Nueva denuncia**: formulario con categoría, título, descripción, dirección,
  ubicación GPS y hasta 5 fotos/videos. Los datos del denunciante (nombre, DNI,
  correo y teléfono) se toman automáticamente del perfil.
- **Confirmación previa**: antes de terminar se muestra un resumen de la denuncia
  y el ciudadano elige el **tipo de entidad** que la atenderá
  (Municipalidad / Comisaría / Serenazgo); el sistema asigna la entidad concreta.
- **Seguimiento**: "Mis denuncias" muestra el estado en tiempo real
  (Recibida → En revisión → En proceso → Resuelta), el historial completo de
  cambios con notas y las evidencias adjuntas.
- **Alertas**: notificaciones in-app en tiempo real de cada cambio de estado.

### Funcionarios (entidades)
- **Panel municipal**: lista de denuncias asignadas a su entidad, con datos del
  denunciante (nombre, DNI, correo y teléfono) para contactarlo.
- **Gestión de estados**: cambia el estado de cada denuncia con nota opcional; el
  ciudadano recibe la alerta al instante.
- Solo la entidad responsable (o un administrador) puede modificar el estado de
  cada denuncia.

---

## Descarga e instalación (beta)

### Opción 1: desde GitHub Releases (recomendada)
1. Abre la release **["denupe (beta)"](https://github.com/Zarabia-22/denupe/releases/tag/v1.0.0)**.
2. Descarga el archivo `denupe.beta.apk`.
3. En el teléfono Android, abre el archivo descargado.
4. Si el sistema lo pide, permite la instalación **"Orígenes desconocidos"** o
   **"Instalar esta app"** para este instalador.
5. Confirma la instalación y abre **DenuPe**.

### Cuenta demo (funcionario)
Para probar el panel de la entidad, inicia sesión con:

- **Correo:** `funcionario.municipal@denupe.test`
- **Contraseña:** `Funcionario123`

*(Es una cuenta de prueba de la versión beta; los ciudadanos se registran desde
la misma app con su propio correo.)*

---

## Requisitos
- Android 8.0 (API 26) o superior.
- Conexión a internet (la app usa el backend en la nube).

## Soporte
Reporta incidencias o ideas en
[https://github.com/Zarabia-22/denupe/issues](https://github.com/Zarabia-22/denupe/issues).