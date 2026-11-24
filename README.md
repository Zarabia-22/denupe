# DenuPe

<p align="center">
  <img src="assets/denupe_logo.png" alt="Logotipo de DenuPe" width="150" />
</p>

<p align="center">
  <strong>Plataforma móvil de denuncias ciudadanas</strong><br />
  Reporta incidencias de tu comunidad, adjunta evidencias y sigue su atención desde un solo lugar.
</p>

<p align="center">
  <a href="https://github.com/Zarabia-22/denupe/releases"><img src="https://img.shields.io/badge/versi%C3%B3n-1.4.8%2B14-2457A7" alt="Versión 1.4.8+14" /></a>
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
| InsForge Flutter SDK | Integración de la aplicación con los servicios de InsForge. |
| InsForge y PostgreSQL | Autenticación, persistencia, datos y funciones RPC. |
| Python y FastAPI | API independiente de recomendaciones y resolución territorial. |
| scikit-learn | Procesamiento de texto y clasificación de categorías en el backend. |
| HTTP y JSON | Comunicación entre la aplicación y la API. |
| Socket.IO | Eventos y actualizaciones en tiempo real. |
| Geolocator | Obtención de coordenadas con permiso del usuario. |
| Image Picker | Selección de fotografías y videos. |
| flutter_dotenv | Configuración mediante variables de entorno. |
| flutter_secure_storage | Almacenamiento seguro compatible con la plataforma. |
| url_launcher | Apertura de enlaces externos. |

## Prerrequisitos

Para desarrollar y ejecutar el proyecto localmente:

- Git.
- Flutter SDK y Dart compatibles con la restricción declarada en `pubspec.yaml`: Dart `^3.13.4`.
- Android Studio y Android SDK, o un dispositivo Android para ejecutar la aplicación móvil.
- Google Chrome si se desea ejecutar la versión web.
- Un proyecto de InsForge con su URL y clave pública/anon.
- Acceso a una instancia del backend FastAPI para probar el catálogo territorial y las funciones de IA.
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

Edita el archivo `.env`:

| Variable | Descripción |
|---|---|
| `INSFORGE_URL` | URL base del proyecto InsForge. |
| `INSFORGE_ANON_KEY` | Clave pública/anon para las operaciones cliente autorizadas por las políticas de acceso. |
| `DENUPE_IA_URL` | URL base del backend FastAPI, sin barra final. |

Ejemplo ilustrativo; reemplaza los valores por los de tu entorno:

```dotenv
INSFORGE_URL=https://tu-proyecto.us-east.insforge.app
INSFORGE_ANON_KEY=tu_clave_publica
DENUPE_IA_URL=https://tu-backend.onrender.com
```

Para acceder desde el emulador Android a un backend que corre en el equipo anfitrión, normalmente se utiliza `http://10.0.2.2:8000`. En un dispositivo físico utiliza una dirección accesible desde ese dispositivo.

**Seguridad:** no subas el archivo `.env`, tokens ni credenciales administrativas. La clave anon no reemplaza las políticas de autorización de InsForge. No configures una URL de pruebas como si fuera producción.

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

### Comprobar el backend de IA

Con el backend configurado en `DENUPE_IA_URL`, puedes comprobar su disponibilidad:

```bash
curl https://tu-backend.onrender.com/health
```

La aplicación integra estos endpoints del backend:

| Método | Endpoint | Propósito |
|---|---|---|
| `GET` | `/health` | Comprobar disponibilidad del servicio. |
| `POST` | `/api/ia/sugerir-categoria` | Solicitar una categoría sugerida a partir del texto de la denuncia. |
| `GET` | `/api/entidades/disponibles` | Consultar entidades disponibles según los parámetros territoriales y de categoría. |
| `POST` | `/api/ia/sugerir-entidad` | Solicitar una recomendación de entidad o una abstención. |

Consulta el [README del backend](https://github.com/Zarabia-22/denupe-ia-backend) para conocer los esquemas de petición y respuesta vigentes de cada endpoint.

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

DenuPe está organizada en una aplicación Flutter y servicios backend desacoplados:

```text
Aplicación Flutter
   |-- InsForge SDK
   |     |-- Autenticación
   |     |-- PostgreSQL / RPC
   |     |-- Datos y almacenamiento
   |
   |-- HTTP REST
   |     |-- Backend FastAPI
   |           |-- Sugerencia de categoría
   |           |-- Catálogo y resolución territorial
   |           |-- Recomendación de entidad
   |
   |-- Socket.IO
         |-- Eventos y actualizaciones en tiempo real
```

### Directorios y componentes

| Ruta | Responsabilidad |
|---|---|
| `lib/config.dart` | Lectura y validación de configuración. |
| `lib/models.dart` y `lib/models/` | Modelos y estructuras de datos. |
| `lib/screens/` | Pantallas de autenticación, denuncias, detalle y paneles. |
| `lib/services/` | Integración con InsForge, API de IA y eventos en tiempo real. |
| `lib/theme/` | Colores y tema visual. |
| `lib/widgets/` | Componentes reutilizables. |
| `assets/` | Logotipos e imágenes. |
| `test/` | Pruebas automatizadas. |
| `migrations/` | Migraciones SQL para InsForge. |

### Catálogo territorial

La base de datos incorpora las tablas `distritos_peru`, `entidades_resolucion` y `distrito_categoria_entidad`. El conjunto documentado contiene 1.893 UBIGEO y 15.144 relaciones para ocho categorías: alumbrado, seguridad, limpieza, agua, tránsito, áreas verdes, infraestructura y otros.

Estas relaciones indican resolutores sectoriales orientativos. La institución concreta debe determinarse mediante las fuentes geográficas y jurisdiccionales correspondientes; el UBIGEO por sí solo no prueba la competencia de una comisaría, concesionaria, EPS o titular vial.

---

**Repositorio:** [github.com/Zarabia-22/denupe](https://github.com/Zarabia-22/denupe) · **Backend:** [denupe-ia-backend](https://github.com/Zarabia-22/denupe-ia-backend) · **Soporte:** [Issues](https://github.com/Zarabia-22/denupe/issues)
