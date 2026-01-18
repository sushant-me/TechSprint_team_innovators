plugins {
    id("com.android.application")
    id("kotlin-android")
    // Use the latest declarative syntax for the Flutter Gradle Plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ghost_signal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Modern Android development now defaults to Java 17 or 21
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        // Enable context receivers and other modern Kotlin features if needed
        freeCompilerArgs += listOf("-Xjsr305=strict")
    }

    defaultConfig {
        applicationId = "com.example.ghost_signal"
        
        // Use versioning from local.properties/pubspec.yaml automatically
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Optimize for performance: only include necessary resource locales
        resConfigs("en") 
    }

    buildTypes {
        release {
            // Enable code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            signingConfig = signingConfigs.getByName("debug")
        }
        
        getByName("debug") {
            // Faster builds for debug mode
            isMinifyEnabled = false
        }
    }

    // Improve build speed by excluding unnecessary files from the APK
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}
