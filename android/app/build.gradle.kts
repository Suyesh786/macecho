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

        // Phase 12.2: Centralized backend URL configuration.
        // Override with MACECHO_BACKEND_URL environment variable, or in
        // local.properties as macecho.backendUrl for per-machine configuration.
        // Default: ws://10.0.2.2:3000/ws targets localhost on Android Emulator.
        // Physical device: set MACECHO_BACKEND_URL=ws://<HOST_LAN_IP>:3000/ws
        val backendUrl = System.getenv("MACECHO_BACKEND_URL")
            ?: (project.findProperty("macecho.backendUrl") as String? ?: "ws://10.0.2.2:3000/ws")
        buildConfigField("String", "BACKEND_URL", "\"$backendUrl\"")
    }

    buildFeatures {
        viewBinding = true
        buildConfig = true     // required for BuildConfig.BACKEND_URL
    }
}

dependencies {
    // AppCompat — AppCompatActivity, Fragment support
    implementation("androidx.appcompat:appcompat:1.7.0")

    // Material Components 3 — theme and UI widgets
    implementation("com.google.android.material:material:1.12.0")

    // ConstraintLayout — flexible screen layouts
    implementation("androidx.constraintlayout:constraintlayout:2.2.1")

    // CoordinatorLayout — required for activity_main BottomNavigationView layout
    implementation("androidx.coordinatorlayout:coordinatorlayout:1.3.0")

    // OkHttp — WebSocket transport client (Phase 7)
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Kotlin Coroutines — SharedFlow, StateFlow, Dispatchers (Phase 7 + 12.2)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    // ── Phase 12.2: CameraX ─────────────────────────────────────────────────
    // Camera capture pipeline — used for QR scanning preview
    implementation("androidx.camera:camera-core:1.4.0")
    implementation("androidx.camera:camera-camera2:1.4.0")
    implementation("androidx.camera:camera-lifecycle:1.4.0")
    // PreviewView widget for camera viewfinder
    implementation("androidx.camera:camera-view:1.4.0")

    // ── Phase 12.2: ML Kit Barcode Scanning ─────────────────────────────────
    // Google's official barcode / QR code scanning library.
    // Approved: Google first-party library.
    implementation("com.google.mlkit:barcode-scanning:17.3.0")

    // JUnit 4 — local JVM unit tests for crypto primitives (Phase 8)
    testImplementation("junit:junit:4.13.2")

    // org.json standalone — real JSONObject for local JVM unit tests
    testImplementation("org.json:json:20240303")
}

