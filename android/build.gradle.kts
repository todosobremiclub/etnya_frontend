// Top-level Gradle settings shared by all modules

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // 👇 Fix crítico: fuerza versiones de AndroidX compatibles con Flutter + AGP 8.7
    // Este bloque es lo que evita el crash al tocar un TextField en Android 14/15
    configurations.all {
        resolutionStrategy {
            // core-ktx con soporte para Stylus Handwriting API
            force("androidx.core:core-ktx:1.13.1")

            // core base
            force("androidx.core:core:1.13.1")

            // browser compatible para webview/plugins
            force("androidx.browser:browser:1.7.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}