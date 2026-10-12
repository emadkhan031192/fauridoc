plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase is optional: the Google Services plugin is applied only when
// google-services.json exists (see SETUP.md). Without it the app runs in
// demo mode and this build needs no Firebase at all.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.afzal.fauridoc"
    // compileSdk 36: required by androidx.browser:browser:1.9.0+ (pulled in
    // via url_launcher etc.). targetSdk stays 35 for now.
    compileSdk = 36

    defaultConfig {
        applicationId = "com.afzal.fauridoc"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Pinned debug keystore (CI): when the FAURIDOC_DEBUG_KEYSTORE_FILE env
    // var points at a keystore, the debug signing config uses it instead of
    // the default ~/.android/debug.keystore. This keeps the SHA-1 stable
    // across CI runs so Google Sign-In keeps working on debug builds.
    // Local builds without the env var are unaffected.
    signingConfigs {
        named("debug") {
            val ksFile = System.getenv("FAURIDOC_DEBUG_KEYSTORE_FILE")
            val ksPass = System.getenv("FAURIDOC_DEBUG_KEYSTORE_PASSWORD")
            val ksAlias = System.getenv("FAURIDOC_DEBUG_KEY_ALIAS")
            if (!ksFile.isNullOrEmpty() && !ksPass.isNullOrEmpty() &&
                !ksAlias.isNullOrEmpty() && file(ksFile).exists()
            ) {
                storeFile = file(ksFile)
                storePassword = ksPass
                keyAlias = ksAlias
                keyPassword = ksPass
            }
        }
    }

    buildTypes {
        debug {
            // Debug builds skip shrinking for speed.
            isMinifyEnabled = false
        }
        release {
            // Debug-signed for now; the user adds their upload keystore
            // when publishing to the Play Store.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            // The Flutter Gradle plugin enables resource shrinking on release
            // by default; it requires code shrinking, which we skip, so turn
            // it off explicitly.
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}
