# Auditoría de compatibilidad: Flutter → Backend DenuPe en Render

**Rama:** `feature/migracion-final-backend-r2`  
**Base:** `develop`  
**Estado:** auditoría inicial; no se han cambiado flujos funcionales ni se ha retirado InsForge.

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
| Arranque | `main.dart` ejecuta `Insforge.initialize` y restaura sesión del SDK. | Inicialización del cliente HTTP y restauración del JWT desde almacenamiento seguro. |
| Configuración | `config.dart` exige `INSFORGE_URL` y `INSFORGE_ANON_KEY`. | `DENUPE_API_BASE_URL`; IA se mantiene separada hasta completar su proxy. |
| Sesión | `DenupeApi` usa `auth.currentUser`, `currentSession` y `onAuthStateChange`. | Estado de sesión propio, JWT Bearer y consulta `GET /api/v1/auth/me`. |
| Registro/verificación | `signUp`, envío y validación OTP mediante InsForge. | El backend actual registra y entrega JWT, pero no implementa envío/verificación de correo. Bloqueante de paridad. |
| Recuperación | Inserta en `solicitudes_recuperacion`, envía código, intercambia token y cambia contraseña con InsForge. | No existe todavía un contrato equivalente completo en el backend. Bloqueante de paridad. |
| Perfil | Lee `perfiles` y actualiza mediante RPC `actualizar_perfil`. | `GET/PATCH /api/v1/auth/me`; adaptar el objeto anidado `profile`. |
| Categorías/autoridades | Consultas directas a tablas `categorias` y `autoridades`. | `GET /api/v1/catalogos/categorias` y `/autoridades`; campos compatibles en gran parte. |
| Denuncias | CRUD mediante consultas directas a `denuncias`. | Endpoints REST de `/api/v1/denuncias`; revisar payload, filtros y paginación. |
| Historial | Consulta directa a `historial_estados`. | `GET /api/v1/denuncias/{id}/historial`. |
| Evidencias | Sube/borra objetos de `complaint-media` y escribe filas en `adjuntos_denuncia`. | Flujo R2 upload-url → PUT → confirm; descarga mediante download-url. |
| Notificaciones | Consulta y actualiza `notificaciones` directamente. | `GET /api/v1/notificaciones` y `PATCH /api/v1/notificaciones/{id}/leida`. |
| Tiempo real | Socket.IO conectado a InsForge con `realtime:subscribe`. | El backend actual no expone un protocolo realtime equivalente; requiere decisión (polling o implementar realtime). |
| IA | Servicios Flutter consultan directamente la URL del backend IA. | Mantener el backend IA intacto; migrar a proxy del backend principal cuando estén expuestos y validados todos los contratos IA. |

## Incompatibilidades de contrato encontradas

1. **Registro:** Flutter espera `requireEmailVerification` y flujo OTP. El backend `POST /auth/register` devuelve `user`, `access_token` y `token_type`, sin verificación de correo.
2. **Recuperación:** el backend no publica endpoints de solicitud, validación de código ni cambio de contraseña.
3. **Perfil:** `GET /auth/me` devuelve datos de usuario y un objeto `profile`; el cliente debe dejar de buscar una fila de `perfiles`.
4. **Creación de denuncia:** el cliente actual usa `autoridad_id`, `entidad_publica_id`, `entidad_publica_nombre` y `ruta_territorial_code`. El backend acepta `district_ubigeo`, pero no todos los campos de asignación territorial; debe acordarse el contrato antes de cambiar el formulario.
5. **Respuesta de denuncia:** el backend serializa `entity_id`, `entity_name` y `district_ubigeo`; el modelo Flutter espera `entidad_publica_id` y `entidad_publica_nombre`. Debe normalizarse un único formato.
6. **Adjuntos:** `GET /denuncias/{id}/adjuntos` devuelve `storage_key`, `url`, `media_type`, `mime_type` y fecha, pero el modelo Flutter actual exige `user_id`. Además, el nuevo flujo R2 guarda `url = null`; la interfaz debe solicitar una URL de descarga temporal.
7. **Eliminación de adjuntos:** el cliente actual borra objeto y fila directamente; el backend no ofrece todavía un endpoint de eliminación R2. No se debe simular ni borrar solo la fila.
8. **Notificaciones:** la respuesta REST no incluye `user_id`, aunque el modelo Flutter actual lo exige.
9. **Personal funcionario:** revisar filtros por `autoridad_id`; la lista REST actual aplica ámbito general de staff y no reproduce exactamente el filtro del cliente.
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
