import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (gitignored). Falling back
// to the debug keystore silently produces an artifact Play rejects, so a real
// release build fails instead; set ALLOW_DEBUG_SIGNED_RELEASE=true only for a
// local smoke test of the release configuration.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val allowDebugSignedRelease =
    (project.findProperty("ALLOW_DEBUG_SIGNED_RELEASE") as String?)?.toBoolean() == true
            || System.getenv("ALLOW_DEBUG_SIGNED_RELEASE")?.toBoolean() == true

android {
    namespace = "com.cosmicguide.cosmic_guide"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.cosmicguide.cosmic_guide"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                if (!allowDebugSignedRelease) {
                    throw GradleException(
                        "No release signing config: android/key.properties is missing. " +
                        "A debug-signed release is rejected by Play and breaks Google " +
                        "Sign-In (different SHA-1). Create the upload keystore and " +
                        "key.properties, or pass -PALLOW_DEBUG_SIGNED_RELEASE=true to " +
                        "build an unpublishable test artifact."
                    )
                }
                logger.warn("WARNING: signing the release build with DEBUG keys — not publishable.")
                signingConfigs.getByName("debug")
            }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
