# Plantillas de correo de autenticación — DenuPe

Los archivos HTML de este directorio son referencias visuales de los correos de verificación y recuperación de contraseña. **No están conectados directamente a la aplicación Flutter ni se instalan en un proveedor BaaS.**

## Plantillas incluidas

| Archivo | Uso previsto | Asunto sugerido |
|---|---|---|
| `verification-email.html` | Verificación de cuenta nueva mediante código OTP | `DenuPe | Confirma tu correo electrónico` |
| `password-reset-code.html` | Recuperación de contraseña mediante código OTP | `DenuPe | Código para restablecer tu contraseña` |

## Envío actual

El backend FastAPI principal gestiona el envío de correos mediante SMTP. Flutter solicita las operaciones a los endpoints autenticados o públicos correspondientes:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/email/resend`
- `POST /api/v1/auth/email/verify`
- `POST /api/v1/auth/password-reset/request`
- `POST /api/v1/auth/password-reset/resend`
- `POST /api/v1/auth/password-reset/exchange`
- `POST /api/v1/auth/password-reset/confirm`

La configuración SMTP se mantiene exclusivamente en las variables de entorno del servicio backend. No debe copiarse ninguna credencial SMTP al proyecto Flutter.

## Personalización futura

Si se desea utilizar el diseño HTML de estos archivos en los correos reales, debe adaptarse al motor de plantillas del backend y probarse allí. Los nombres de variables, el formato del OTP y los tiempos de expiración deben coincidir con la implementación vigente del backend; no se deben asumir variables de plantilla de un proveedor anterior.

No se debe modificar ni eliminar la configuración histórica de InsForge desde este directorio: el cliente Flutter ya no depende de ese servicio.
