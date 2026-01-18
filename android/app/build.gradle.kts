plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied to the app module
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ghost_signal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Modern Android development (AGP 8.0+) defaults to Java 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        // Enable strict mode for better null safety interoperability with Java
        freeCompilerArgs += listOf("-Xjsr305=strict")
    }

    defaultConfig {
        applicationId = "com.example.ghost_signal"
        
        // Dynamic versioning handled by the Flutter plugin from pubspec.yaml
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Resource optimization: Only keep English resources (removes unused library languages)
        resConfigs("en")
    }

    buildTypes {
        release {
            // R8 Configuration: Enables code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // TODO: Replace 'debug' with a real release signing config for Play Store upload
            signingConfig = signingConfigs.getByName("debug")
        }
        
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Improve build reliability by handling duplicate files from dependencies
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add specific Android dependencies here if needed (e.g., Multidex)
    // implementation("androidx.multidex:multidex:2.0.1")
}
