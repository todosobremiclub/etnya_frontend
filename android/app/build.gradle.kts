import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

/**
 * Lee android/key.properties (debe estar en: android/key.properties)
 */
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

require(keystorePropertiesFile.exists()) {
    "No se encontró android/key.properties. Debe existir en: ${keystorePropertiesFile.absolutePath}"
}

FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }

android {
    namespace = "com.etnya.pilates"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.etnya.pilates"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 30
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            // En key.properties debe decir: storeFile=app/my-release-key.jks
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}

