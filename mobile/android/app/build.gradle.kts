import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing (EAR-4B, PD-052/055/056/057)
//
// The release identity lives OUTSIDE this repository, under the CEO's control:
//   TINDAK_SIGNING_PROPERTIES  path to a properties file holding only
//                              storeFile and keyAlias (no password)
//   TINDAK_SIGNING_PASSWORD    the keystore password, for one terminal session,
//                              entered through tools/signing/Enter-SigningSession.ps1
//
// Nothing here has a default. A release build without all three pieces FAILS;
// it never falls back to the debug key, which is how the CEO Alpha APK ended up
// debug-signed. Debug builds are untouched.
// ---------------------------------------------------------------------------
val releaseSigningPropertiesPath: String? = System.getenv("TINDAK_SIGNING_PROPERTIES")
val releaseSigningPassword: String? = System.getenv("TINDAK_SIGNING_PASSWORD")
val releaseSigningProperties = Properties().apply {
    val path = releaseSigningPropertiesPath
    if (!path.isNullOrBlank()) {
        val source = file(path)
        if (source.isFile) FileInputStream(source).use { load(it) }
    }
}
val releaseStoreFile = releaseSigningProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }?.let { file(it) }
val releaseKeyAlias: String? = releaseSigningProperties.getProperty("keyAlias")?.takeIf { it.isNotBlank() }
val releaseSigningReady =
    releaseStoreFile?.isFile == true && releaseKeyAlias != null && !releaseSigningPassword.isNullOrEmpty()

android {
    namespace = "my.tindak.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (M7b): it uses java.time to
        // schedule, which older Android versions do not ship.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "my.tindak.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = releaseStoreFile
                storeType = "pkcs12"
                storePassword = releaseSigningPassword
                keyAlias = releaseKeyAlias
                // PKCS12 keystores use a single password for store and key.
                keyPassword = releaseSigningPassword
            }
        }
    }

    buildTypes {
        release {
            // The approved release identity, or nothing. Never the debug key.
            signingConfig = if (releaseSigningReady) signingConfigs.getByName("release") else null
        }
    }
}

// Fail closed: refuse to build any release artifact without the release identity.
gradle.taskGraph.whenReady {
    val releaseArtifactRequested = allTasks.any { task ->
        task.project == project &&
            Regex("^(assemble|bundle|package|sign)[A-Za-z]*Release$").matches(task.name)
    }
    if (releaseArtifactRequested && !releaseSigningReady) {
        throw GradleException(
            "TINDAK release signing is not configured, so no release build will be produced " +
                "(it will never fall back to the debug key). " +
                "Run tools/signing/Enter-SigningSession.ps1 in this terminal first. " +
                "properties_set=${!releaseSigningPropertiesPath.isNullOrBlank()} " +
                "store_file_found=${releaseStoreFile?.isFile == true} " +
                "alias_set=${releaseKeyAlias != null} " +
                "password_set=${!releaseSigningPassword.isNullOrEmpty()}"
        )
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
