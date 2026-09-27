plugins {
    id("com.android.application")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // Firebase Google Services plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.binarypulse.amarguard"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.binarypulse.amarguard"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseKeystore = System.getenv("AMARGUARD_RELEASE_KEYSTORE")
    val releaseStorePassword = System.getenv("AMARGUARD_RELEASE_STORE_PASSWORD")
    val releaseKeyAlias = System.getenv("AMARGUARD_RELEASE_KEY_ALIAS")
    val releaseKeyPassword = System.getenv("AMARGUARD_RELEASE_KEY_PASSWORD")

    if (releaseKeystore != null && releaseStorePassword != null &&
        releaseKeyAlias != null && releaseKeyPassword != null
    ) {
        signingConfigs.create("amarguardRelease") {
            storeFile = file(releaseKeystore)
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("amarguardRelease")
                ?: throw GradleException(
                    "Release signing is not configured. Set the AMARGUARD_RELEASE_* environment variables."
                )
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