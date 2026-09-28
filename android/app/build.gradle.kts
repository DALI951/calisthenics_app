plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// google-services is applied ONLY when google-services.json exists (real Firebase project).
// Emulator-first development and CI build without it because Firebase is initialized
// programmatically from --dart-define options. See docs/firebase-setup.md.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.dali951.calisthenics_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dali951.calisthenics_app"
        // Firebase SDKs require API 23+; 24 keeps us comfortably current.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Personal release: signed with debug keys so the APK installs on Dali's
            // own phones. A dedicated signing keystore is a documented release task
            // (docs/release-checklist.md) — do NOT ship to an app store with this.
            signingConfig = signingConfigs.getByName("debug")
        }
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