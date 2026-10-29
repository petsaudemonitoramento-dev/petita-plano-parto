plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val institutionalSigning = System.getenv("PETITA_INSTITUTIONAL_SIGNING") == "true"

android {
    namespace = "br.edu.ufcg.petsaude.petita"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Proposed institutional identity; publication requires institutional approval.
        applicationId = "br.edu.ufcg.petsaude.petita"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (institutionalSigning) {
            create("institutional") {
                fun requiredEnv(name: String): String =
                    System.getenv(name)?.takeIf { it.isNotBlank() }
                        ?: error("Required protected signing variable missing: $name")
                storeFile = file(requiredEnv("PETITA_KEYSTORE_PATH"))
                storePassword = requiredEnv("PETITA_STORE_PASSWORD")
                keyAlias = requiredEnv("PETITA_KEY_ALIAS")
                keyPassword = requiredEnv("PETITA_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        debug {
            applicationIdSuffix = ".internal"
            versionNameSuffix = "-internal"
        }
        release {
            // No debug-signing fallback. CI validates a deliberately unsigned binary.
            signingConfig = if (institutionalSigning) signingConfigs.getByName("institutional") else null
            if (!institutionalSigning) {
                applicationIdSuffix = ".releasecheck"
                versionNameSuffix = "-unsigned-test"
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
