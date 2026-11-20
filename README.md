# DenuPe

**DenuPe** es una aplicación móvil de participación ciudadana desarrollada con **Flutter**. Permite reportar incidencias de la comunidad, adjuntar evidencias, indicar dónde ocurre el problema, seleccionar una institución receptora y hacer seguimiento del estado de la denuncia.

La solución integra **InsForge** como plataforma de backend y persistencia, y un microservicio independiente desarrollado con **Python y FastAPI** para sugerir categorías y apoyar la identificación de entidades competentes. La inteligencia artificial es asistencial: la persona conserva el control de la categoría y del destino de su denuncia.

<text align="center"> </text>

<badge>Versión 1.4.4+10</badge>

---

## 1. Funcionalidades

### Ciudadanía

- **Registro e inicio de sesión:** creación de cuenta, verificación de correo electrónico mediante código y autenticación.
- **Perfil:** consulta y actualización de los datos del usuario, incluido el distrito.
- **Registro de denuncias:** formulario para seleccionar categoría, ingresar título y descripción, registrar ubicación y adjuntar evidencias.
- **Evidencias multimedia:** selección de fotografías y videos desde el dispositivo.
- **Ubicación:** captura de coordenadas y dirección asociada a la incidencia, según los permisos y disponibilidad del dispositivo.
- **Selección de entidad:** consulta del catálogo disponible y selección manual de la institución receptora.
- **Sugerencia de categoría con IA:** analiza el título y la descripción y propone una de las categorías disponibles. La persona puede aceptar o mantener su selección.
- **Sugerencia de entidad con IA:** utiliza el contexto de la denuncia y territorial para proponer una institución cuando existe evidencia suficiente. La recomendación puede aceptarse, volver a solicitarse o ignorarse.
- **Revisión de competencia:** cuando no se puede confirmar una entidad pública concreta, la denuncia puede mantenerse para revisión interna de DenuPe. Esta bandeja no es una institución pública.
- **Seguimiento:** consulta de denuncias, estados, historial y detalle.
- **Notificaciones:** recepción y actualización de notificaciones asociadas a las denuncias.

### Funcionarios

- Consulta de denuncias recibidas por la entidad asociada a su cuenta.
- Visualización de datos y evidencias de cada denuncia.
- Actualización del estado y registro de una nota opcional, según los permisos del rol.

---

## 2. Arquitectura general

DenuPe está organizada en una aplicación Flutter y servicios backend desacoplados.

```text
                    Aplicación Flutter
                           |
          +----------------+----------------+
          |                |                |
          v                v                v
    InsForge SDK       HTTP REST        Socket.IO
          |                |                |
          v                v                v
  Autenticación, DB   Backend FastAPI   Eventos en tiempo
  y almacenamiento   (servicio de IA)   real / notificaciones
          |                |
          v                v
  PostgreSQL y RPC    Modelo de categorías
  Catálogo territorial y resolución de entidades
```

### Tecnologías

| Tecnología | Uso en el proyecto |
|---|---|
| Flutter | Desarrollo de la aplicación multiplataforma. |
| Dart | Lenguaje de programación de la interfaz y lógica cliente. |
| InsForge Flutter SDK | Acceso a autenticación, base de datos y servicios de InsForge. |
| InsForge / PostgreSQL | Persistencia de usuarios, perfiles, denuncias, categorías, entidades y datos relacionados. |
| FastAPI | API independiente para las recomendaciones de IA y las consultas territoriales. |
| Python / scikit-learn | Procesamiento de texto y clasificación de categorías en el backend. |
| HTTP / JSON | Comunicación entre Flutter y FastAPI. |
| Socket.IO | Comunicación de eventos en tiempo real. |
| Geolocator | Obtención de coordenadas del dispositivo con permiso del usuario. |
| Image Picker | Selección de fotografías y videos. |
| Flutter Dotenv | Lectura de configuración por entorno desde `.env`. |
| Flutter Secure Storage | Almacenamiento seguro de información de sesión compatible con la plataforma. |
| URL Launcher | Apertura de enlaces externos. |

Repositorio del backend de IA: https://github.com/Zarabia-22/denupe-ia-backend

---

## 3. Organización del proyecto

La aplicación concentra sus componentes principales en `lib/`.

| Directorio / archivo | Responsabilidad |
|---|---|
| `lib/config.dart` | Lectura y validación de las URL y claves de configuración. |
| `lib/models.dart` y `lib/models/` | Modelos y estructuras de datos de la aplicación. |
| `lib/screens/` | Pantallas de autenticación, registro, denuncias, detalle, confirmación y paneles. |
| `lib/services/` | Acceso a InsForge, API de IA, eventos en tiempo real y lógica de servicios. |
| `lib/theme/` | Colores y configuración visual de la aplicación. |
| `lib/widgets/` | Componentes reutilizables de interfaz. |
| `lib/routes/` | Navegación y rutas, cuando corresponda. |
| `assets/` | Logotipos, imágenes y recursos visuales. |
| `test/` | Pruebas automatizadas de Flutter. |
| `migrations/` | Scripts SQL para cambios de esquema y catálogo en InsForge. |

