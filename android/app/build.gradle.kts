plugins {
    id("com.android.application")
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

    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    // AppCompat — AppCompatActivity, Fragment support
    implementation("androidx.appcompat:appcompat:1.7.0")

    // Material Components — theme and UI widgets
    implementation("com.google.android.material:material:1.12.0")

    // ConstraintLayout — flexible screen layouts
    implementation("androidx.constraintlayout:constraintlayout:2.2.1")

    // OkHttp — WebSocket transport client (Phase 7)
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Kotlin Coroutines — SharedFlow, Dispatchers (Phase 7)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    // JUnit 4 — local JVM unit tests for crypto primitives (Phase 8)
    testImplementation("junit:junit:4.13.2")
}
