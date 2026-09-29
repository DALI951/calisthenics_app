plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// Release signing. Read from android/key.properties when present.
//
// WHY THIS MATTERS: signing releases with the *debug* key meant every CI run
// produced a differently-signed APK, and Android REFUSES to install an update
// over an app signed with a different key ("App not installed"). One stable
// keystore is the whole reason the in-app updater can work at all.
// key.properties and *.jks are gitignored; CI reconstructs key.properties from
// repository secrets (see .github/workflows/build-apk.yml).
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun secret(name: String, fallback: String? = null): String? =
    (keystoreProperties.getProperty(name) ?: System.getenv(name) ?: fallback)
        ?.takeIf { it.isNotBlank() }

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

    signingConfigs {
        create("release") {
            val storePath = secret("CALISTHENICS_STORE_FILE")
            if (!storePath.isNullOrBlank()) {
                storeFile = rootProject.file(storePath)
                storePassword = secret("CALISTHENICS_STORE_PASSWORD")
                keyAlias = secret("CALISTHENICS_KEY_ALIAS")
                keyPassword = secret("CALISTHENICS_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Use the dedicated release keystore when it is configured. Falling
            // back to the debug key is ONLY for a throwaway local build — it
            // produces an APK that cannot be installed over any other build.
            signingConfig = if (secret("CALISTHENICS_STORE_FILE") != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: no release keystore configured, signing with the " +
                        "debug key. This APK cannot be installed over another one."
                )
                signingConfigs.getByName("debug")
            }
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