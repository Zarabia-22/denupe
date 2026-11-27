# Funciones de InsForge conservadas para rollback

`send-notification-sms.ts` se conserva como respaldo histórico del envío SMS anterior. No debe ser invocada ni programada para nuevas notificaciones después de activar el dispatcher del backend principal.

El flujo activo nuevo está en:

- Backend: `Zarabia-22/denupe-backend/app/sms_service.py`
- Endpoint interno: `POST /api/v1/internal/notifications/sms/dispatch`
- Programación: `Zarabia-22/denupe-backend/.github/workflows/dispatch-sms.yml`

El backend usa PostgreSQL de Render para reclamar notificaciones y Twilio por HTTPS para enviarlas. Las filas históricas no se envían: solo las notificaciones creadas después de la activación reciben `sms_queued_at`.

Mantener este archivo hasta completar la regresión de Flutter y la verificación del nuevo envío. Antes de activar el workflow nuevo, deshabilitar cualquier programación externa que todavía invoque la función antigua para evitar SMS duplicados.
