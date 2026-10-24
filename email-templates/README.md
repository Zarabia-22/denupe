# Plantilla de verificación de correo — DenuPe

Diseño HTML responsive basado en la opción 3 aprobada: encabezado ilustrado de ciudad, código resaltado en amarillo, recordatorio de seguridad y tres pasos de activación.

## Instalación en InsForge

1. Abre la configuración de plantillas de correo de autenticación de tu proyecto InsForge.
2. Selecciona la plantilla de **verificación por código**.
3. Copia el contenido de `verification-email.html` en el editor HTML.
4. **Importante:** sustituye `{{verification_code}}` por la variable exacta de OTP que admita tu versión de InsForge. Esta cadena es un marcador local y no se ha verificado como sintaxis de InsForge.
5. Asunto sugerido: `DenuPe | Confirma tu correo electrónico`.
6. Envía un correo de prueba y comprueba el código real en Gmail y Outlook.

## Notas

- No modifica el flujo de autenticación de Flutter ni envía correos por sí mismo.
- Se usa HTML con tablas y estilos inline para mejorar compatibilidad con clientes de correo.
- Los iconos ilustrativos son emojis: su apariencia puede variar según el cliente de correo.
- No se fija un tiempo de expiración concreto porque debe coincidir con el configurado en InsForge.
- No se añadieron enlaces a redes sociales ficticias.
