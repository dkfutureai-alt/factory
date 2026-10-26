plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("FACTORYOS_ANDROID_KEYSTORE_PATH")
val releaseKeystorePassword = System.getenv("FACTORYOS_ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("FACTORYOS_ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("FACTORYOS_ANDROID_KEY_PASSWORD")
val requireReleaseSigning = System.getenv("FACTORYOS_REQUIRE_RELEASE_SIGNING") == "true"
val hasReleaseSigning = listOf(
    releaseKeystorePath,
    releaseKeystorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

if (requireReleaseSigning && !hasReleaseSigning) {
    throw GradleException(
        "Production signing is required but FACTORYOS_ANDROID_KEYSTORE_PATH, " +
            "FACTORYOS_ANDROID_KEYSTORE_PASSWORD, FACTORYOS_ANDROID_KEY_ALIAS and " +
            "FACTORYOS_ANDROID_KEY_PASSWORD are not all configured."
    )
}

android {
    namespace = "com.dkappsstudio.factoryos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dkappsstudio.factoryos"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // Unique package ID for an explicit offline QA preview build only.
            // Standard debug and release identities remain unchanged.
            if (System.getenv("FACTORYOS_QA_PREVIEW_BUILD") == "true") {
                applicationIdSuffix = ".qapreview"
            }
        }
        release {
            // CI can compile with the debug key to prove the release project builds.
            // Store publishing must set FACTORYOS_REQUIRE_RELEASE_SIGNING=true,
            // which makes missing production signing secrets a hard failure.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
