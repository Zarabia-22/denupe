# DenuPe

Aplicación móvil de **denuncias ciudadanas** desarrollada con Flutter e InsForge. Permite registrar incidencias, adjuntar evidencias, seleccionar manualmente una institución competente y consultar una recomendación de IA como ayuda opcional.

> **Versión del paquete:** 1.4.2 — Flutter / InsForge (Postgres BaaS) / FastAPI (servicio de IA).

---

## Funcionalidades

### Ciudadanos
- Registro, verificación de correo, inicio de sesión y perfil editable.
- Nueva denuncia con categoría, título, descripción, dirección, GPS y hasta 5 fotos o videos.
- Selección manual de destinos públicos disponibles según categoría y territorio.
- Recomendación opcional de categoría y entidad mediante IA; el ciudadano conserva la decisión final.
- Si no existe una institución verificable, la denuncia puede dirigirse a la bandeja interna de revisión de competencia. Esta bandeja no se presenta como entidad pública.
- Seguimiento de estados, historial, evidencias y notificaciones en tiempo real.

### Funcionarios
- Panel de denuncias asignadas a la entidad receptora.
- Consulta de información y evidencias de la denuncia.
- Actualización del estado con una nota opcional.

---

## Descarga e instalación

Consulta los [GitHub Releases](https://github.com/Zarabia-22/denupe/releases) para obtener una versión publicada. La configuración del APK distribuido depende de las variables incorporadas durante su compilación.

---

## Desarrollo local

### Requisitos
- Flutter SDK compatible con Dart `^3.13.4`.
- Git.
- Visual Studio Code con las extensiones Flutter y Dart.
- Android Studio/emulador o un dispositivo Android (opcional).

### 1. Clonar el repositorio

```bash
git clone https://github.com/Zarabia-22/denupe.git
cd denupe
```

### 2. Configurar variables de entorno

El archivo `.env` está excluido de Git porque contiene credenciales. Créalo a partir de la plantilla:

**Windows (PowerShell):**
```powershell
Copy-Item .env.example .env
```

**macOS / Linux:**
```bash
cp .env.example .env
```

Edita `.env` y configura valores reales:

- `INSFORGE_URL`: URL del proyecto InsForge.
- `INSFORGE_ANON_KEY`: clave pública/anon del proyecto.
- `DENUPE_IA_URL`: URL base HTTPS del backend FastAPI de DenuPe, sin barra final (por ejemplo, el servicio de pruebas HU-IA02 indicado en la plantilla).

No sustituyas las credenciales por valores ficticios ni publiques el archivo `.env`. El catálogo de instituciones para la selección manual y las recomendaciones de IA comparten este servicio, por lo que `DENUPE_IA_URL` es necesaria para disponer de ambas funciones. Si el servicio no responde, la app informa del problema y permite reintentar el catálogo; la denuncia aún puede continuar con la asignación de respaldo configurada en InsForge. La app no apunta silenciosamente a un servidor de pruebas.

### 3. Instalar dependencias

```bash
flutter pub get
```

### 4. Ejecutar la aplicación

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android
```

### 5. Compilar Android

```bash
flutter build apk --release
```

Para compilar la web:

```bash
flutter build web --release
cd build/web
python -m http.server 8080
```

Abre http://localhost:8080.

---

## Integración con el backend de IA

La app consume estos endpoints del servicio FastAPI:

- `GET /api/entidades/disponibles`: catálogo elegible por categoría y territorio.
- `POST /api/ia/sugerir-categoria`: sugerencia basada en título y descripción.
- `POST /api/ia/sugerir-entidad`: recomendación de destino público o abstención hacia revisión de competencia.
- `GET /health`: estado del servicio.

La URL se configura exclusivamente mediante `DENUPE_IA_URL`. El catálogo manual y las recomendaciones dependen de este servicio; si no responde, la app muestra el error y permite reintentar. La asignación de respaldo de InsForge evita bloquear el envío de la denuncia. Una recomendación de IA nunca se aplica sin confirmación del ciudadano.

**Cobertura territorial:** el catálogo de entidades descrito por el backend tiene cobertura inicial en Lima Metropolitana y Callao. La aplicación no debe asumir que una entidad está disponible para distritos o competencias que el backend no haya verificado.

---

## Soporte

Reporta incidencias en [GitHub Issues](https://github.com/Zarabia-22/denupe/issues).
