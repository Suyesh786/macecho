package com.macecho.app.pairing

/**
 * PairingToken.kt — Phase 12.2
 *
 * Decoded and validated payload from the pairing QR code.
 *
 * This mirrors PairingSessionToken on macOS, but as a pure Kotlin data class
 * with no Android imports. It is produced by QrValidator after successful
 * validation and passed to PairingSessionClient.
 *
 * Must NOT contain:
 *   - Network calls         → PairingSessionClient
 *   - Android imports       → none needed here
 *   - Business logic        → QrValidator
 */
data class PairingToken(
    /** Temporary, single-use session UUID from the QR code. */
    val sessionId: String,

    /** MacEcho protocol version. Must equal 1 in Phase 12.2. */
    val protocolVersion: Int,

    /** WebSocket URL to connect to. Must use ws:// or wss:// scheme. */
    val backendUrl: String,

    /** Unix epoch milliseconds when this token expires. */
    val expiresAt: Long,
)
