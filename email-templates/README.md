# Plantillas de correo de autenticación — DenuPe

Los diseños HTML de este directorio son la fuente visual de los correos de verificación y recuperación de contraseña. Las copias activas que utiliza el backend se encuentran en:

- `Zarabia-22/denupe-backend/app/templates/verification-email.html`
- `Zarabia-22/denupe-backend/app/templates/password-reset-code.html`

Cuando se modifique un diseño, deben mantenerse sincronizadas ambas copias y ejecutar las pruebas de `tests/test_email_service.py` del backend.

## Plantillas

| Archivo | Uso | Asunto |
|---|---|---|
| `verification-email.html` | Verificación de cuenta nueva mediante OTP | `DenuPe | Confirma tu correo electrónico` |
| `password-reset-code.html` | Recuperación de contraseña mediante OTP | `DenuPe | Código para restablecer tu contraseña` |

## Envío

Flutter no envía correos ni accede directamente a un proveedor de email. La aplicación solicita las operaciones al backend FastAPI:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/email/resend`
- `POST /api/v1/auth/email/verify`
- `POST /api/v1/auth/password-reset/request`
- `POST /api/v1/auth/password-reset/resend`
- `POST /api/v1/auth/password-reset/exchange`
- `POST /api/v1/auth/password-reset/confirm`

El backend renderiza la plantilla HTML y genera también una versión de texto plano. En Render Free, el envío se realiza mediante la API HTTPS de Resend; SMTP queda disponible como alternativa para entornos que permitan conexiones SMTP salientes.

## Variables dinámicas

- `{{ token }}`: código OTP, escapado como HTML antes de insertarse.
- `{{ expiry_minutes }}`: tiempo de vigencia configurado en el backend.

No deben agregarse secretos, direcciones de destinatarios ni credenciales del proveedor a estas plantillas. La API key de Resend y la dirección remitente se configuran exclusivamente en el entorno del backend.
