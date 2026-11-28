import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun validateReleaseSigning() {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException("Falta android/key.properties: configura la firma de release antes de compilar.")
    }
    val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingKeys = requiredKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missingKeys.isNotEmpty()) {
        throw GradleException("android/key.properties incompleto. Faltan: ${missingKeys.joinToString(", ")}")
    }
    val releaseStoreFile = keystorePropertiesFile.resolveSibling(keystoreProperties.getProperty("storeFile").trim()).absoluteFile
    if (!releaseStoreFile.exists()) {
        throw GradleException("No se encontró el keystore de release: ${releaseStoreFile.absolutePath}")
    }
}

android {
    namespace = "com.denupe.denupe"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.denupe.denupe"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storePath = keystoreProperties.getProperty("storeFile")?.trim().orEmpty()
            if (storePath.isNotEmpty()) {
                storeFile = keystorePropertiesFile.resolveSibling(storePath).absoluteFile
            }
            storePassword = keystoreProperties.getProperty("storePassword").orEmpty()
            keyAlias = keystoreProperties.getProperty("keyAlias").orEmpty()
            keyPassword = keystoreProperties.getProperty("keyPassword").orEmpty()
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

tasks.matching { task ->
    task.name.contains("Release")
}.configureEach {
    doFirst {
        validateReleaseSigning()
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
