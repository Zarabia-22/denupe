# Auditoría de compatibilidad: Flutter → Backend DenuPe en Render

> **Documento histórico.** Describe la migración ejecutada en la rama `feature/migracion-final-backend-r2`; ya no representa la configuración vigente del proyecto.

- **Rama original:** `feature/migracion-final-backend-r2`
- **Base:** `develop`
- **Estado final:** migración completada. El cliente Flutter consume el backend FastAPI en Render, las evidencias en Cloudflare R2 mediante URLs prefirmadas y los servicios de IA mediante el proxy autenticado del backend. InsForge fue retirado del cliente y el tag `v1.6.0` fue publicado.

## Objetivo y reglas originales

La aplicación Flutter debe consumir el backend principal `https://denupe-backend.onrender.com` para autenticación, perfiles, catálogos, denuncias, historial, evidencias y notificaciones. Cloudflare R2 se consume exclusivamente mediante URLs prefirmadas emitidas por el backend.

- Mantener InsForge activo e intacto durante toda la migración y el periodo de validación (histórico; ya retirado del cliente).
- No modificar `denupe-ia-backend`.
- No publicar secretos ni incluir tokens/URLs prefirmadas en logs.
- No cambiar la interfaz ni la lógica de negocio fuera del alcance de cada etapa.
- No activar el cambio de backend en producción hasta completar pruebas de paridad y recuperación.

## Hallazgos del cliente durante la migración

| Área | Implementación previa | Dependencia que debe retirarse |
|---|---|---|
| Arranque | `main.dart` carga configuración y llama `api.initialize()`; restaura JWT desde `flutter_secure_storage` y consulta `/auth/me`. | Inicialización del cliente HTTP y restauración del JWT desde almacenamiento seguro. |
| Configuración | `config.dart` usa `DENUPE_API_URL` (fallback a backend Render); las claves InsForge se conservaron temporalmente y ya no deben aparecer en `.env.example`. | `DENUPE_API_BASE_URL`; IA se mantiene separada hasta completar su proxy. |
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
| IA | Servicios Flutter consumen el proxy autenticado del backend principal para categoría, entidad y territorio. | Backend IA permanece intacto; Flutter ya consume proxies autenticados del backend principal para sugerir categoría, listar entidades, catálogo territorial y sugerir entidad. |

## Incompatibilidades de contrato encontradas durante la migración

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

## Validación documental inicial

Esta sección refleja el punto de partida histórico: la auditoría se basó en el código fuente y los contratos publicados, sin ejecutar Flutter, iniciar sesión con una cuenta real ni escribir en datos productivos.


## Implementación realizada durante la migración (2026-11-27)

- Cliente HTTP único en `lib/services/denupe_api.dart`: manejo de errores, Bearer JWT, refresh token rotativo, secure storage, restauración de sesión y logout.
- `main.dart`, `app.dart` y `app_scope.dart` conectados al estado de sesión propio; pantallas de login, registro, verificación, recuperación y perfil adaptadas a excepciones del backend.
- Catálogos, perfil, denuncias, historial, panel municipal y notificaciones consumen REST.
- Evidencias usan presigned PUT a R2, confirmación, URL firmada GET y eliminación.
- Realtime sustituido por polling autenticado que comparte el cliente HTTP y renueva JWT cuando es necesario.
- Admin se incluye en el panel de gestión.
- InsForge fue retirado del cliente: no se conservan SDK, variables ni referencias funcionales.

### Resultado de CI observado

La ejecución histórica aprobada usó `flutter analyze --no-fatal-infos` y `flutter test` en [run 45943132594](https://github.com/Zarabia-22/denupe/actions/runs/45943132594). La configuración vigente ejecuta `flutter analyze`, `flutter test --coverage` y `flutter build web --release`.

## Estado final

- Backend principal FastAPI en Render para autenticación, perfiles, catálogos, denuncias, historial, adjuntos y notificaciones.
- Cloudflare R2 privado con URLs prefirmadas; el cliente persiste `storage_key`.
- Servicios de IA consumidos mediante el proxy autenticado del backend principal.
- InsForge retirado del cliente; `insforge.toml` y `functions/` eliminados del repositorio.
- Tag `v1.6.0` publicado.

## Sigue abierto

1. Verificación E2E en dispositivo: login, perfil, catálogos, crear denuncia, R2 foto/vídeo, descarga, eliminación, notificaciones y permisos de dos autoridades.
2. Pruebas E2E de los proxies de IA contra el backend desplegado.
3. Cobertura nacional efectiva de selección territorial y validación nominal de competencias.
4. Capturas actualizadas y demo web estable, si se habilita un despliegue público.
