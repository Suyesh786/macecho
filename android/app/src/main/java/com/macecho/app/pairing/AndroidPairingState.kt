package com.macecho.app.pairing

/**
 * AndroidPairingState.kt — Phase 12.2
 *
 * Android-side pairing state machine states.
 *
 * Transitions (in order):
 *   UNPAIRED → SCANNING → CONNECTING → CONNECTED →
 *   EXCHANGING_KEYS → VERIFYING → SECURE_CHANNEL_READY
 *
 * Any state can transition to ERROR.
 * ERROR always transitions back to UNPAIRED on retry.
 *
 * Must NOT contain business logic — pure state definition.
 */
enum class AndroidPairingState {
    /** Initial state. No pairing attempt in progress. */
    UNPAIRED,

    /** Camera is open. Waiting for the user to scan a QR code. */
    SCANNING,

    /** QR decoded and validated. WebSocket connection to backend is opening. */
    CONNECTING,

    /** WebSocket connected. PAIRING_JOIN_ACK received. Waiting for Mac. */
    CONNECTED,

    /** Both devices connected to backend. Exchanging ephemeral public keys. */
    EXCHANGING_KEYS,

    /** Keys exchanged. Verifying fingerprints to confirm matching shared secret. */
    VERIFYING,

    /**
     * Fingerprints matched. Temporary encrypted channel established.
     * Phase 12.3 will use this state to begin trust establishment.
     * No permanent pairing has occurred yet.
     */
    SECURE_CHANNEL_READY,

    /** A recoverable error occurred. User can retry. */
    ERROR,
}
