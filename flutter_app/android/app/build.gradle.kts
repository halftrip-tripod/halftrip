import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tourism.travelmvp.travel_support_mvp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tourism.travelmvp.travel_support_mvp"
        // Google Maps 키 — android/local.properties(GOOGLE_MAP_API_KEY=...)에서 읽음. 커밋 금지 영역.
        val localProperties = Properties()
        rootProject.file("local.properties").let { f ->
            if (f.exists()) f.inputStream().use { localProperties.load(it) }
        }
        manifestPlaceholders["GOOGLE_MAP_API_KEY"] =
            localProperties.getProperty("GOOGLE_MAP_API_KEY") ?: ""
        // 소셜 로그인 키 — local.properties에서 읽음(커밋 금지). 미설정이면 빈 값(앱에서 안내만 노출).
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] =
            localProperties.getProperty("KAKAO_NATIVE_APP_KEY") ?: ""
        manifestPlaceholders["NAVER_CLIENT_ID"] =
            localProperties.getProperty("NAVER_CLIENT_ID") ?: ""
        manifestPlaceholders["NAVER_CLIENT_SECRET"] =
            localProperties.getProperty("NAVER_CLIENT_SECRET") ?: ""
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
