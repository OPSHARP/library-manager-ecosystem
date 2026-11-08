import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // Kotlin plugin — version managed in settings.gradle.kts. Declared here so
    // the IDE resolves the `kotlin { compilerOptions { } }` DSL and JvmTarget.
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load keystore properties for signed release builds.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.librarymanager.student"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring — required by flutter_local_notifications
        // and for Java 8+ API support on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.librarymanager.student"
        minSdk = 24
        targetSdk = 36       // Android 16 (Google Play requirement from Aug 2026)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = file(keystoreProperties["storeFile"] as String? ?: "")
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Enable R8 code shrinking and resource shrinking for a smaller APK.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // 16 KB page-size support (Google Play requirement for apps targeting
    // SDK 35+). Keep native libs uncompressed so they stay page-aligned
    // inside the APK/AAB (android:extractNativeLibs=false is the AGP 8
    // default; this makes it explicit).
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring â€” required by flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // mobile_scanner pulls com.google.mlkit:barcode-scanning:17.2.0, whose
    // bundled libs (libbarhopper_v3.so, libimage_processing_util_jni.so) are
    // only 4 KB aligned. 17.3.0 ships 16 KB-aligned native libs â€” required
    // for the 16 KB page-size check (targetSdk 36). Gradle resolves the
    // higher version over the plugin's transitive 17.2.0.
    implementation("com.google.mlkit:barcode-scanning:17.3.0")

    // mobile_scanner also pins CameraX 1.3.3, whose
    // libimage_processing_util_jni.so is only 4 KB aligned. CameraX 1.4.2 is
    // the first stable line whose native libs are 16 KB-aligned (verified by
    // reading the ELF LOAD segment size). Pin the whole 1.4.2 train so
    // core, camera2 and lifecycle resolve consistently.
    implementation("androidx.camera:camera-core:1.4.2")
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
}

configurations.all {
    resolutionStrategy {
        // Attestation is the Play Integrity API — this app activates
        // AndroidProvider.playIntegrity in lib/main.dart. The deprecated
        // SafetyNet app-check artifact bundled by firebase_app_check is
        // excluded so it can never be referenced or shipped. (No SafetyNet
        // reCAPTCHA is used; App Check's Debug provider is used in debug
        // builds, Play Integrity in release.)
        exclude(group = "com.google.firebase", module = "firebase-appcheck-safetynet")
    }
}
