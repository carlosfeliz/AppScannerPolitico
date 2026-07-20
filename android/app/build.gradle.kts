plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.capturas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
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
