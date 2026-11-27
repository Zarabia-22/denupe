# DenuPe

<p align="center">
  <img src="assets/denupe_logo.png" alt="Logotipo de DenuPe" width="150" />
</p>

<p align="center">
  <strong>Plataforma móvil de denuncias ciudadanas</strong><br />
  Reporta incidencias de tu comunidad, adjunta evidencias y sigue su atención desde un solo lugar.
</p>

<p align="center">
  <a href="https://github.com/Zarabia-22/denupe/releases"><img src="https://img.shields.io/badge/versi%C3%B3n-1.5.0%2B15-2457A7" alt="Versión 1.5.0+15" /></a>
  <img src="https://img.shields.io/badge/Flutter-Dart%20%5E3.13.4-02569B?logo=flutter&logoColor=white" alt="Flutter y Dart" />
  <img src="https://img.shields.io/badge/plataforma-Android%20%7C%20Web-0F766E" alt="Android y Web" />
  <a href="https://github.com/Zarabia-22/denupe/issues"><img src="https://img.shields.io/badge/soporte-GitHub%20Issues-orange" alt="Soporte en GitHub Issues" /></a>
</p>

DenuPe es una aplicación desarrollada con Flutter para facilitar el registro y seguimiento de denuncias ciudadanas. Permite describir un problema, adjuntar fotografías o videos, registrar su ubicación y seleccionar una entidad receptora; incorpora recomendaciones de inteligencia artificial como apoyo, sin quitarle al ciudadano la decisión final.

---

## Tabla de contenidos

