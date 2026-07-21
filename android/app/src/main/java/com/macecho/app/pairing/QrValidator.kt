package com.macecho.app.pairing

import org.json.JSONException
import org.json.JSONObject
import java.util.UUID

/**
 * QrValidator.kt — Phase 12.2
 *
 * Validates the JSON payload decoded from a pairing QR code.
 *
 * Pure validation — no network, no Android imports, no side-effects.
 * Returns a sealed result so callers can display user-friendly errors.
 *
 * Rejection rules (in order):
 *   1. Malformed JSON
 *   2. Missing required fields (sessionId, protocolVersion, backendUrl, expiresAt)
 *   3. Invalid UUID format for sessionId
 *   4. Wrong protocol version (must be 1)
 *   5. Invalid URL scheme — only ws:// and wss:// are accepted
 *   6. Expired token (expiresAt ≤ current time)
 *   7. Duplicate scan guard (sessionId already seen this session)
 *
 * Must NOT contain:
 *   - Network calls              → PairingSessionClient
 *   - Android system imports     → none needed
 *   - Business logic beyond validation
 */
object QrValidator {

    // -------------------------------------------------------------------------
    // Result type
    // -------------------------------------------------------------------------

    sealed class Result {
        data class Valid(val token: PairingToken) : Result()
        data class Error(val reason: String) : Result()
    }

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    private const val EXPECTED_PROTOCOL_VERSION = 1
    private val ALLOWED_SCHEMES = setOf("ws", "wss")

    // Duplicate-scan guard — tracks session IDs seen in this process lifetime.
    // Cleared on each fresh PairingScannerFragment open.
    private val seenSessionIds = mutableSetOf<String>()

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /**
     * Validates the raw JSON string from a QR decode.
     * Returns [Result.Valid] with a [PairingToken] if all checks pass.
     * Returns [Result.Error] with a user-readable reason for any failure.
     */
    fun validate(json: String): Result {
        // 1. JSON parse
        val obj: JSONObject = try {
            JSONObject(json)
        } catch (_: JSONException) {
            return Result.Error("QR code is not a valid MacEcho pairing code.")
        }

        // 2. Required fields present
        val sessionId = if (obj.has("sessionId")) obj.getString("sessionId") else null
            ?: return Result.Error("QR code is missing the session ID.")
        val protocolVersion = if (obj.has("protocolVersion")) obj.getInt("protocolVersion")
            else return Result.Error("QR code is missing the protocol version.")
        val backendUrl = if (obj.has("backendUrl")) obj.getString("backendUrl") else null
            ?: return Result.Error("QR code is missing the backend URL.")
        val expiresAt = if (obj.has("expiresAt")) obj.getLong("expiresAt")
            else return Result.Error("QR code is missing the expiry time.")

        // 3. Valid UUID
        try {
            UUID.fromString(sessionId)
        } catch (_: IllegalArgumentException) {
            return Result.Error("QR code contains an invalid session ID.")
        }

        // 4. Protocol version
        if (protocolVersion != EXPECTED_PROTOCOL_VERSION) {
            return Result.Error(
                "Protocol version mismatch (expected $EXPECTED_PROTOCOL_VERSION, got $protocolVersion). " +
                "Please update your MacEcho app."
            )
        }

        // 5. URL scheme — only ws:// and wss:// accepted
        val scheme = backendUrl.substringBefore("://").lowercase()
        if (scheme !in ALLOWED_SCHEMES) {
            return Result.Error(
                "QR code contains an unsupported URL scheme '$scheme'. " +
                "Only ws:// and wss:// are accepted."
            )
        }

        // 6. Expiry
        val nowMs = System.currentTimeMillis()
        if (expiresAt <= nowMs) {
            return Result.Error(
                "This QR code has expired. Please generate a new one on your Mac."
            )
        }

        // 7. Duplicate scan guard
        if (sessionId in seenSessionIds) {
            return Result.Error(
                "This QR code has already been scanned. Please generate a new one."
            )
        }

        return Result.Valid(
            PairingToken(
                sessionId = sessionId,
                protocolVersion = protocolVersion,
                backendUrl = backendUrl,
                expiresAt = expiresAt,
            )
        )
    }

    /**
     * Registers a session ID as "seen" to prevent duplicate scans.
     * Called by [PairingScannerFragment] immediately after a valid scan.
     */
    fun markSeen(sessionId: String) {
        seenSessionIds.add(sessionId)
    }

    /**
     * Clears the duplicate-scan guard.
     * Call when the user opens a fresh PairingScannerFragment.
     */
    fun clearSeenIds() {
        seenSessionIds.clear()
    }
}
