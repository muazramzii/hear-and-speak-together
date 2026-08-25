import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (Phase 5): reads android/key.properties, which is
// git-ignored (see android/.gitignore) and never committed - see
// docs/release-build.md for how to generate the keystore it points to.
// Falls back to the debug keystore when that file does not exist, so a
// fresh checkout still builds (`flutter run --release`) with no setup.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "my.fyp.hear_speak_together"
    // Higher than Flutter's own default (35 / the bundled NDK) because
    // flutter_tts and several other plugins declare a requirement above it -
    // both are backward compatible, so this is safe for every supported
    // device, not just newer ones.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "my.fyp.hear_speak_together"
        // Flutter's own default (21) is lower than what `record` (23) and
        // `flutter_tts` (24) declare as their minimums - Gradle's manifest
        // merger refuses to build below either rather than risk a runtime
        // crash on APIs those plugins actually use. Android 7.0 (API 24)
        // is a reasonable floor for a 2026 release in any case.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // A real release keystore signs the build when key.properties
            // exists (see docs/release-build.md); otherwise this falls back
            // to the debug keystore so `flutter run --release` still works
            // on a fresh checkout with no signing set up yet. A release APK
            // meant to actually ship must be built with the keystore in
            // place - the debug-signed fallback is a developer convenience,
            // not something to distribute.
            signingConfig =
                if (hasReleaseSigning) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            // Code shrinking (R8/ProGuard) is deliberately left off: several
            // plugins here use reflection (flutter_secure_storage's Keystore
            // access, permission_handler) that needs per-plugin keep rules
            // verified against an actual installed build before it is safe
            // to enable - see docs/release-build.md's "Future: code
            // shrinking" note rather than shipping that unverified.
        }
    }
}

flutter {
    source = "../.."
}