- [Demo y apoyo visual](#demo-y-apoyo-visual)
- [Características principales](#características-principales)
- [Stack tecnológico](#stack-tecnológico)
- [Prerrequisitos](#prerrequisitos)
- [Instalación y configuración](#instalación-y-configuración)
- [Ejemplos de uso](#ejemplos-de-uso)
- [Roadmap y limitaciones conocidas](#roadmap-y-limitaciones-conocidas)
- [Contribución y licencia](#contribución-y-licencia)
- [Arquitectura y estructura](#arquitectura-y-estructura)

## Demo y apoyo visual

- **Descargar la aplicación:** [Versiones publicadas en GitHub Releases](https://github.com/Zarabia-22/denupe/releases).
- **Código fuente:** [Zarabia-22/denupe](https://github.com/Zarabia-22/denupe).
- **Backend de IA:** [Zarabia-22/denupe-ia-backend](https://github.com/Zarabia-22/denupe-ia-backend).

El repositorio no contiene actualmente capturas de pantallas ni un GIF de demostración de la interfaz. Se muestra el logotipo del proyecto al inicio; las capturas del flujo de registro, creación y seguimiento de denuncias quedan pendientes de incorporar. No se publica aquí una URL de demo web porque no se ha verificado un despliegue público estable.

## Características principales

### Ciudadanía
- Registro de cuenta, verificación de correo e inicio de sesión.
- Gestión del perfil del ciudadano.
- Registro de denuncias con categoría, título, descripción y ubicación.
- Adjuntar fotografías y videos como evidencia.
- Selección manual de la entidad receptora disponible para la denuncia.
- Sugerencia de categoría mediante IA a partir del título y la descripción.
- Recomendación opcional de entidad mediante IA; el ciudadano puede aceptarla, solicitar otra o ignorarla.
- Seguimiento del estado, historial, detalle y notificaciones de las denuncias.

### Funcionarios
- Consulta de denuncias recibidas por la entidad asociada a la cuenta.
- Visualización de los datos y evidencias de cada denuncia.
- Actualización del estado y registro de una nota opcional, según los permisos del rol.

### Asignación territorial responsable
- Uso de coordenadas GPS para apoyar la identificación del distrito y la jurisdicción.
- Consulta de reglas territoriales por UBIGEO y categoría.
- Abstención cuando no existe evidencia suficiente para identificar una institución concreta.
- La bandeja de revisión de competencia es un mecanismo interno de DenuPe; no representa a una entidad pública.

## Stack tecnológico

| Tecnología | Uso |
|---|---|
| Dart y Flutter | Aplicación móvil y ejecución web. |
| Python y FastAPI | Backend principal: autenticación, perfiles, denuncias, catálogos, permisos y notificaciones. |
| PostgreSQL en Render | Persistencia relacional del backend principal. |
| Cloudflare R2 | Almacenamiento privado de fotografías y videos mediante URLs prefirmadas. |
| JWT | Autenticación con tokens de acceso y refresh rotativo. |
| HTTP y JSON | Comunicación REST entre Flutter y el backend. |
| SMTP | Envío de códigos de verificación y recuperación desde el backend. |
| Backend de IA | Recomendaciones de categoría y entidad consumidas mediante proxy autenticado. |
| Geolocator | Obtención de coordenadas con permiso del usuario. |
| Image Picker | Selección de fotografías y videos. |
| flutter_dotenv | Configuración mediante variables de entorno. |
| flutter_secure_storage | Almacenamiento seguro de tokens en el dispositivo. |
| url_launcher | Apertura de enlaces externos. |

## Prerrequisitos

Para desarrollar y ejecutar el proyecto localmente:

- Git.
- Flutter SDK y Dart compatibles con la restricción declarada en `pubspec.yaml`: Dart `^3.13.4`.
- Android Studio y Android SDK, o un dispositivo Android para ejecutar la aplicación móvil.
- Google Chrome si se desea ejecutar la versión web.
- Acceso a Internet para consumir el backend principal desplegado en Render.
- Visual Studio Code con las extensiones Flutter y Dart (opcional).

Verifica tu instalación:

```bash
flutter doctor
flutter --version
dart --version
git --version
```

## Instalación y configuración

### 1. Clonar el repositorio

```bash
git clone https://github.com/Zarabia-22/denupe.git
cd denupe
```

### 2. Crear el archivo de entorno

El repositorio incluye una plantilla `.env.example`. Crea el archivo local `.env`:

**Windows PowerShell**

```powershell
Copy-Item .env.example .env
```

**macOS / Linux**

```bash
cp .env.example .env
```

### 3. Configurar las variables

Edita el archivo `.env`. La aplicación Flutter solo necesita la URL del backend principal:

| Variable | Descripción |
|---|---|
| `DENUPE_API_URL` | URL base del backend FastAPI principal, sin barra final. Por defecto se utiliza el servicio de producción en Render. |

Ejemplo:

```dotenv
DENUPE_API_URL=https://denupe-backend.onrender.com
```

El backend principal gestiona las llamadas a PostgreSQL, las operaciones de almacenamiento privado en R2 y el proxy autenticado hacia el servicio de IA. No configures URLs ni claves de InsForge en Flutter. Tampoco coloques credenciales SMTP, claves de R2 ni secretos JWT en el archivo `.env` de la aplicación.

Para desarrollo local, utiliza la dirección accesible desde el emulador o dispositivo que estés ejecutando; no sustituyas la URL de producción por una dirección local en una compilación publicada.

**Seguridad:** no subas el archivo `.env`, tokens ni credenciales. Los secretos de SMTP, JWT y Cloudflare R2 pertenecen exclusivamente a las variables de entorno del backend.

### 4. Instalar dependencias

```bash
flutter pub get
```

### 5. Ejecutar la aplicación

**Web**

```bash
flutter run -d chrome
```

**Android**

```bash
flutter devices
flutter run -d android
```

Si hay varios dispositivos conectados, utiliza el identificador mostrado por `flutter devices`:

```bash
flutter run -d <device_id>
```

## Ejemplos de uso

### Ejecutar y validar el proyecto

```bash
# Revisar problemas estáticos
flutter analyze

# Ejecutar las pruebas automatizadas
flutter test

# Ejecutar la aplicación en Chrome
flutter run -d chrome

# Generar APK de producción
flutter build apk --release
```

El APK se genera en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Comprobar el backend principal

La aplicación consume el backend FastAPI principal:

```bash
curl https://denupe-backend.onrender.com/health
curl https://denupe-backend.onrender.com/health/database
```

Las operaciones de la aplicación se realizan bajo el prefijo `/api/v1`:

| Método | Endpoint | Propósito |
|---|---|---|
| `POST` | `/auth/register` | Registrar una cuenta y solicitar verificación por correo. |
| `POST` | `/auth/email/verify` | Verificar el correo mediante OTP. |
| `POST` | `/auth/login` | Iniciar sesión y obtener JWT. |
| `POST` | `/auth/refresh` | Renovar la sesión mediante refresh token rotativo. |
| `GET/PATCH` | `/auth/me` | Consultar y actualizar el perfil propio. |
| `GET` | `/catalogos/categorias` | Consultar categorías de denuncia. |
| `GET` | `/catalogos/autoridades` | Consultar autoridades receptoras. |
| `GET` | `/denuncias` | Consultar denuncias permitidas para el usuario. |
| `POST` | `/denuncias` | Registrar una denuncia. |
| `POST` | `/denuncias/{id}/adjuntos/upload-url` | Solicitar autorización de carga a R2. |
| `POST` | `/denuncias/{id}/adjuntos/confirm` | Confirmar y registrar una evidencia. |
| `GET` | `/denuncias/{id}/adjuntos/{attachment_id}/download-url` | Obtener una URL temporal de descarga. |
| `GET` | `/notificaciones` | Consultar notificaciones del usuario. |
| `POST` | `/ia/sugerir-categoria` | Solicitar una categoría sugerida mediante el proxy autenticado de IA. |
| `GET` | `/ia/entidades/disponibles` | Consultar opciones territoriales y entidades disponibles. |
| `GET` | `/ia/territorio/catalogo-distrital` | Consultar el catálogo territorial. |
| `POST` | `/ia/sugerir-entidad` | Solicitar una recomendación de entidad o una abstención. |

Los endpoints de negocio requieren el JWT cuando corresponde. Flutter no accede directamente a PostgreSQL, Cloudflare R2 ni al microservicio de IA. Para evidencias, el backend autoriza la operación con URLs prefirmadas y mantiene privado el bucket.

### Flujo principal en la aplicación

1. Inicia sesión o crea una cuenta.
2. Registra una denuncia con su categoría, título y descripción.
3. Adjunta evidencia y registra la ubicación.
4. En la confirmación, revisa las entidades disponibles y selecciona manualmente una.
5. Si lo deseas, solicita una recomendación de IA y decide si la utilizas.
6. Envía la denuncia y consulta su estado posteriormente.

## Roadmap y limitaciones conocidas

Las siguientes tareas reflejan áreas de evolución y restricciones conocidas; no representan funcionalidades ya completadas.

- [ ] Ampliar y validar la cobertura operativa de selección de entidades fuera de Lima Metropolitana y Callao.
- [ ] Completar la verificación nominal de instituciones y competencias por categoría, distrito y jurisdicción sectorial.
- [ ] Alinear la selección territorial de la interfaz Flutter con la resolución por GPS del backend.
- [ ] Incorporar capturas actualizadas de las pantallas principales y un GIF del flujo de denuncia.
- [ ] Documentar y publicar una demo web estable, si se habilita un despliegue público.
- [ ] Definir y añadir un archivo de licencia al repositorio.
- [ ] Publicar métricas de pruebas y cobertura únicamente cuando exista un reporte automatizado verificable.

**Limitaciones conocidas**
- La matriz territorial contiene reglas de enrutamiento por UBIGEO y categoría; no acredita por sí sola que exista una institución concreta verificada para cada combinación.
- La interfaz Flutter de la versión documentada mantiene una restricción territorial relacionada con el distrito del perfil para Lima Metropolitana y Callao. La cobertura nacional de la matriz no equivale a selección manual nacional habilitada en la aplicación.
- La ubicación depende de los permisos concedidos, la precisión del dispositivo y la disponibilidad de señal.
- Las recomendaciones de IA son asistenciales. Si no hay evidencia suficiente, debe mantenerse la selección manual o la revisión interna de competencia.

## Contribución y licencia

### Cómo contribuir

1. Crea un *fork* del repositorio.
2. Crea una rama descriptiva desde `develop` (por ejemplo, `feat/nombre-funcionalidad` o `fix/nombre-correccion`).
3. Realiza cambios acotados y agrega o actualiza pruebas cuando corresponda.
4. Ejecuta antes de enviar el cambio:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```

5. Abre un *Pull Request* hacia `develop`, explica el problema que resuelve, resume los cambios y adjunta capturas cuando afecten a la interfaz.
6. Para reportar errores, utiliza [GitHub Issues](https://github.com/Zarabia-22/denupe/issues) e incluye pasos para reproducirlos, comportamiento esperado, comportamiento observado y registros relevantes. No adjuntes credenciales ni datos personales de denunciantes.

Mantén los cambios enfocados, evita incluir secretos y no presentes como verificada una entidad pública si no existe una fuente que respalde su competencia.

### Licencia

Actualmente no se ha identificado un archivo `LICENSE` en la raíz del repositorio. Por tanto, **no se debe asumir que el proyecto está distribuido bajo MIT, GPL u otra licencia de código abierto**. Antes de reutilizar, modificar o redistribuir el código, solicita autorización a los titulares o espera a que se incorpore una licencia explícita.

## Arquitectura y estructura

La aplicación utiliza una arquitectura cliente-servidor desacoplada:

```text
Aplicación Flutter
   |
   | HTTPS / REST / JSON + JWT
   v
Backend principal FastAPI (Render)
   |-- Autenticación y sesiones JWT
   |-- Perfiles, permisos y catálogos
   |-- Denuncias, historial y notificaciones
   |-- Proxy autenticado de IA
   |-- Autorización de evidencias
   |
   |-- PostgreSQL (Render)
   |
   |-- URLs prefirmadas
          |
          v
      Cloudflare R2 privado

Backend principal
   |-- SMTP para verificación y recuperación
   |-- Microservicio de IA para clasificación y resolución territorial

Flutter consulta cambios de estado mediante sondeo REST autenticado.
```

### Directorios y componentes

| Ruta | Responsabilidad |
|---|---|
| `lib/config.dart` | URL del backend principal. |
| `lib/models.dart` | Modelos de categorías, perfiles, denuncias, evidencias e historial. |
| `lib/screens/` | Pantallas de autenticación, denuncias, detalle, notificaciones y paneles. |
| `lib/services/denupe_api.dart` | Cliente REST, JWT, refresh, perfiles, denuncias, R2 y notificaciones. |
| `lib/services/complaint_realtime.dart` | Seguimiento de cambios mediante sondeo autenticado. |
| `lib/services/ai_*.dart` | Adaptadores del proxy de IA del backend principal. |
| `lib/theme/` | Colores y tema visual. |
| `lib/widgets/` | Componentes reutilizables. |
| `assets/` | Logotipos e imágenes. |
| `test/` | Pruebas automatizadas. |

El esquema de base de datos y sus migraciones Alembic se mantienen en el repositorio del backend [denupe-backend](https://github.com/Zarabia-22/denupe-backend).

### Catálogo territorial

La base de datos incorpora las tablas `distritos_peru`, `entidades_resolucion` y `distrito_categoria_entidad`. El conjunto documentado contiene 1.893 UBIGEO y 15.144 relaciones para ocho categorías: alumbrado, seguridad, limpieza, agua, tránsito, áreas verdes, infraestructura y otros.

Estas relaciones indican resolutores sectoriales orientativos. La institución concreta debe determinarse mediante las fuentes geográficas y jurisdiccionales correspondientes; el UBIGEO por sí solo no prueba la competencia de una comisaría, concesionaria, EPS o titular vial.

---

**Repositorio:** [github.com/Zarabia-22/denupe](https://github.com/Zarabia-22/denupe) · **Backend:** [denupe-ia-backend](https://github.com/Zarabia-22/denupe-ia-backend) · **Soporte:** [Issues](https://github.com/Zarabia-22/denupe/issues)
