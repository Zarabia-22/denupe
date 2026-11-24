# Migración de DenuPe desde InsForge hacia Render

## Estado

- Rama de trabajo: `migracion` (creada desde `develop`).
- Alcance: preparar la sustitución de InsForge sin interrumpir el entorno actual.
- Estado actual: auditoría inicial del código; no se han cambiado endpoints, credenciales ni servicios de producción.
- Regla de seguridad: InsForge permanece como origen de datos y servicio activo hasta completar exportación, importación, pruebas y aprobación del cambio.

## 1. Hallazgos de la auditoría inicial

### Aplicación Flutter — repositorio `Zarabia-22/denupe`

- `.env.example` define `INSFORGE_URL` y `INSFORGE_ANON_KEY`; también define `DENUPE_IA_URL`.
- `lib/config.dart` exige URL y clave pública de InsForge.
- `lib/services/app_scope.dart` instancia `DenupeApi(Insforge.instance)`, usa la sesión de InsForge para obtener el access token y configura el servicio realtime con la URL de InsForge.
- `lib/services/complaint_realtime.dart` implementa el protocolo Socket.IO de InsForge: autenticación por token, suscripción a `complaint:<id>` y recepción de `status_changed`.
- El README declara que Flutter usa el SDK de InsForge para autenticación, PostgreSQL, RPC, datos y almacenamiento.
- El repositorio contiene migraciones SQL de esquema, ciclo de vida de denuncias, evidencias, roles, perfiles, catálogo territorial nacional, ruta territorial, recuperación de correo y notificaciones SMS.

### Backend FastAPI — repositorio `Zarabia-22/denupe-ia-backend`

- El servicio de IA ya está desplegado en Render mediante Docker y conserva sus rutas públicas actuales.
- `app/insforge_catalog.py` consume RPC de InsForge mediante `INSFORGE_URL` y una clave administrativa `INSFORGE_API_KEY`.
- `app/main.py` depende del catálogo de InsForge para resolver la matriz territorial, verificar ocho categorías y consultar el resolutor por UBIGEO.
- Si el catálogo no está disponible, la API responde con error 503; por tanto, migrar solamente la app móvil no es suficiente.
- `render.yaml` declara actualmente el backend como servicio web Docker en plan Free.

### DenuPe Analytics

- El repositorio `Zarabia-22/denupe-analytics` despliega Metabase en Render.
- Su README documenta InsForge/PostgreSQL como origen externo de solo lectura.
- El despliegue Free de Metabase usa almacenamiento local efímero y no debe considerarse persistente para dashboards ni configuración.
- Tras la migración, Metabase deberá conectarse a la nueva base Render Postgres con un usuario exclusivo de solo lectura.

## 2. Componentes que deben reemplazarse

| Responsabilidad actual de InsForge | Destino propuesto |
|---|---|
| PostgreSQL y tablas de negocio | Render Managed PostgreSQL |
| Autenticación, sesiones y usuarios | API de identidad propia en FastAPI, con contraseñas hash, tokens, verificación y recuperación por correo |
| SDK/API de datos y RPC | Endpoints REST de FastAPI y consultas parametrizadas a PostgreSQL |
| Políticas RLS | Autorización en servidor por usuario, rol, entidad y propiedad del recurso; nunca confiar en filtros del cliente |
| Storage de fotografías y videos | Evaluar disco persistente de Render para una primera versión de una sola instancia; para escalado, almacenamiento de objetos externo |
| Realtime Socket.IO | Servidor Socket.IO propio en Render, validando token y autorización de cada canal; alternativa temporal: actualización periódica |
| SMTP | Proveedor SMTP externo configurado como secreto en Render |
| RPC del catálogo territorial | Funciones SQL equivalentes en Render Postgres o lógica de dominio en FastAPI |
| Fuente de Metabase | Render Postgres mediante usuario de solo lectura |

**Importante:** Render no reemplaza automáticamente los productos administrados de InsForge para autenticación, almacenamiento de objetos, realtime ni envío de correo. Esas responsabilidades requieren implementación y/o servicios complementarios.

## 3. Arquitectura objetivo propuesta

