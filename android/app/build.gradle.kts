plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.example.capturas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // OJO: cambiar este identificador convierte la app en una aplicacion
        // DISTINTA para Android. Quien ya la tenga instalada no recibiria la
        // actualizacion: tendria que desinstalar e instalar de nuevo. Se
        // conserva el valor original a proposito para no romper ese camino.
        // (Solo seria obligatorio cambiarlo para publicar en Google Play, que
        // rechaza los identificadores "com.example.*").
        applicationId = "com.example.capturas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Solo arm64: ML Kit trae tambien x86_64 y armv7 aunque no se usen.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    // Comprime las librerias nativas dentro del APK (por defecto van sin
    // comprimir y el archivo pesa mucho mas para subir/descargar).
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // Dos aplicaciones distintas desde el mismo codigo. Como el identificador
    // de la de pruebas lleva el sufijo ".staging", Android las trata como apps
    // separadas y pueden estar INSTALADAS A LA VEZ en el mismo telefono, con
    // nombres e iconos propios. Asi se prueba contra staging sin arriesgar la
    // app que usan los capturistas en la calle.
    //
    //   produccion: flutter build apk --release --flavor production
    //   pruebas:    flutter build apk --release --flavor staging \
    //                 --dart-define=MAIN_DOMAIN=staging.siselecto.com
    flavorDimensions += "ambiente"

    productFlavors {
        create("production") {
            dimension = "ambiente"
            resValue("string", "app_name", "SISELECT")
        }
        create("staging") {
            dimension = "ambiente"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "SISELECT Pruebas")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