### Servicios de integración destacados

- `AiCategoryService`: envía el título y la descripción al endpoint de sugerencia de categoría y procesa la respuesta.
- `AiEntityService`: consulta el catálogo de entidades disponibles y solicita una recomendación de entidad; convierte las respuestas JSON en modelos usados por la interfaz.
- `DenupeApi`: centraliza las operaciones de la aplicación con InsForge, como autenticación, categorías, autoridades y denuncias.
- `ComplaintRealtime`: administra la conexión de eventos en tiempo real.
- `app_scope.dart`: comparte instancias de servicios y cachés de categorías y entidades entre pantallas.

---

## 4. Flujo de registro de una denuncia

1. La persona inicia una nueva denuncia.
2. Selecciona una categoría o solicita una sugerencia de IA a partir del título y la descripción.
3. Completa la información del incidente.
4. Adjunta fotografías o videos, si dispone de ellos.
5. Registra la ubicación y revisa los datos ingresados.
6. En la confirmación, consulta las entidades disponibles y puede seleccionar una manualmente.
7. Opcionalmente solicita una recomendación de entidad mediante IA.
8. Revisa la sugerencia y decide si la utiliza. Si no existe una entidad verificable, se mantiene la alternativa de revisión de competencia.
9. Confirma el envío y consulta posteriormente el estado de su denuncia.

La sugerencia de IA no se aplica de manera silenciosa ni reemplaza la decisión del ciudadano.

---

## 5. Integración con el backend de IA

La aplicación consume el microservicio FastAPI mediante la URL configurada en `DENUPE_IA_URL`.

| Método | Endpoint | Uso desde Flutter |
|---|---|---|
| `GET` | `/health` | Comprobación básica de disponibilidad del servicio. |
| `POST` | `/api/ia/sugerir-categoria` | Recomendación de categoría usando título y descripción. |
| `GET` | `/api/entidades/disponibles` | Obtención del catálogo para selección manual según categoría y territorio. |
| `POST` | `/api/ia/sugerir-entidad` | Recomendación de institución o respuesta de abstención. |

### Comportamiento ante errores

- Si no se configura `DENUPE_IA_URL`, la aplicación informa que el servicio no está disponible para esa función.
- Si la solicitud supera el tiempo de espera o devuelve una respuesta inválida, se informa el problema y se conserva la posibilidad de selección manual.
- Si el modelo no tiene evidencia suficiente, el backend devuelve una abstención y no fuerza una categoría.
- Si no se verifica una institución concreta, no se presenta una entidad como competente.

