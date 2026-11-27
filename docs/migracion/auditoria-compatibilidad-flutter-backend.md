# Auditoría de compatibilidad: Flutter → Backend DenuPe en Render

**Rama:** `feature/migracion-final-backend-r2`  
**Base:** `develop`  
**Estado:** cliente HTTP y módulos REST/R2 implementados en esta rama; CI de Flutter en corrección final. InsForge SDK/variables se conservan hasta regresión aprobada.

## Objetivo y reglas

La aplicación Flutter debe consumir el backend principal `https://denupe-backend.onrender.com` para autenticación, perfiles, catálogos, denuncias, historial, evidencias y notificaciones. Cloudflare R2 se consume exclusivamente mediante URLs prefirmadas emitidas por el backend.

- Mantener InsForge activo e intacto durante toda la migración y el periodo de validación.
- No modificar `denupe-ia-backend`.
- No publicar secretos ni incluir tokens/URLs prefirmadas en logs.
- No cambiar la interfaz ni la lógica de negocio fuera del alcance de cada etapa.
- No activar el cambio de backend en producción hasta completar pruebas de paridad y recuperación.

## Hallazgos del cliente actual

| Área | Implementación actual | Dependencia que debe retirarse |
|---|---|---|
| Arranque | `main.dart` carga configuración y llama `api.initialize()`; restaura JWT desde `flutter_secure_storage` y consulta `/auth/me`. | Inicialización del cliente HTTP y restauración del JWT desde almacenamiento seguro. |
| Configuración | `config.dart` usa `DENUPE_API_URL` (fallback a backend Render); las claves InsForge se conservan temporalmente en `.env.example` hasta retirar dependencias tras regresión. | `DENUPE_API_BASE_URL`; IA se mantiene separada hasta completar su proxy. |
| Sesión | `DenupeApi` usa JWT Bearer, refresh token rotativo, secure storage y `authStateTick`. | Estado de sesión propio, JWT Bearer y consulta `GET /api/v1/auth/me`. |
| Registro/verificación | `signUp`, envío y validación OTP mediante InsForge. | `DenupeApi` consume registro pendiente, OTP y verificación; el backend exige OTP solo a registros nuevos para preservar acceso de cuentas migradas. |
| Recuperación | Inserta en `solicitudes_recuperacion`, envía código, intercambia token y cambia contraseña con InsForge. | `DenupeApi` consume solicitud/reenvío OTP, intercambio y cambio de contraseña; backend revoca refresh sessions tras el cambio. |
| Perfil | Lee `perfiles` y actualiza mediante RPC `actualizar_perfil`. | `GET/PATCH /api/v1/auth/me`; adaptado el objeto anidado `profile`. |
| Categorías/autoridades | Consultas directas a tablas `categorias` y `autoridades`. | `GET /api/v1/catalogos/categorias` y `/autoridades`; campos compatibles en gran parte. |
| Denuncias | CRUD mediante consultas directas a `denuncias`. | Endpoints REST `/api/v1/denuncias`; cliente y campos de asignación adaptados. |
| Historial | Consulta directa a `historial_estados`. | `GET /api/v1/denuncias/{id}/historial`. |
| Evidencias | Sube/borra objetos de `complaint-media` y escribe filas en `adjuntos_denuncia`. | Flujo R2 upload-url → PUT → confirm; URLs de descarga por adjunto y DELETE propietario implementados. |
| Notificaciones | Consulta y actualiza `notificaciones` directamente. | `GET /api/v1/notificaciones` y `PATCH /api/v1/notificaciones/{id}/leida`. |
| Tiempo real | Socket.IO conectado a InsForge con `realtime:subscribe`. | Reemplazado por polling autenticado cada 20 segundos mediante el mismo cliente HTTP, con refresh automático. |
| IA | Servicios Flutter consultan directamente la URL del backend IA. | Mantener el backend IA intacto; migrar a proxy del backend principal cuando estén expuestos y validados todos los contratos IA. |

## Incompatibilidades de contrato encontradas

1. **Registro:** Flutter espera `requireEmailVerification` y flujo OTP. El backend `POST /auth/register` devuelve `user`, `access_token` y `token_type`, sin verificación de correo.
2. **Recuperación:** el backend no publica endpoints de solicitud, validación de código ni cambio de contraseña.
3. **Perfil:** `GET /auth/me` devuelve datos de usuario y un objeto `profile`; el cliente debe dejar de buscar una fila de `perfiles`.
4. **Creación de denuncia:** el cliente actual usa `autoridad_id`, `entidad_publica_id`, `entidad_publica_nombre` y `ruta_territorial_code`. El backend acepta y valida UBIGEO, autoridad, entidad pública y ruta territorial; deriva identidad del denunciante desde el perfil.
5. **Respuesta de denuncia:** el backend serializa `entity_id`, `entity_name` y `district_ubigeo`; el modelo Flutter espera `entidad_publica_id` y `entidad_publica_nombre`. Debe normalizarse un único formato.
6. **Adjuntos:** `GET /denuncias/{id}/adjuntos` devuelve `storage_key`, `url`, `media_type`, `mime_type` y fecha, pero el modelo Flutter exige `user_id`, ahora devuelto. El cliente solicita URL firmada de descarga por ID.
7. **Eliminación de adjuntos:** el cliente actual borra objeto y fila directamente; el backend ofrece DELETE autenticado para borrar objeto R2 y metadato. No se debe simular ni borrar solo la fila.
8. **Notificaciones:** la respuesta REST incluye `user_id`.
9. **Personal funcionario:** revisar filtros por `autoridad_id`; la API filtra funcionarios por autoridad del perfil y limita detalle/historial/adjuntos/actualización de estado al mismo ámbito.
10. **Tiempo real:** la conexión actual está acoplada a InsForge y no debe mantenerse apuntando a su URL después del cambio de autenticación.

