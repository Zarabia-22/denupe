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
## Catálogo nacional de entidades por distrito (asignación solo con GPS)

La migración `20261119010000_catalogo_nacional_entidades_por_distrito_gps.sql` crea:
- `distritos_peru`: catálogo territorial nacional por UBIGEO (1,893 registros de distrito en la versión de datos incorporada).
- `entidades_resolucion`: resolutores sectoriales para municipalidad local, PNP, concesionaria eléctrica, EPS/operador de saneamiento, autoridad de tránsito, titular vial y ventanilla municipal.
- `distrito_categoria_entidad`: matriz precargada de 8 categorías por distrito (15,144 relaciones para 1,893 distritos).

La matriz es una **relación de enrutamiento**, no una asignación anticipada a una institución concreta. La institución real se resuelve después de obtener latitud/longitud, intersectar el punto con los límites distritales oficiales, obtener el UBIGEO y consultar la relación de su categoría. Para PNP, electricidad, saneamiento, transporte y vialidad también se valida la jurisdicción sectorial específica; el distrito por sí solo no reemplaza esos polígonos o ámbitos de prestación.

La migración elimina la autoridad predeterminada global de las categorías y permite que `denuncias.autoridad_id` permanezca nulo al crear una denuncia. El trigger `limpiar_asignacion_entidad_cliente` evita que un cliente asigne una institución o UBIGEO directamente. El backend confiable registra la resolución mediante `registrar_entidad_resuelta_por_gps`, que exige coordenadas GPS en la denuncia y una relación UBIGEO-categoría-resolutor existente. La función presupone que el backend ya validó el punto contra el polígono geográfico; no sustituye esa comprobación espacial.

### Mapeo de categorías

| Código | Entidad/resolutor relacionado | Cómo se determina la institución final |
|---|---|---|
| `alumbrado` | Concesionaria eléctrica | GPS contra polígonos de concesión OSINERGMIN/MINEM |
| `seguridad` | Comisaría PNP | GPS contra polígonos oficiales de jurisdicción PNP y validación de comisaría operativa |
| `limpieza` | Municipalidad local | UBIGEO + directorio oficial de municipalidades |
| `agua` | EPS/SEDAPAL/JASS u operador | GPS + ámbito oficial SUNASS y cobertura efectiva del predio |
| `transito` | Autoridad de tránsito/transporte | GPS + tipo de incidente y competencia ATU/provincial/local/MTC |
| `areas_verdes` | Municipalidad local | UBIGEO + validación de titularidad/administración del parque |
| `infraestructura` | Titular/gestor del tramo vial | GPS + jerarquía, titularidad y concesión del tramo |
| `otros` | Municipalidad como ventanilla inicial | UBIGEO + clasificación posterior de competencia |

**Límite de datos:** el listado de UBIGEO se incorpora desde el conjunto `ubigeos_2026.csv` de [Rodasluis/Peru-maps](https://github.com/Rodasluis/Peru-maps), que declara derivación del SISCONCODE/INEI; el directorio de municipalidades vigente se debe contrastar con el [directorio INEI 2026](https://www.gob.pe/institucion/inei/informes-publicaciones/8058591). Los 1,893 registros territoriales no significan que existan 1,893 municipalidades distritales operativas ni que cada resolutor sectorial esté validado nominalmente para cada distrito. Los mapeos de PNP, concesionarias, EPS y titulares viales se resuelven contra sus fuentes oficiales en tiempo de asignación.
