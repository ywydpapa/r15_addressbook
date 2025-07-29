plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    // Add Firebase dependencies as needed
    implementation("com.google.firebase:firebase-analytics")
    // implementation("com.google.firebase:firebase-auth") // 예시
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

android {
    namespace = "kr.swcore.r15_addressbook"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // 플러그인이 요구하는 NDK 버전

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }


    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            keyAlias = "coredjk-001"
            keyPassword = "Core2025%%"
            storeFile = file("E:/pondProject/r15_addressbook/my-release-key.jks")
            storePassword = "Core2025%%"
        }
    }

    defaultConfig {
        applicationId = "kr.swcore.r15_addressbook"
        minSdk = 23          // ← 21에서 23으로 변경!
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = true
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
