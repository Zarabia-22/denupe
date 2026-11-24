# Plantillas de correo de autenticación — DenuPe

InsForge renderiza las plantillas con `{{ token }}` para los códigos de 6 dígitos, `{{ link }}` para enlaces y `{{ name }}` / `{{ email }}` con los datos del destinatario. `{{ code }}` no es una variable válida: si se usa, el correo muestra el texto literal.

## Plantillas incluidas

| Archivo | Plantilla de InsForge | Cuándo se envía | Asunto sugerido |
|---|---|---|---|
| `verification-email.html` | `email-verification-code` | Verificación de cuenta nueva | `DenuPe | Confirma tu correo electrónico` |
| `password-reset-code.html` | `reset-password-code` | Recuperación de contraseña | `DenuPe | Código para restablecer tu contraseña` |

## Instalación en InsForge

1. Abre `Authentication → Email` en el panel de InsForge.
2. Si usas SMTP personalizado, habilítalo y guarda la configuración antes de editar las plantillas.
3. Selecciona la plantilla indicada en la tabla anterior.
4. Copia el contenido HTML del archivo correspondiente.
5. Usa `{{ token }}` como variable del código. No la renombres.
6. Guarda y envía un correo de prueba para verificar el código real en Gmail y Outlook.

## Notas

- El backend usa actualmente las plantillas predeterminadas en inglés; estos archivos son la versión personalizada de DenuPe.
- La verificación y el reseteo están configurados en modo `code`, por eso no se usa `{{ link }}`.
- InsForge aplica un intervalo mínimo de 60 segundos por destinatario; los reenvíos dentro de ese plazo devuelven HTTP 429.
- Se usa HTML con tablas y estilos inline para mejorar compatibilidad con clientes de correo.
- No se fija un tiempo de expiración concreto porque debe coincidir con el configurado en InsForge.