La documentación técnica de algoritmos, endpoints, variables del servidor y pruebas del microservicio se encuentra en el [README del backend](https://github.com/Zarabia-22/denupe-ia-backend).

---

## 6. Catálogo territorial y entidades

La base de datos incorpora una estructura territorial por UBIGEO y una matriz de relaciones entre distrito, categoría y resolutor sectorial.

La migración `20261119010000_catalogo_nacional_entidades_por_distrito_gps.sql` crea:

| Tabla | Propósito |
|---|---|
| `distritos_peru` | Catálogo territorial por UBIGEO. |
| `entidades_resolucion` | Catálogo de resolutores sectoriales. |
| `distrito_categoria_entidad` | Relación de categorías y resolutores por distrito. |

La matriz contempla ocho categorías: alumbrado, seguridad, limpieza, agua, tránsito, áreas verdes, infraestructura y otros. En el conjunto territorial incorporado se registran 1.893 UBIGEO y 15.144 relaciones distrito-categoría.

**Importante:** estas relaciones son reglas de enrutamiento, no un directorio que certifique una institución concreta para cada categoría en todos los distritos. Para identificar la institución receptora se requiere validar la ubicación y la jurisdicción sectorial correspondiente. La existencia de un resolutor como municipalidad, PNP, operador de saneamiento o autoridad vial no demuestra por sí sola la competencia de una institución nominal.

El backend dispone de resolución territorial basada en GPS y consulta de la matriz en InsForge. Sin embargo, la interfaz Flutter de selección de entidades de esta versión todavía contiene una restricción de distrito de perfil para Lima Metropolitana y Callao. Por ello, no debe interpretarse la matriz nacional como disponibilidad de selección manual nacional ya habilitada en la app móvil.

### Categorías y resolutores orientativos

| Categoría | Resolutor sectorial orientativo |
|---|---|
| Alumbrado | Concesionaria eléctrica correspondiente. |
| Seguridad | Comisaría / jurisdicción PNP. |
| Limpieza | Municipalidad competente. |
| Agua | EPS u operador de saneamiento correspondiente. |
| Tránsito | Autoridad de transporte competente según el ámbito. |
| Áreas verdes | Municipalidad o administrador competente del espacio. |
| Infraestructura | Titular o gestor de la vía. |
| Otros | Ventanilla municipal o revisión posterior de competencia. |

La asignación final depende de las fuentes geográficas, los directorios y las validaciones de competencia disponibles para cada caso.

---

## 7. Requisitos previos

Para ejecutar el proyecto localmente se necesita:

- Flutter SDK con Dart compatible con `^3.13.4`.
- Git.
- Android Studio o un dispositivo Android para ejecutar la versión móvil.
- Visual Studio Code (opcional) con las extensiones Flutter y Dart.
- Un proyecto InsForge configurado.
- Acceso al backend FastAPI para probar las funciones de IA y el catálogo territorial.

Comprueba la instalación de Flutter:

```bash
flutter doctor
```

---

## 8. Instalación y ejecución local

### 8.1 Clonar el repositorio

```bash
git clone https://github.com/Zarabia-22/denupe.git
cd denupe
```

### 8.2 Configurar las variables de entorno

El archivo `.env` no se debe subir al repositorio. Crea una copia de la plantilla:

**Windows PowerShell**

```powershell
Copy-Item .env.example .env
```

**macOS / Linux**

```bash
cp .env.example .env
```

Configura los valores de tu entorno:

| Variable | Descripción |
|---|---|
| `INSFORGE_URL` | URL base del proyecto InsForge. |
| `INSFORGE_ANON_KEY` | Clave pública/anon para las operaciones cliente permitidas por las políticas de acceso. |
| `DENUPE_IA_URL` | URL base HTTPS del backend FastAPI, sin barra final. |

Ejemplo de configuración local (reemplaza los valores por los de tu entorno):

```dotenv
INSFORGE_URL=https://tu-proyecto.us-east.insforge.app
INSFORGE_ANON_KEY=anon_tu_clave_publica
DENUPE_IA_URL=https://tu-backend.onrender.com
```

Para un emulador Android que ejecuta el backend localmente, normalmente se utiliza `http://10.0.2.2:8000` como URL de acceso al host. En un dispositivo físico se debe usar una dirección accesible desde ese dispositivo.

No publiques el archivo `.env`, claves privadas, tokens ni credenciales administrativas. La clave anon no sustituye las políticas de autorización de la base de datos.

### 8.3 Instalar dependencias

```bash
flutter pub get
```

### 8.4 Ejecutar la aplicación

**Web**

```bash
flutter run -d chrome
```

**Android**

```bash
flutter run -d android
```

También puedes seleccionar un dispositivo conectado:

```bash
flutter devices
flutter run -d <device_id>
```

---

## 9. Compilación

### APK Android

```bash
flutter build apk --release
```

El archivo se genera en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Aplicación web

```bash
flutter build web --release
```

Para servir localmente el resultado:

```bash
cd build/web
python -m http.server 8080
```

Abre http://localhost:8080 en el navegador.

---

## 10. Pruebas y análisis

Ejecuta el análisis estático:

```bash
flutter analyze
```

Ejecuta las pruebas automatizadas:

```bash
flutter test
```

Para ejecutar una prueba específica:

```bash
flutter test test/widget_test.dart
```

Antes de integrar cambios, comprueba que el análisis y las pruebas finalicen correctamente.

---

## 11. Versiones y publicación

La versión declarada actualmente en `pubspec.yaml` es:

- **Versión:** `1.4.4`
- **Build:** `10`
- **Identificador completo:** `1.4.4+10`

Las versiones publicadas y sus paquetes de instalación se encuentran en [GitHub Releases](https://github.com/Zarabia-22/denupe/releases).

Para reportar errores o solicitar mejoras, utiliza [GitHub Issues](https://github.com/Zarabia-22/denupe/issues).

---

## 12. Seguridad y consideraciones

- No incluyas secretos ni claves administrativas de InsForge en el código Flutter.
- Configura las políticas de acceso y autorización de InsForge para que cada usuario solo pueda consultar o modificar los registros permitidos por su rol.
- Solicita permisos de ubicación y multimedia cuando sean necesarios y explica su uso.
- La geolocalización depende del permiso concedido, la precisión del dispositivo y la disponibilidad de señal.
- La IA es un mecanismo de apoyo; las recomendaciones inciertas deben permitir selección manual o revisión de competencia.
- La matriz de relaciones territoriales no garantiza por sí sola que una institución concreta esté verificada para cada categoría y distrito.
- Los datos de prueba o simulados no deben presentarse como denuncias ciudadanas reales.

---

## 13. Repositorios relacionados

- **Aplicación móvil:** https://github.com/Zarabia-22/denupe
- **Backend de IA y resolución territorial:** https://github.com/Zarabia-22/denupe-ia-backend
