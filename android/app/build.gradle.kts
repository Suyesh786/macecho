plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.macecho.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.macecho.app"
        minSdk = 29
        targetSdk = 37
        versionCode = 1
        versionName = "0.0.0"
    }
}
