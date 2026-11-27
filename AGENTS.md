# Guía del proyecto DenuPe

## Arquitectura vigente

- Aplicación cliente: Flutter y Dart.
- Backend principal: FastAPI en `https://denupe-backend.onrender.com`.
- Persistencia: PostgreSQL administrado por Render.
- Evidencias: Cloudflare R2 privado; el cliente solicita URLs prefirmadas al backend.
- IA: se consume mediante endpoints proxy autenticados del backend principal.
- Autenticación: JWT de acceso y refresh rotativo; los tokens se guardan con `flutter_secure_storage`.
- Seguimiento de estados: sondeo autenticado mediante el cliente REST compartido.

## Reglas de implementación

- Todas las operaciones de autenticación y datos de la aplicación deben pasar por `lib/services/denupe_api.dart`.
- No conectar Flutter directamente a PostgreSQL, R2 ni al microservicio de IA.
- No introducir SDK, URL, claves ni credenciales de InsForge en el cliente.
- No almacenar URLs prefirmadas de R2 como referencias permanentes; persistir y utilizar `storage_key`.
- Mantener los mensajes de error presentados al usuario libres de detalles internos y secretos.
- No registrar contraseñas, OTP, tokens, direcciones de correo ni credenciales.
- Antes de integrar cambios, ejecutar `flutter pub get`, `flutter analyze` y `flutter test`.
- Mantener los cambios visuales separados de cambios de lógica cuando el trabajo solicitado sea exclusivamente de diseño.
