pluginManagement {
    // 1. dynamic Flutter SDK Path Resolution
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }
        val path = properties.getProperty("flutter.sdk")
        require(path != null) { "flutter.sdk not set in local.properties" }
        path
    }

    // 2. Include the Flutter Gradle Tooling
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // This plugin handles loading Flutter plugins from pubspec.yaml
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // Android Gradle Plugin (AGP) - Version 8.3.2 is stable and supports Java 17
    id("com.android.application") version "8.3.2" apply false
    
    // Kotlin Android Plugin - Version 1.9.24 is highly compatible with current Flutter
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

include(":app")
