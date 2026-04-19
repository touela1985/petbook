import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load signing values from local.properties (never committed to git).
// Add these keys to local.properties when you have a release keystore:
//   releaseStoreFile=../petbook-release.keystore
//   releaseStorePassword=YOUR_STORE_PASSWORD
//   releaseKeyAlias=petbook
//   releaseKeyPassword=YOUR_KEY_PASSWORD
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("local.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.example.petbook_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            val storePath = keystoreProperties.getProperty("releaseStoreFile") ?: ""
            if (storePath.isNotEmpty()) {
                storeFile = file(storePath)
                storePassword = keystoreProperties.getProperty("releaseStorePassword") ?: ""
                keyAlias = keystoreProperties.getProperty("releaseKeyAlias") ?: ""
                keyPassword = keystoreProperties.getProperty("releaseKeyPassword") ?: ""
            }
        }
    }

    defaultConfig {
        // TODO: Change applicationId before Play Store submission.
        // See: ANDROID RELEASE PREP — Task Group 4 for safe migration steps.
        applicationId = "com.example.petbook_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.getByName("release")
            // Uses release signing if keystore is configured in local.properties,
            // otherwise falls back to debug signing so flutter run --release still works.
            signingConfig = if (releaseConfig.storeFile != null) releaseConfig
                            else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
