package com.macecho.app.pairing

import com.macecho.app.crypto.CryptoManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import org.json.JSONObject
import java.security.KeyPair
import java.util.concurrent.TimeUnit

/**
 * PairingSessionClient.kt — Phase 12.2
 *
 * Android-side pairing protocol state machine.
 *
 * Drives the full handshake after QR decode:
 *   CONNECTING  → opens WebSocket to token.backendUrl
 *   CONNECTED   → sends PAIRING_JOIN, receives PAIRING_JOIN_ACK
 *   EXCHANGING_KEYS → on PAIRING_READY from backend: sends ephemeral X25519 public key
 *                     receives Mac's public key; derives shared secret
 *   VERIFYING   → computes SHA-256 fingerprint (first 8 bytes), sends PAIRING_FINGERPRINT
 *                 receives Mac's fingerprint; compares
 *   SECURE_CHANNEL_READY → fingerprints match; emits state; ephemeral private key destroyed
 *
 * Symmetric cancellation:
 *   - If the backend sends PAIRING_CANCELLED or PAIRING_TIMEOUT → reset to UNPAIRED
 *   - If [cancel] is called → sends PAIRING_CANCELLED, disconnects, resets
 *
 * Must NOT contain:
 *   - Keychain / Keystore writes   → Phase 12.3
 *   - Trust establishment          → Phase 12.3
 *   - Permanent device pairing     → Phase 12.3
 *   - Long-term key overwrite      → prohibited
 *   - Business logic beyond pairing handshake
 *
 * @param deviceId  Stable Android device UUID (used as senderId in messages).
 */