```text
Flutter DenuPe
   |
   | HTTPS / REST + Socket.IO autenticado
   v
FastAPI en Render
   |-- Autenticación y autorización
   |-- Usuarios, perfiles y roles
   |-- Denuncias, estados e historial
   |-- Evidencias (metadatos y carga)
   |-- Catálogo territorial y RPC sustituidas
   |-- Notificaciones y eventos realtime
   |-- Integración con servicio de IA
   |
   +---- Render Managed PostgreSQL
   |
   +---- Almacenamiento de archivos (decisión pendiente)
   |
   +---- SMTP externo (verificación y recuperación)

Metabase en Render
   |
   +---- Render Postgres (usuario de solo lectura)
```

## 4. Plan de migración por etapas

1. **Inventario y línea base:** completar mapa de tablas, relaciones, RPC, políticas RLS, buckets, autenticación, triggers, realtime y variables. Identificar datos y volúmenes sin copiar secretos.
2. **Diseño de destino:** definir esquema PostgreSQL, estrategia de identidad, autorización, almacenamiento de archivos, SMTP y eventos.
3. **Preparación de Render:** provisionar PostgreSQL en región acordada, definir plan/costo, backups, red privada y secretos. No conectar producción todavía.
4. **Migraciones SQL:** adaptar las migraciones de InsForge a PostgreSQL estándar/Render; retirar dependencias de esquemas y funciones propias del proveedor cuando corresponda.
5. **API de reemplazo:** implementar endpoints compatibles para Flutter, auth, permisos, carga/descarga de archivos, realtime y catálogo territorial.
6. **Migración de datos:** exportación consistente de PostgreSQL y usuarios; transformación de identidades; copia y verificación de archivos; conteos y checksums.
7. **Pruebas de aceptación:** registro, login, verificación, recuperación, perfiles, roles, CRUD de denuncias, adjuntos, seguimiento, notificaciones, GPS, catálogo territorial, IA y Metabase.
8. **Corte controlado:** ventana de mantenimiento, exportación final/delta, cambio de configuración, monitoreo y plan de reversión.
9. **Retiro de InsForge:** únicamente después de validar integridad, estabilidad y backups del destino.

## 5. Información y accesos necesarios antes de provisionar

No incluir contraseñas, claves API ni tokens en GitHub o en mensajes. Los valores secretos deben introducirse directamente en los paneles de los proveedores.

- Acceso de lectura/exportación al PostgreSQL actual de InsForge o un dump `.dump`/`.sql` seguro.
- Inventario/exportación de usuarios de Auth y confirmación de si el proveedor permite exportar hashes de contraseña. Si no, habrá que diseñar restablecimiento de contraseña.
- Inventario de buckets, archivos y tamaños; acceso de exportación de objetos.
- Definición de región Render y presupuesto aceptable. La persistencia y disponibilidad de producción pueden requerir recursos de pago.
- Confirmación de si el alcance incluye migrar autenticación y archivos o si se permite mantener temporalmente un servicio externo.

## 6. Riesgos y controles

- **Identidades:** no asumir que exportar la tabla de perfiles exporta credenciales de Auth. Preservar UUID y relaciones cuando sea posible.
- **Seguridad:** no exponer Render Postgres directamente a Flutter; el cliente debe hablar con la API. Aplicar autorización por cada recurso y rol.
- **Archivos:** no guardar evidencias únicamente en el filesystem efímero de un Web Service.
- **Datos personales:** minimizar acceso, cifrar conexiones, limitar logs y usar cuentas de servicio con privilegios mínimos.
- **Compatibilidad:** no cambiar contratos de endpoints de IA ni apagar RPC hasta tener equivalentes probados.
- **Analítica:** Metabase debe tener permisos de solo lectura y acceso únicamente a vistas/campos necesarios.
- **Reversión:** mantener InsForge intacto y respaldado durante todo el periodo de validación.

## 7. Próximo paso

Obtener el inventario completo del proyecto InsForge: esquema y datos, Auth, Storage, funciones RPC, triggers, políticas RLS y configuración realtime. Con esa evidencia se elaborará una matriz objeto-por-objeto y el plan SQL específico para Render.

**No ejecutar todavía:** creación de recursos de pago, restauración de datos, cambios de DNS/URLs, actualización de variables productivas ni eliminación de recursos InsForge.
