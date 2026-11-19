# DenuPe

Aplicación móvil de **denuncias ciudadanas**: los vecinos reportan problemas de su distrito (alumbrado, seguridad, limpieza, agua, etc.) y las entidades responsables (municipalidad, comisaría, serenazgo) los reciben, se asignan y se atienden hasta su resolución.

> **Versión:** 1.2.0 — Flutter / InsForge (Postgres BaaS)

---

## Funcionalidades

### Ciudadanos
- **Cuenta y perfil**: registro with verificación de correo, inicio de sesión y perfil editable (nombre, DNI, teléfono, distrito). La denuncia se bloquea si el perfil está incompleto.
- **Nueva denuncia**: formulario con categoría, título, descripción, dirección, ubicación GPS y hasta 5 fotos/videos. Los datos del denunciante se toman automáticamente del perfil.
- **Confirmación previa**: antes de terminar se muestra un resumen de la denuncia y el ciudadano elige el **tipo de entidad** que la atenderá (Municipalidad / Comisaría / Serenazgo).
- **Seguimiento**: "Mis denuncias" muestra el estado en tiempo real (Recibida → En revisión → En proceso → Resuelta), historial y evidencias adjuntas.
- **Alertas**: notificaciones in-app en tiempo real de cada cambio de estado.

### Funcionarios (entidades)
- **Panel**: lista de denuncias asignadas a su entidad, con datos del denunciante para contactarlo.
- **Gestión de estados**: cambia el estado de cada denuncia con nota opcional; el ciudadano recibe la alerta al instante.

---

## Descarga e instalación

### Opción 1: desde GitHub Releases (recomendada)
1. Abre [v1.2.0](https://github.com/Zarabia-22/denupe/releases/tag/v1.2.0).
2. Descarga el archivo denupe-1.2.0.apk.
3. En el teléfono Android, abre el archivo descargado y permite la instalación desde orígenes desconocidos si lo solicita.
4. Confirma la instalación y abre **DenuPe**.

### Cuenta demo (funcionario)
- **Correo:** uncionario.municipal@denupe.test
- **Contraseña:** Funcionario123

---

## Desarrollo local

### Requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Git](https://git-scm.com/)
- [Visual Studio Code](https://code.visualstudio.com/) con extensiones Flutter y Dart
- (Opcional) Android Studio / emulador Android
- (Opcional) Python 3 para servir build web

### 1) Clonar el repositorio
`ash
git clone https://github.com/Zarabia-22/denupe.git
cd denupe
`

### 2) Configurar VS Code
1. Abrir VS Code → Archivo > Abrir carpeta... → seleccionar denupe.
2. Instalar extensiones Flutter y Dart si no las tienes.
3. Usar Flutter: Select Device (Ctrl+Shift+P) para elegir dispositivo/emulador/navegador.

### 3) Instalar dependencias
`ash
flutter pub get
`

### 4) Levantar en servidor local HTTP (web)
`ash
# Compilar
flutter build web --release

# Servir
cd build/web
python -m http.server 8080
# o: py -m http.server 8080
`
Abrir [http://localhost:8080](http://localhost:8080)

### 5) Ejecutar en desarrollo
`ash
# Web
flutter run -d chrome

# Android (emulador/dispositivo)
flutter run -d android

# Windows (si habilitado)
flutter run -d windows
`

---

## Requisitos mínimos
- Android 8.0 (API 26) o superior
- Conexión a internet

## Soporte
Reporta incidencias en [https://github.com/Zarabia-22/denupe/issues](https://github.com/Zarabia-22/denupe/issues)

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
