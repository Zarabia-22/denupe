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
