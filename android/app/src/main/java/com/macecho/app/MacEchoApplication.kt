package com.macecho.app

import android.app.Application

/**
 * MacEchoApplication — Phase 4
 *
 * Application entry point. Exists to establish the application class in the
 * Android manifest so that future phases have a documented place to add
 * application-level initialization.
 *
 * Phase 4 intentionally performs no initialization here beyond the super call.
 *
 * Future phases must not add initialization to this class without a
 * corresponding documented phase authorizing it. Each feature initializes
 * its own dependencies in the phase that introduces it.
 *
 * Do NOT add:
 *   - Logging setup        → belongs to the phase that introduces diagnostics
 *   - Dependency injection → belongs to the phase that introduces DI (if any)
 *   - Networking           → Phase 7
 *   - Cryptography         → Phase 8
 *   - Analytics            → not currently in scope
 *   - Background workers   → Phase 16
 */
class MacEchoApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        // Intentionally empty. See class documentation above.
    }
}
