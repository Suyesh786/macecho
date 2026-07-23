package com.macecho.app.session

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import okhttp3.WebSocket

/**
 * AppSessionManager.kt — Connection Lifecycle Fix
 *
 * Long-lived owner of the ONE active MacEcho session after pairing succeeds.
 *
 * Problem this file solves:
 *   Previously, PairingSessionClient.cleanupSession() closed the WebSocket
 *   unconditionally whenever a session ended — including the success path,
 *   since fragment teardown (PairingScannerFragment.onDestroyView calling
 *   pairingClient.destroy()) triggered the same cleanup as an explicit
 *   cancel. The pairing UI was, in effect, the owner of the connection.
 *
 * Fix:
 *   AppSessionManager becomes the single long-lived owner of the paired
 *   connection. PairingSessionClient still performs the entire handshake
 *   exactly as before (no duplicated logic); the only change is that on
 *   SECURE_CHANNEL_READY it hands its already-open WebSocket to
 *   AppSessionManager instead of that connection being tied to the
 *   fragment's lifecycle.
 *
 * This file does NOT:
 *   - Implement authentication (already complete, per project context).
 *   - Implement reconnection.
 *   - Implement Unpair.
 *   - Modify protocol packets, cryptography, or the pairing handshake itself.
 *
 * There is always at most one active session. Calling [adopt] again replaces
 * the previous session (matching the existing "only one paired device"
 * design of MacEcho Version 1).
 *
 * Object (process-wide singleton) rather than an injected instance, matching
 * the existing project's lack of a DI framework (see MacEchoApplication.kt:
 * "Dependency injection → belongs to the phase that introduces DI (if any)").
 */
object AppSessionManager {

    /**
     * Everything the rest of the app needs to know about the current
     * session, independent of any particular screen's lifecycle.
     */
    data class ActiveSession(
        /**
         * The already-connected transport handed over by
         * [com.macecho.app.pairing.PairingSessionClient] after a successful
         * handshake. AppSessionManager becomes its owner — it will not be
         * closed just because the pairing screen was destroyed.
         */
        val webSocket: WebSocket,
        val pairedDeviceId: String,
        val pairedDeviceName: String,
        val pairedDeviceType: String,
        val establishedAtMillis: Long,
    )

    /** Reasons the application-level session may end. A UI screen being
     * destroyed is never one of them. */
    enum class SessionTerminationReason {
        APPLICATION_QUIT,
        UNPAIRED,
        FATAL_PROTOCOL_FAILURE,
        FATAL_NETWORK_FAILURE,
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    @Volatile
    var activeSession: ActiveSession? = null
        private set

    /**
     * `true` once a session has been adopted. Home screens and the
     * "Pair New Device" action consult this instead of re-deriving pairing
     * state from a UI fragment.
     */
    val isPaired: Boolean
        get() = activeSession != null

    /** Display name of the currently paired device, or `null` if unpaired. */
    val pairedDeviceName: String?
        get() = activeSession?.pairedDeviceName
        
    private val _trustRevokedEvents = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val trustRevokedEvents: SharedFlow<Unit> = _trustRevokedEvents

    // -------------------------------------------------------------------------
    // Adoption (called once, by the pairing screen, on success)
    // -------------------------------------------------------------------------

    /**
     * Adopts an already-established connection as the application's one
     * long-lived session. Call this exactly once, at the moment
     * [com.macecho.app.pairing.PairingSessionClient] reports
     * `AndroidPairingState.SECURE_CHANNEL_READY`.
     *
     * This does NOT open a new connection and does NOT repeat any part of
     * the handshake — [webSocket] is the same OkHttp [WebSocket] instance
     * the pairing client already connected and used.
     *
     * If a previous session exists, it is replaced (there is always exactly
     * one active session per the Version 1 one-Android/one-Mac design).
     */
    @Synchronized
    fun adopt(
        webSocket: WebSocket,
        pairedDeviceId: String,
        pairedDeviceName: String,
        pairedDeviceType: String,
    ) {
        activeSession = ActiveSession(
            webSocket = webSocket,
            pairedDeviceId = pairedDeviceId,
            pairedDeviceName = pairedDeviceName,
            pairedDeviceType = pairedDeviceType,
            establishedAtMillis = System.currentTimeMillis(),
        )
    }

    // -------------------------------------------------------------------------
    // Termination (NOT triggered by UI screens being destroyed)
    // -------------------------------------------------------------------------

    /**
     * Ends the current session. Intended call sites: application
     * termination, a future Unpair feature, or a fatal protocol/network
     * failure — never a fragment's `onDestroyView`.
     */
    @Synchronized
    fun terminate(reason: SessionTerminationReason) {
        val session = activeSession ?: return
        session.webSocket.close(1000, reason.name)
        activeSession = null
    }

    /**
     * Emits an event indicating that the peer has revoked trust.
     * UIs can observe [trustRevokedEvents] to show an alert and refresh.
     */
    fun emitTrustRevokedEvent() {
        _trustRevokedEvents.tryEmit(Unit)
    }
}
