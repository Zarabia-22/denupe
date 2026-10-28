# DenuPe

<p align="center">
  <img src="assets/images/denupe_logo.png" alt="Logotipo de DenuPe" width="160">
</p>

**DenuPe** es una aplicación móvil de **denuncias ciudadanas** que facilita el reporte y seguimiento de incidentes en la comunidad. Permite describir un problema, indicar su ubicación, adjuntar evidencias y consultar su estado. Incluye una función de **inteligencia artificial que sugiere categorías** a partir del título y la descripción.

> **Versión actual:** 1.3.0 · **Aplicación:** Flutter · **Backend de datos:** InsForge (PostgreSQL) · **IA:** Python + FastAPI, desplegada en Render.  
> **Estado:** prototipo académico / versión de pruebas. La app no sustituye los canales oficiales de emergencia ni garantiza la atención institucional de una denuncia.

## Descargar e instalar

**Android:** [Descargar DenuPe 1.3.0 (APK)](https://github.com/Zarabia-22/denupe/releases/download/v1.3.0/denupe-1.3.0.apk) · [Ver notas de la versión](https://github.com/Zarabia-22/denupe/releases/tag/v1.3.0).

1. Descarga el APK desde la versión publicada en GitHub Releases.
2. Abre el archivo en tu dispositivo Android.
3. Si Android lo solicita, habilita la instalación desde esa fuente y confirma.
4. Abre DenuPe, regístrate y verifica tu correo electrónico.

La versión 1.3.0 incorpora sugerencias de categoría con IA, ajustes de interfaz y el icono de DenuPe. La APK es una **versión de prueba distribuida por GitHub**, no una publicación en una tienda de aplicaciones.

## Funcionalidades

### Ciudadanos

| Funcionalidad | Descripción |
|---|---|
| Registro y acceso | Registro con verificación de correo, inicio/cierre de sesión y conservación de la sesión cuando corresponde. |
| Perfil | Consulta y edición de nombre, DNI, teléfono y distrito. Para enviar una denuncia se requiere el perfil completo. |
| Nueva denuncia | Formulario con título, descripción, categoría, dirección y ubicación GPS opcional. |
| Evidencias | Adjunta desde la galería hasta **5 fotografías o videos**; límite de **50 MB por archivo**. |
| Sugerencia con IA | Analiza el **título y la descripción** para sugerir una categoría, sin seleccionarla definitivamente hasta que el ciudadano la acepte. |
| Confirmación | Revisión de la información y elección de la entidad destinataria antes del envío definitivo. |
| Mis denuncias | Listado, detalle e historial de estados de las denuncias registradas. |
| Notificaciones | Avisos dentro de la aplicación sobre cambios de estado; pueden marcarse como leídos. |

Los estados contemplados son: **Recibida**, **En revisión**, **En proceso**, **Resuelta**, **Rechazada** y **Archivada**.

### Funcionarios

- Panel de denuncias asociadas a la entidad del funcionario.
- Consulta del detalle de los reportes y de los datos de contacto permitidos.
- Actualización del estado con una nota opcional para el historial.

> La selección de la entidad, el registro de una denuncia y su seguimiento pertenecen al backend de datos de DenuPe. **La IA solo propone la categoría**: no determina automáticamente la autoridad, la prioridad ni la resolución del caso.

## Inteligencia artificial: sugerencia de categorías

La IA permite que el ciudadano describa un incidente en lenguaje cotidiano y reciba una recomendación antes de seleccionar la categoría definitiva.

**Categorías del prototipo:** `Alumbrado`, `Limpieza`, `Ruido` y `Seguridad`.

**Flujo de funcionamiento:**

1. El ciudadano introduce el **título** y la **descripción** de la denuncia.
2. Pulsa **«Sugerir categoría con IA»**.
3. Flutter envía ambos textos por HTTPS al servicio **FastAPI**.
4. El servicio utiliza un vectorizador **TF-IDF** y un **árbol de decisión** entrenado para producir una recomendación.
5. La aplicación comprueba si la categoría devuelta corresponde a una categoría disponible en DenuPe.
6. El ciudadano **acepta la sugerencia o elige manualmente**. Si la IA falla, la información es insuficiente o no existe una correspondencia única, el formulario permite continuar manualmente.

El modelo es una **prueba de concepto entrenada con 200 registros simulados**; obtuvo una exactitud del **83,33 %** en su conjunto de prueba sintético. Esa cifra **no representa una precisión validada con denuncias reales**.

**Recursos del backend de IA:**

- [Repositorio de Python + FastAPI](https://github.com/Zarabia-22/denupe-ia-backend)
- [API pública y documentación Swagger](https://denupe-ia-backend.onrender.com/docs)
- [Verificación de disponibilidad](https://denupe-ia-backend.onrender.com/health)

**Endpoint de predicción:**

```http
POST https://denupe-ia-backend.onrender.com/api/ia/sugerir-categoria
Content-Type: application/json
```

Cuerpo de ejemplo:

```json
{
  "titulo": "Basura acumulada en mi calle",
  "descripcion": "Hay bolsas de basura y residuos que no han sido recogidos durante varios dias"
}
```

La respuesta incluye `sugerida`, `categoria`, `motivo` y datos informativos del modelo. Cuando `sugerida` es `false`, DenuPe mantiene la selección manual.

> El servicio de IA alojado en el plan gratuito de Render puede tardar en responder después de un periodo de inactividad. El cliente Flutter tiene un tiempo de espera de 15 segundos y muestra una alternativa manual ante errores.

## Arquitectura y tecnologías

| Componente | Tecnología | Responsabilidad |
|---|---|---|
| Aplicación móvil | Flutter / Dart | Interfaz, navegación, formularios y consumo de servicios. |
| Backend de datos | InsForge (PostgreSQL BaaS) | Autenticación, perfiles, denuncias, entidades, historial y notificaciones. |
| Evidencias | InsForge Storage | Almacenamiento de fotografías y videos. |
| Actualizaciones | InsForge y conexión en tiempo real | Reflejar cambios de las denuncias y notificaciones. |
| Servicio de IA | Python, FastAPI, Scikit-learn | Clasificación de textos mediante TF-IDF y árbol de decisión. |
| Despliegue de IA | Render + Docker | API HTTPS independiente de la aplicación. |
| Repositorios | GitHub | Control de versiones y automatización de pruebas del servicio IA. |

El proyecto está organizado en pantallas, servicios, modelos, componentes compartidos y temas visuales. El servicio de inteligencia artificial se mantiene **separado** del backend de datos.

```text
denupe/
├── android/                 # Configuración Android
├── ios/                     # Configuración iOS
├── assets/                  # Recursos e imágenes
├── lib/
│   ├── main.dart            # Arranque e inicialización
│   ├── app.dart             # Navegación raíz
│   ├── config.dart          # Variables de entorno
│   ├── models.dart          # Modelos de datos
│   ├── screens/             # Registro, denuncias, perfil, panel, etc.
│   ├── services/            # Acceso a InsForge y al servicio de IA
│   ├── theme/               # Colores y estilos
│   └── widgets/             # Componentes reutilizables
├── migrations/              # Migraciones SQL de InsForge
├── test/                    # Pruebas Flutter
├── .env.example             # Plantilla de configuración
└── pubspec.yaml             # Dependencias y versión
```

## Desarrollo local

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) con una versión compatible con el `pubspec.yaml` del repositorio.
- [Git](https://git-scm.com/).
- Android Studio, un emulador Android o un teléfono con depuración USB habilitada.
- Opcional: [Visual Studio Code](https://code.visualstudio.com/) y las extensiones Flutter y Dart.
- Credenciales de acceso a un proyecto **InsForge** configurado con las migraciones y recursos que necesita DenuPe.

### 1. Clonar el proyecto

```bash
git clone https://github.com/Zarabia-22/denupe.git
cd denupe
```

### 2. Configurar las variables de entorno

Copia `.env.example` a `.env` y reemplaza los datos de InsForge con los de **tu proyecto**:

```env
INSFORGE_URL=https://tu-proyecto.us-east.insforge.app
INSFORGE_ANON_KEY=anon_xxxxxxxxxxxxxxxxxxxx
DENUPE_IA_URL=https://denupe-ia-backend.onrender.com
```

- `INSFORGE_URL` y `INSFORGE_ANON_KEY` son necesarios para iniciar la aplicación.
- `DENUPE_IA_URL` permite utilizar otro servidor de IA; si está ausente, la aplicación usa la URL pública de Render.
- Para probar FastAPI en un emulador Android, puedes sustituirla por `http://10.0.2.2:8000` **solo para desarrollo local**.
- **No subas tu archivo `.env` al repositorio.** Las variables integradas en el cliente móvil no deben contener claves administrativas ni secretos privados; utiliza únicamente credenciales destinadas al cliente.

### 3. Instalar dependencias y ejecutar

```bash
flutter doctor
flutter pub get
flutter devices
flutter run
```

Selecciona tu dispositivo si Flutter detecta más de uno. Para ejecutar pruebas del proyecto:

```bash
flutter test
```

Para generar una APK local:

```bash
flutter build apk --release
```

**Aviso:** la configuración Android actual firma las compilaciones `release` con las claves de depuración. Antes de distribuir la aplicación por una tienda o como producto final debe configurarse la **firma de producción**.

### 4. Desarrollar el servicio de IA por separado

El backend de IA no requiere ejecutar Flutter para probar sus predicciones. Revisa sus instrucciones en [denupe-ia-backend](https://github.com/Zarabia-22/denupe-ia-backend). Puede probarse mediante Swagger UI y mediante su endpoint `/health`.

## Alcance actual y próximas mejoras

**Disponible en el código actual:** registro e inicio de sesión, perfiles, formulario de denuncias, ubicación, carga de evidencias, selección de entidad, historial, notificaciones dentro de la aplicación, panel de funcionarios y sugerencias de categoría con IA.

**Pendiente o fuera del alcance de esta versión:** pruebas completas de usabilidad y precisión del modelo con ciudadanos reales, autenticación y limitación de solicitudes en la API pública de IA, envío automático de denuncias sin conexión y notificaciones por SMS. Tampoco se ha implementado reconocimiento de imágenes para clasificar incidencias.

## Contribuciones y soporte

Para comunicar errores o proponer mejoras, utiliza [GitHub Issues](https://github.com/Zarabia-22/denupe/issues).

**Proyecto DenuPe — Plataforma de Denuncias Ciudadanas Accesibles.**