## Orden de migración acordado

| Etapa | Trabajo | Condición para avanzar |
|---|---|---|
| 0 | Congelar contratos y cerrar brechas del backend (ver documento complementario en el repositorio backend). | Contratos de auth, perfil, denuncia, adjuntos, notificaciones y staff aprobados. |
| 1 | Crear cliente HTTP, manejo uniforme de errores, JWT y almacenamiento seguro. | Login, restauración de sesión, expiración y logout probados. |
| 2 | Migrar registro, verificación y recuperación. | Backend dispone de OTP/correo y pruebas de seguridad. |
| 3 | Migrar perfil y catálogos. | Modelos y formularios conservan los datos actuales. |
| 4 | Migrar denuncias, historial y panel de funcionarios. | Crear/listar/detallar/editar/actualizar estado y permisos probados. |
| 5 | Migrar evidencias a R2. | PUT firmado, confirmación HEAD, descarga y manejo de expiración probados en dispositivo. |
| 6 | Migrar notificaciones y decidir reemplazo realtime. | Lectura, marcado y actualización probados; sin dependencia de socket InsForge. |
| 7 | Migrar IA a través del proxy del backend principal. | Todos los endpoints de categoría/entidad/territorio necesarios están expuestos y validados. |
| 8 | Retirar dependencias InsForge del cliente. | Búsqueda estática sin referencias funcionales y regresión integral aprobada. |

## Archivos Flutter prioritarios

- `lib/main.dart`, `lib/config.dart`, `lib/app.dart`
- `lib/services/app_scope.dart`, `lib/services/denupe_api.dart`, `lib/services/complaint_realtime.dart`
- `lib/models.dart`
- `lib/screens/login_screen.dart`, `register_screen.dart`, `new_complaint_screen.dart`, `complaint_detail_screen.dart`, `mis_denuncias_screen.dart`, `profile_screen.dart`, `notifications_screen.dart`, `panel_municipal_screen.dart`

## Validación pendiente

Esta auditoría se basa en el código fuente y los contratos publicados en los repositorios. No se ha ejecutado Flutter, no se ha iniciado sesión con una cuenta real y no se ha realizado ninguna escritura contra datos productivos. Las pruebas en dispositivo se harán después de implementar cada etapa.


## Implementación realizada en esta rama (2026-11-27)

- Cliente HTTP único en `lib/services/denupe_api.dart`: manejo de errores, Bearer JWT, refresh token rotativo, secure storage, restauración de sesión y logout.
- `main.dart`, `app.dart` y `app_scope.dart` conectados al estado de sesión propio; pantallas de login, registro, verificación, recuperación y perfil adaptadas a excepciones del backend.
- Catálogos, perfil, denuncias, historial, panel municipal y notificaciones consumen REST.
- Evidencias usan presigned PUT a R2, confirmación, URL firmada GET y eliminación.
- Realtime sustituido por polling autenticado que comparte el cliente HTTP y renueva JWT cuando es necesario.
- Admin se incluye en el panel de gestión.
- InsForge SDK permanece declarado en dependencias/configuración como medida temporal; la inicialización funcional ya fue retirada de `main.dart`, pero no se borrará la dependencia hasta que el análisis, pruebas y regresión completa queden aprobados.

### Resultado de CI observado

La primera ejecución de Flutter CI detectó errores de tipos y un import no usado. Los errores de tipos se corrigieron; el análisis posterior pasó, pero la ejecución se canceló por concurrencia de commits y la siguiente ejecución detectó un import no usado, ya eliminado. Falta que una ejecución final complete tanto `flutter analyze` como `flutter test`.

### Pendientes de validación

1. CI verde final en Flutter.
2. SMTP real en Render y prueba de registro/verificación/recuperación.
3. E2E del cliente Flutter en dispositivo: login, perfil, catálogos, crear denuncia, R2 foto/vídeo, descarga, eliminación, notificaciones y permisos de dos autoridades.
4. Proxies de IA: categoría y operaciones de entidad/territorio aún deben inventariarse y migrarse sin modificar el repositorio IA.
5. Retirar InsForge SDK, claves y variables solo después de aprobar regresión integral y comprobar que el servicio IA conserva su dependencia independiente.
