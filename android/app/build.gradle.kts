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
    compileSdk = 35

    defaultConfig {
        applicationId = "com.afzal.fauridoc"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
