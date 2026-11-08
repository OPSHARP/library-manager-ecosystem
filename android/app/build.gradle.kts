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

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.librarymanager.owner"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring for Java 8+ API support on older Android versions
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.librarymanager.owner"
        minSdk = 24          // Android 7.0 (Nougat)
        targetSdk = 36       // Android 16
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
            // Enable R8 code shrinking and resource shrinking for smaller APK
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    // Core library desugaring — required for Java 8+ APIs on Android 7/8
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Enforce Google Play Billing Library v9.0.0+ for Google Play policy requirements
    implementation("com.android.billingclient:billing:9.0.0")
}

configurations.all {
    resolutionStrategy {
        force("com.android.billingclient:billing:9.0.0")
        // Play Integrity is the App Check provider used by this app
        // (AndroidProvider.playIntegrity in lib/main.dart) — the deprecated
        // SafetyNet app-check dependency bundled by firebase_app_check is
        // excluded so it can never be referenced or shipped.
        exclude(group = "com.google.firebase", module = "firebase-appcheck-safetynet")
    }
}

flutter {
    source = "../.."
}

// Patch .so ELF alignment to 16KB for Android 16+ (runs after native libs merge)
tasks.matching { it.name.startsWith("merge") && it.name.endsWith("NativeLibs") }.configureEach {
    doLast {
        val scriptFile = rootProject.projectDir.resolve("patch_16kb_alignment.py")
        val allSoFiles = mutableListOf<String>()
        outputs.files.forEach { outDir ->
            fileTree(outDir) { include("**/*.so") }.files.forEach { soFile ->
                allSoFiles.add(soFile.absolutePath)
            }
        }
        if (allSoFiles.isEmpty()) return@doLast
        val result = project.exec {
            commandLine("python", scriptFile.absolutePath, *allSoFiles.toTypedArray())
            isIgnoreExitValue = true
        }
        logger.lifecycle("16KB alignment: ${allSoFiles.size} libs (exit=${result.exitValue})")
    }
}