class PairingSessionClient(
    private val deviceId: String,
    private val keystoreManager: com.macecho.app.storage.KeystoreManager,
    private val trustStore: com.macecho.app.storage.TrustStore
) {

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    private val _state = MutableStateFlow(AndroidPairingState.UNPAIRED)
    val state: StateFlow<AndroidPairingState> = _state

    private val _errorMessage = MutableStateFlow<String?>(null)
    /** Human-readable error message, set when state == ERROR. */
    val errorMessage: StateFlow<String?> = _errorMessage

    // -------------------------------------------------------------------------
    // Internal resources
    // -------------------------------------------------------------------------

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .build()

    private var webSocket: WebSocket? = null
    private var currentSessionId: String? = null

    // Ephemeral X25519 key pair — generated fresh per pairing attempt.
    // Private key is nulled immediately after shared secret derivation.
    private var ephemeralKeyPair: KeyPair? = null

    // Derived session key — held temporarily until fingerprint verified.
    // Nulled after verification (pass/fail).
    private var derivedKeyBytes: ByteArray? = null

    // Track received public keys to detect duplicate / out-of-order messages
    private var macPublicKeyReceived = false
    private var androidKeyHasBeenSent = false
    private var androidIdentityReceived = false

    // Fingerprint tracking
    private var ourFingerprint: String? = null
    private var macFingerprintReceived: String? = null
    private var macIdentityReceived: JSONObject? = null

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /**
     * Begins the pairing handshake using the validated [token].
     * Any previous session is cancelled first.
     */
    fun start(token: PairingToken) {
        cancel("new_session_started")
        currentSessionId = token.sessionId
        _state.value = AndroidPairingState.CONNECTING
        _errorMessage.value = null
        ephemeralKeyPair = CryptoManager.generateX25519KeyPair()
        openWebSocket(token)
    }

    /**
     * Cancels the current pairing session.
     * Sends PAIRING_CANCELLED to the backend, resets state to UNPAIRED.
     * Safe to call when not in an active session.
     */
    fun cancel(reason: String = "user_cancelled") {
        val sid = currentSessionId ?: return
        sendPairingMessage(buildJson("PAIRING_CANCELLED") {
            put("reason", reason)
        })
        cleanupSession()
        _state.value = AndroidPairingState.UNPAIRED
    }

    /**
     * Releases all resources. Call from Fragment.onDestroyView().
     *
     * Connection-ownership fix: if pairing already succeeded, the socket has
     * already been handed to [com.macecho.app.session.AppSessionManager] and
     * [webSocket] is already null here — [cancel] becomes a harmless no-op
     * on the (already-cleared) session, and does NOT flip state back to
     * UNPAIRED, since a real, still-connected session exists and this
     * fragment tearing down must not appear to unpair it.
     */
    fun destroy() {
        if (_state.value != AndroidPairingState.SECURE_CHANNEL_READY) {
            cancel("destroyed")
        }
        scope.cancel()
        okHttpClient.dispatcher.executorService.shutdown()
    }

    // -------------------------------------------------------------------------
    // WebSocket
    // -------------------------------------------------------------------------

    private fun openWebSocket(token: PairingToken) {
        val request = Request.Builder().url(token.backendUrl).build()
        webSocket = okHttpClient.newWebSocket(request, createListener(token.sessionId))
    }

    private fun createListener(sessionId: String) = object : WebSocketListener() {

        override fun onOpen(webSocket: WebSocket, response: Response) {
            if (_state.value == AndroidPairingState.CONNECTING) {
                _state.value = AndroidPairingState.CONNECTED
                // Register as Android for this session
                sendPairingMessage(buildJson("PAIRING_JOIN") {
                    put("senderId", deviceId)
                })
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            handleMessage(text)
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            // Binary frames are not part of the pairing protocol — ignore
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            setError("Connection failed: ${t.message ?: "unknown error"}")
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (_state.value != AndroidPairingState.SECURE_CHANNEL_READY &&
                _state.value != AndroidPairingState.UNPAIRED
            ) {
                setError("Connection closed unexpectedly.")
            }
        }
    }

    // -------------------------------------------------------------------------
    // Message handling
    // -------------------------------------------------------------------------

    private fun handleMessage(raw: String) {
        val obj = try { JSONObject(raw) } catch (_: Exception) { return }
        val type = obj.optString("type") ?: return
        val sid = obj.optString("sessionId")
        if (sid != currentSessionId) return // ignore messages for other sessions

        when (type) {
            "PAIRING_JOIN_ACK" -> {
                // Backend confirmed join; if Mac is present, exchange keys
                val macConnected = obj.optBoolean("macConnected", false)
                if (macConnected) {
                    _state.value = AndroidPairingState.EXCHANGING_KEYS
                    sendIdentity()
                }
            }

            "PAIRING_READY" -> {
                // Theoretically Mac sends this, but Android relies on macConnected in JOIN_ACK
                _state.value = AndroidPairingState.EXCHANGING_KEYS
                sendIdentity()
            }

            "PAIRING_IDENTITY" -> {
                println("PairingTrace: RECEIVE PAIRING_IDENTITY")
                macIdentityReceived = obj
            }

            "PAIRING_PUBLIC_KEY" -> {
                println("PairingTrace: RECEIVE PAIRING_PUBLIC_KEY")
                // Mac's ephemeral X25519 public key (base64 X.509)
                val b64Key = obj.optString("publicKey") ?: return
                if (macPublicKeyReceived) return // ignore duplicates
                macPublicKeyReceived = true
                handleMacPublicKey(b64Key)
            }

            "PAIRING_FINGERPRINT" -> {
                println("PairingTrace: RECEIVE PAIRING_FINGERPRINT")
                // Mac's verification fingerprint (hex, 8 bytes of SHA-256)
                val fp = obj.optString("fingerprint") ?: return
                macFingerprintReceived = fp
                tryVerifyFingerprints()
            }

            "PAIRING_CANCELLED" -> {
                val reason = obj.optString("reason", "remote_cancelled")
                setError(humanReadableCancelReason(reason))
            }

            "PAIRING_TIMEOUT" -> {
                setError("The pairing session expired. Please generate a new QR code.")
            }
            
            "TRUST_REVOKED" -> {
                if (sid != null) {
                    trustStore.remove(sid)
                }
                com.macecho.app.session.AppSessionManager.terminate(
                    com.macecho.app.session.AppSessionManager.SessionTerminationReason.UNPAIRED
                )
                com.macecho.app.session.AppSessionManager.emitTrustRevokedEvent()
            }
        }
    }

    // -------------------------------------------------------------------------
    // Key exchange
    // -------------------------------------------------------------------------

    private fun sendIdentity() {
        if (androidIdentityReceived) return
        androidIdentityReceived = true
        
        val deviceName = android.os.Build.MODEL ?: "Android Device"
        val identity = keystoreManager.generateIdentity(deviceName, "Android")

        val ed25519B64 = android.util.Base64.encodeToString(identity.ed25519PublicKeyBytes, android.util.Base64.NO_WRAP)
        val x25519B64 = android.util.Base64.encodeToString(identity.x25519PublicKeyBytes, android.util.Base64.NO_WRAP)
        
        println("PairingTrace: SEND PAIRING_IDENTITY")
        sendPairingMessage(buildJson("PAIRING_IDENTITY") {
            put("senderId", deviceId)
            put("deviceName", identity.deviceName)
            put("deviceType", identity.deviceType)
            put("ed25519PublicKey", ed25519B64)
            put("x25519PublicKey", x25519B64)
        })
        
        sendEphemeralPublicKey()
    }

    private fun sendEphemeralPublicKey() {
        if (androidKeyHasBeenSent) return
        androidKeyHasBeenSent = true
        val keyPair = ephemeralKeyPair ?: run { setError("No ephemeral key pair."); return }
        
        val rawKeyBytes = CryptoManager.getRawX25519PublicKey(keyPair)
        val pubKeyB64 = android.util.Base64.encodeToString(
            rawKeyBytes, android.util.Base64.NO_WRAP
        )
        println("PairingTrace: SEND PAIRING_PUBLIC_KEY")
        sendPairingMessage(buildJson("PAIRING_PUBLIC_KEY") {
            put("senderId", deviceId)
            put("publicKey", pubKeyB64)
        })
    }

    private fun handleMacPublicKey(base64Key: String) {
        val keyPair = ephemeralKeyPair ?: run { setError("No ephemeral key pair."); return }
        try {
            val macPubKeyBytes = android.util.Base64.decode(base64Key, android.util.Base64.NO_WRAP)
            val sharedSecretBytes = CryptoManager.deriveX25519SharedSecret(
                keyPair.private, macPubKeyBytes
            )
            // Derive session key via HKDF-SHA256
            derivedKeyBytes = CryptoManager.hkdfSha256(
                inputKeyMaterial = sharedSecretBytes,
                salt = null,
                info = "macecho-pairing-v1".toByteArray(),
                outputLength = 32,
            )
            // Zero the raw shared secret bytes immediately
            sharedSecretBytes.fill(0)
            // Null the ephemeral private key — it has served its purpose
            ephemeralKeyPair = null

            // Compute and send our fingerprint
            val keyBytes = derivedKeyBytes ?: return
            val digest = CryptoManager.sha256(keyBytes)
            val fingerprint = digest.take(8).joinToString("") { "%02x".format(it.toInt() and 0xFF) }
            ourFingerprint = fingerprint

            _state.value = AndroidPairingState.VERIFYING
            println("PairingTrace: SEND PAIRING_FINGERPRINT ($fingerprint)")
            sendPairingMessage(buildJson("PAIRING_FINGERPRINT") {
                put("senderId", deviceId)
                put("fingerprint", fingerprint)
            })

            // If Mac's fingerprint already arrived, verify now
            tryVerifyFingerprints()
        } catch (e: Exception) {
            setError("Key exchange failed: ${e.message ?: "unknown error"}")
        }
    }

    // -------------------------------------------------------------------------
    // Fingerprint verification
    // -------------------------------------------------------------------------

    private fun tryVerifyFingerprints() {
        println("PairingTrace: tryVerifyFingerprints (ours=$ourFingerprint, theirs=$macFingerprintReceived)")
        val ours = ourFingerprint ?: return      // not computed yet
        val theirs = macFingerprintReceived ?: return  // not received yet

        // Clear key material regardless of outcome
        derivedKeyBytes?.fill(0)
        derivedKeyBytes = null

        println("PairingTrace: VALIDATE FINGERPRINT (ours=$ours, theirs=$theirs)")
        if (ours == theirs) {
            val identity = macIdentityReceived
            if (identity != null) {
                try {
                    val senderId = identity.optString("senderId")
                    val deviceName = identity.optString("deviceName", "Mac")
                    val deviceType = identity.optString("deviceType", "Mac")
                    val ed25519B64 = identity.optString("ed25519PublicKey")
                    val x25519B64 = identity.optString("x25519PublicKey")
                    
                    if (ed25519B64.isNotEmpty() && x25519B64.isNotEmpty() && senderId.isNotEmpty()) {
                        val ed25519Bytes = android.util.Base64.decode(ed25519B64, android.util.Base64.NO_WRAP)
                        val x25519Bytes = android.util.Base64.decode(x25519B64, android.util.Base64.NO_WRAP)
                        
                        println("PairingTrace: FINGERPRINT_MATCH. Saving TrustEntry.")
                        val entry = com.macecho.app.storage.TrustEntry(
                            trustedDeviceId = senderId,
                            trustedX25519PublicKeyBytes = x25519Bytes,
                            trustedEd25519PublicKeyBytes = ed25519Bytes,
                            pairingTimestampMs = System.currentTimeMillis(),
                            trustStatus = com.macecho.app.storage.TrustStatus.TRUSTED,
                            deviceName = deviceName,
                            deviceType = deviceType
                        )
                        trustStore.addOrUpdate(entry)
                        println("PairingTrace: TrustStore updated successfully.")
                    } else {
                        println("PairingTrace: FINGERPRINT_MATCH but Identity missing required fields.")
                    }
                } catch (e: Exception) {
                    println("PairingTrace: Failed to save TrustEntry: ${e.message}")
                }
            } else {
                println("PairingTrace: FINGERPRINT_MATCH but Identity missing.")
            }
            println("PairingTrace: SECURE_CHANNEL_READY")

            // Connection-ownership fix: hand the already-open WebSocket to
            // AppSessionManager BEFORE marking success, so it becomes the
            // long-lived owner instead of this client (whose cleanup would
            // otherwise close it once the fragment is destroyed). This does
            // not open a second connection or repeat any handshake step —
            // it is the same `webSocket` instance used throughout.
            val socket = webSocket
            if (socket != null) {
                com.macecho.app.session.AppSessionManager.adopt(
                    webSocket = socket,
                    pairedDeviceId = identity?.optString("senderId") ?: "",
                    pairedDeviceName = identity?.optString("deviceName") ?: "Mac",
                    pairedDeviceType = identity?.optString("deviceType") ?: "MACOS",
                )
                // Prevent cleanupSession() (called by destroy()/cancel() on
                // later teardown) from closing a socket AppSessionManager
                // now owns.
                webSocket = null
            }

            _state.value = AndroidPairingState.SECURE_CHANNEL_READY
        } else {
            println("PairingTrace: FINGERPRINT_MISMATCH")
            setError("Fingerprint mismatch — possible interference. Please try again.")
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun sendPairingMessage(json: JSONObject) {
        webSocket?.send(json.toString())
    }

    private fun buildJson(type: String, block: JSONObject.() -> Unit = {}): JSONObject =
        JSONObject().apply {
            put("type", type)
            put("sessionId", currentSessionId)
            put("timestamp", System.currentTimeMillis())
            block()
        }

    private fun setError(message: String) {
        cleanupSession()
        _errorMessage.value = message
        _state.value = AndroidPairingState.ERROR
    }

    private fun cleanupSession() {
        webSocket?.close(1000, "pairing_cleanup")
        webSocket = null
        currentSessionId = null
        ephemeralKeyPair = null
        derivedKeyBytes?.fill(0)
        derivedKeyBytes = null
        macPublicKeyReceived = false
        androidKeyHasBeenSent = false
        ourFingerprint = null
        macFingerprintReceived = null
    }

    private fun humanReadableCancelReason(reason: String): String = when (reason) {
        "mac_disconnected" -> "Your Mac disconnected. Please try again."
        "expired" -> "The pairing session expired. Please generate a new QR code."
        "replaced" -> "A new pairing session was started on your Mac."
        else -> "Pairing was cancelled. Please try again."
    }
}
