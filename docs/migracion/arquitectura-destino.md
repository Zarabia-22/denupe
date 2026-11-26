# Arquitectura objetivo: backend principal de DenuPe en Render

## Decisión aprobada

La aplicación Flutter se comunicará únicamente con el nuevo backend principal de DenuPe. Este backend será el intermediario con el servicio de IA existente.

- Backend principal nuevo: repositorio independiente `Zarabia-22/denupe-backend` (pendiente de creación).
- Backend IA existente: `Zarabia-22/denupe-ia-backend`; debe permanecer intacto durante esta migración.
- Flutter: se migrará desde el SDK directo de InsForge hacia la API REST del backend principal, en una etapa posterior.
- Base de datos principal destino: Render PostgreSQL.
- InsForge: permanecerá activo durante la transición y no se eliminará mientras existan dependencias pendientes.

## Restricción crítica: no afectar el backend IA

La auditoría del código actual confirma que el backend IA tiene una dependencia operativa de InsForge:
- `app/insforge_catalog.py` usa `INSFORGE_URL` y `INSFORGE_API_KEY`.
- Consulta las RPC `consultar_matriz_distrital_por_ubigeo` y `consultar_entidades_por_ubigeo`.
- `app/main.py` usa esas consultas en los endpoints territoriales y de sugerencia de entidad.

Por tanto, durante esta migración:
1. No se modifica el repositorio, código, configuración, variables ni despliegue del backend IA.
2. No se revocan ni rotan sus credenciales de InsForge.
3. No se eliminan ni alteran las RPC ni tablas de catálogo que consume.
4. InsForge debe seguir disponible para el backend IA mientras conserve esa dependencia.
5. El backend principal nuevo llamará a los endpoints actuales de IA por HTTP y adaptará las respuestas para Flutter.
6. La eventual retirada de InsForge queda fuera de esta fase y requerirá un proyecto separado para migrar el catálogo IA, con autorización expresa.

## Flujo objetivo

```text
Flutter
  |
  | HTTPS (API principal)
  v
DenuPe Backend (FastAPI en Render)
  |                         |
  |                         | HTTPS (proxy de IA)
  v                         v
Render PostgreSQL      denupe-ia-backend (sin cambios)
  |                         |
  |                         v
  |                    InsForge RPC (dependencia actual conservada)
  |
  +-- usuarios/perfiles, denuncias, estados, historial,
      categorías, autoridades, notificaciones y referencias de evidencias

Metabase (solo lectura) ---> Render PostgreSQL
```

El almacenamiento de evidencias se decidirá después de inventariar Storage, volumen, permisos y estrategia de copias. No se debe usar el disco efímero de un Web Service para archivos permanentes.

## Hallazgos de integración Flutter

En la rama `migracion`:
- `lib/config.dart` obtiene `INSFORGE_URL` y `INSFORGE_ANON_KEY`.
- `lib/services/app_scope.dart` instancia `DenupeApi(Insforge.instance)` y `ComplaintRealtime(Config.baseUrl)`.
- `lib/services/denupe_api.dart` concentra Auth, consultas CRUD, RPC, Storage y notificaciones.
- `lib/services/complaint_realtime.dart` implementa el protocolo Socket.IO de InsForge.
- `lib/services/ai_category_service.dart` y `lib/services/ai_entity_service.dart` llaman actualmente directamente a `DENUPE_IA_URL`.

La migración de Flutter deberá reemplazar estas llamadas por un cliente de la API principal. Los endpoints de IA no deben cambiar en el servicio existente; el nuevo backend actuará como proxy compatible. La implementación se hará solo después de tener el contrato API y pruebas.

## Fases y límites

1. Auditar PostgreSQL, RLS, RPC, triggers, Auth, Storage y Realtime de InsForge.
2. Crear el repositorio independiente del backend principal.
3. Implementar API principal y pruebas sin tocar Flutter ni InsForge.
4. Crear y preparar Render PostgreSQL solo después de conocer región, volumen y presupuesto.
5. Migrar datos y archivos en entorno de prueba.
6. Validar compatibilidad funcional y seguridad.
7. Adaptar Flutter en la rama `migracion`.
8. Validar Analytics con usuario PostgreSQL de solo lectura.
9. Realizar corte controlado manteniendo InsForge y el backend IA activos.
10. No retirar InsForge mientras el backend IA dependa de sus RPC.

## Estado actual

- Rama Flutter: `migracion`.
- Diagnóstico inicial: `docs/migracion/diagnostico-inicial.md`.
- Esta decisión: arquitectura A aprobada por el usuario.
- Repositorio `Zarabia-22/denupe-backend`: no encontrado; debe crearse antes de subir el backend independiente.
- No se ha creado infraestructura nueva en Render ni se han cambiado recursos existentes.
