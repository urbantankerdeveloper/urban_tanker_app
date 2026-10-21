plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.urbantanker.app"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.urbantanker.app"
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0"
    }
}

flutter {
    source = "../.."
}
