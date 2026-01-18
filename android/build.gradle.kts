plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after Android/Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Namespace must match the 'package' in your AndroidManifest.xml
    namespace = "com.example.ghost_signal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // FIX 1: Enable Core Library Desugaring (allows new Java APIs on old Androids)
        isCoreLibraryDesugaringEnabled = true

        // Standard for modern Flutter/Android (AGP 8.0+) is Java 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Unique ID for the Play Store (must match the namespace usually)
        applicationId = "com.example.ghost_signal"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with debug keys for testing. 
            // TODO: Replace with your real upload keystore before publishing.
            signingConfig = signingConfigs.getByName("debug")
            
            // Recommended: Enable code shrinking for release builds
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FIX 2: Add the Desugar Library dependency (Update version if needed)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
