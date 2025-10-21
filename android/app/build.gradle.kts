plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pro.speedy"
    compileSdk = flutter.compileSdkVersion

    // Set NDK version explicitly to match installed NDK
    ndkVersion = "27.3.13750724"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID updated to production package
        applicationId = "com.pro.speedy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Create a release signing config from android/key.properties if present
        val keystorePropertiesFile = rootProject.file("android/key.properties")
        if (keystorePropertiesFile.exists()) {
            val keystoreProperties = java.util.Properties()
            keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
            create("release") {
                val storePath = keystoreProperties.getProperty("storeFile")
                val resolvedStore = if (storePath == null) rootProject.file("android/keystore.jks") else if (java.io.File(storePath).isAbsolute) file(storePath) else rootProject.file("android/$storePath")
                storeFile = resolvedStore
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        } else {
            // fallback will be configured below in buildTypes
        }
    }

    buildTypes {
        release {
            // Use the release signing config if created, otherwise fall back to a local keystore
            val keystorePropertiesFile = rootProject.file("android/key.properties")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (rootProject.file("android/keystore.jks").exists()) {
                signingConfig = signingConfigs.getByName("debug") // keep debug as a placeholder
            }
            // Lint configuration: don't abort build on lint errors for release builds in CI
            // Use setter to avoid unknown property on decorated BuildType
            setMinifyEnabled(false)
            // For AGP 7+, configure lint options via lint block
            lint {
                isAbortOnError = false
            }
        }
    }
}

flutter {
    source = "../.."
}
