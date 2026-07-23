package com.macecho.app.storage

// Phase 9 — Local Trust Database (Encrypted Local Storage)
//
// TrustStore provides encrypted persistence for trusted device metadata per
// 04_SECURITY_MODEL.md §Local Trust Database and Architecture Decision 18.
//
// This is NOT the Android Keystore (that is KeystoreManager.kt).
// The Security Model explicitly separates:
//   - Private keys          → Android Keystore (KeystoreManager.kt)
//   - Trust metadata        → Encrypted local storage (this file)
//
// Trust metadata stored per entry (04_SECURITY_MODEL.md §Local Trust Database):
//   • Trusted Device Identifier
//   • Trusted Public Key (X25519 + Ed25519)
//   • Pairing Timestamp
//   • Trust Status
//   • Device Metadata (name, type)
//
// Encryption: Trust data is serialized as Java Properties, encrypted with a
// dedicated AES-256-GCM wrapping key stored in Android Keystore, and written
// to internal storage as a binary envelope.
//
// Must NOT contain:
//   - Pairing logic          → Phase 12 (TrustStore is populated by Phase 12)
//   - Authentication logic   → Phase 13
//   - Transport              → Phase 7
//   - Private key material   → KeystoreManager.kt
//   - Business logic of any kind
//
// Starts empty. Phase 12 (pairing) will call addOrUpdate() to populate it.
//
// File stored in: context.filesDir / "macecho_trust.enc"
// Format: [12-byte GCM nonce][4-byte ciphertext length][ciphertext]
//         where ciphertext decrypts to a UTF-8 Java Properties document

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.StringReader
import java.io.StringWriter
import java.security.KeyStore
import java.security.SecureRandom
import java.util.Base64
import java.util.Properties
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

// ---------------------------------------------------------------------------
// TrustStatus
// ---------------------------------------------------------------------------

/**
 * Represents the current trust status of a paired device.
 *
 * [TRUSTED] — The device has completed pairing and is recognized as a trusted peer.
 * [REVOKED] — Trust has been explicitly removed (unpairing, key change, or manual revocation).
 */
enum class TrustStatus { TRUSTED, REVOKED }

// ---------------------------------------------------------------------------
// TrustEntry — one record in the local trust database
// ---------------------------------------------------------------------------

/**
 * A single entry in the local trust database.
 *
 * Represents one trusted (or previously trusted) remote device. Populated
 * by Phase 12 (pairing) and validated by Phase 13 (authentication).
 *
 * Per 04_SECURITY_MODEL.md §Local Trust Database:
 *   - Never stores the other device's private key.
 *   - The backend has no authority to modify this record.
 *   - Only the local application may update trust records after successful
 *     security validation.
 *
 * @property trustedDeviceId         The peer's cryptographically random device ID.
 * @property trustedX25519PublicKeyBytes  Peer's X.509-encoded X25519 public key.
 * @property trustedEd25519PublicKeyBytes Peer's X.509-encoded Ed25519 public key.
 * @property pairingTimestampMs      Unix epoch ms when pairing completed.
 * @property trustStatus             Current trust status.
 * @property deviceName              Human-readable peer device name.
 * @property deviceType              Peer platform string (e.g. "MACOS").
 */
data class TrustEntry(
    val trustedDeviceId: String,
    val trustedX25519PublicKeyBytes: ByteArray,
    val trustedEd25519PublicKeyBytes: ByteArray,
    val pairingTimestampMs: Long,
    val trustStatus: TrustStatus,
    val deviceName: String,
    val deviceType: String,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is TrustEntry) return false
        return trustedDeviceId == other.trustedDeviceId &&
            trustedX25519PublicKeyBytes.contentEquals(other.trustedX25519PublicKeyBytes) &&
            trustedEd25519PublicKeyBytes.contentEquals(other.trustedEd25519PublicKeyBytes) &&
            pairingTimestampMs == other.pairingTimestampMs &&
            trustStatus == other.trustStatus &&
            deviceName == other.deviceName &&
            deviceType == other.deviceType
    }

    override fun hashCode(): Int {
        var h = trustedDeviceId.hashCode()
        h = 31 * h + trustedX25519PublicKeyBytes.contentHashCode()
        h = 31 * h + trustedEd25519PublicKeyBytes.contentHashCode()
        h = 31 * h + pairingTimestampMs.hashCode()
        h = 31 * h + trustStatus.hashCode()
        h = 31 * h + deviceName.hashCode()
        h = 31 * h + deviceType.hashCode()
        return h
    }
}

// ---------------------------------------------------------------------------
// TrustStore
// ---------------------------------------------------------------------------

/**
 * Encrypted local storage for trusted device metadata.
 *
 * Architecture Decision 18: "Android stores trusted device metadata in
 * encrypted local storage." This is a separate store from the Android
 * Keystore used for private keys.
 *
 * Operations are synchronous. In production, callers should dispatch to a
 * background thread (e.g. Dispatchers.IO). Threading is not the concern of
 * this storage layer.
 *
 * @param context Android [Context] for internal file access.
 */
class TrustStore(private val context: Context) {

    private companion object {
        const val ANDROID_KEYSTORE_PROVIDER = "AndroidKeyStore"
        const val TRUST_KEY_ALIAS = "com.macecho.trust.wrapping"
        const val TRUST_FILE_NAME = "macecho_trust.enc"
        const val GCM_NONCE_BYTES = 12
        const val GCM_TAG_BITS = 128

        // Properties keys
        const val PROP_IDS = "entry.ids"
        const val PROP_X25519 = "x25519"
        const val PROP_ED25519 = "ed25519"
        const val PROP_TIMESTAMP = "timestamp"
        const val PROP_STATUS = "status"
        const val PROP_NAME = "name"
        const val PROP_TYPE = "type"
    }

    // CSPRNG — sole source of all random material (nonce generation)
    private val secureRandom = SecureRandom()

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /**
     * Adds or updates a trust entry.
     *
     * If an entry with [TrustEntry.trustedDeviceId] already exists, it is
     * replaced. Called by Phase 12 (pairing) after a successful pairing flow.
     */
    fun addOrUpdate(entry: TrustEntry) {
        val entries = loadEntries().toMutableMap()
        entries[entry.trustedDeviceId] = entry
        saveEntries(entries)
    }

    /**
     * Returns the trust entry for [deviceId], or null if not found.
     *
     * Called by Phase 13 (authentication) to verify an incoming connection.
     */
    fun get(deviceId: String): TrustEntry? = loadEntries()[deviceId]

    /**
     * Returns all trust entries in the store.
     *
     * Order is not guaranteed. The list may be empty if no devices have
     * been paired or all entries have been removed.
     */
    fun getAll(): List<TrustEntry> = loadEntries().values.toList()

    /**
     * Returns `true` if a trust entry exists for [deviceId].
     */
    fun contains(deviceId: String): Boolean = loadEntries().containsKey(deviceId)

    /**
     * Removes the trust entry for [deviceId].
     *
     * Safe to call when [deviceId] is not present (idempotent).
     * Called by Phase 12 (unpairing flow).
     */
    fun remove(deviceId: String) {
        val entries = loadEntries().toMutableMap()
        if (entries.remove(deviceId) != null) {
            saveEntries(entries)
        }
    }

    /**
     * Removes all trust entries. The trust store file is overwritten with
     * an empty encrypted store (not deleted).
     *
     * Used by application reset flows.
     */
    fun clear() {
        saveEntries(emptyMap())
    }

    /**
     * Returns the number of trust entries currently stored.
     */
    fun count(): Int = loadEntries().size

    // -----------------------------------------------------------------------
    // Internal serialization helpers (internal visibility for unit tests)
    // -----------------------------------------------------------------------

    /** Serializes [entries] to a Java Properties document (UTF-8 string bytes). */
    internal fun buildPropertiesBytes(entries: Map<String, TrustEntry>): ByteArray {
        val props = Properties()
        props[PROP_IDS] = entries.keys.joinToString(",")
        for ((id, entry) in entries) {
            fun key(field: String) = "entry.$id.$field"
            props[key(PROP_X25519)] = Base64.getEncoder().encodeToString(entry.trustedX25519PublicKeyBytes)
            props[key(PROP_ED25519)] = Base64.getEncoder().encodeToString(entry.trustedEd25519PublicKeyBytes)
            props[key(PROP_TIMESTAMP)] = entry.pairingTimestampMs.toString()
            props[key(PROP_STATUS)] = entry.trustStatus.name
            props[key(PROP_NAME)] = entry.deviceName
            props[key(PROP_TYPE)] = entry.deviceType
        }
        val sw = StringWriter()
        props.store(sw, null /* no header comment */)
        return sw.toString().toByteArray(Charsets.UTF_8)
    }

    /** Parses a Java Properties document back into trust entries. */
    internal fun parsePropertiesBytes(propsBytes: ByteArray): Map<String, TrustEntry> {
        val props = Properties().apply {
            load(StringReader(String(propsBytes, Charsets.UTF_8)))
        }
        val idsStr = props.getProperty(PROP_IDS) ?: return emptyMap()
        if (idsStr.isBlank()) return emptyMap()
        val ids = idsStr.split(",").map { it.trim() }.filter { it.isNotEmpty() }
        return ids.associateWith { id ->
            fun prop(field: String) = props.getProperty("entry.$id.$field")
                ?: error("Missing property entry.$id.$field")
            TrustEntry(
                trustedDeviceId = id,
                trustedX25519PublicKeyBytes = Base64.getDecoder().decode(prop(PROP_X25519)),
                trustedEd25519PublicKeyBytes = Base64.getDecoder().decode(prop(PROP_ED25519)),
                pairingTimestampMs = prop(PROP_TIMESTAMP).toLong(),
                trustStatus = TrustStatus.valueOf(prop(PROP_STATUS)),
                deviceName = prop(PROP_NAME),
                deviceType = prop(PROP_TYPE),
            )
        }
    }

    // -----------------------------------------------------------------------
    // Private implementation
    // -----------------------------------------------------------------------

    private fun trustFile(): File = File(context.filesDir, TRUST_FILE_NAME)

    private fun loadEntries(): Map<String, TrustEntry> {
        val file = trustFile()
        if (!file.exists()) return emptyMap()
        return runCatching {
            val key = getOrCreateTrustKey()
            val plaintext = decryptEnvelope(file.readBytes(), key)
            parsePropertiesBytes(plaintext)
        }.getOrDefault(emptyMap())
    }

    private fun saveEntries(entries: Map<String, TrustEntry>) {
        val key = getOrCreateTrustKey()
        val plaintext = buildPropertiesBytes(entries)
        val encrypted = encryptEnvelope(plaintext, key)
        trustFile().writeBytes(encrypted)
    }

    /**
     * Returns the existing AES trust wrapping key from Android Keystore, or
     * creates a new AES-256-GCM key in the Keystore (hardware-backed where available).
     *
     * This key is separate from the identity wrapping key in [KeystoreManager].
     * Per Architecture Decision 18: "Separating metadata into encrypted local
     * storage was preferred, since metadata does not require hardware-backed
     * key storage and benefits from simpler access patterns."
     */
    private fun getOrCreateTrustKey(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE_PROVIDER).apply { load(null) }
        if (ks.containsAlias(TRUST_KEY_ALIAS)) {
            return (ks.getEntry(TRUST_KEY_ALIAS, null) as KeyStore.SecretKeyEntry).secretKey
        }
        val kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE_PROVIDER)
        kg.init(
            KeyGenParameterSpec.Builder(
                TRUST_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return kg.generateKey()
    }

    // Encrypted envelope format: [12-byte nonce][4-byte ciphertext length][ciphertext]
    private fun encryptEnvelope(plaintext: ByteArray, key: SecretKey): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val nonce = cipher.iv
        val ciphertext = cipher.doFinal(plaintext)
        val baos = ByteArrayOutputStream()
        DataOutputStream(baos).use { dos ->
            dos.write(nonce)
            dos.writeInt(ciphertext.size)
            dos.write(ciphertext)
        }
        return baos.toByteArray()
    }

    private fun decryptEnvelope(data: ByteArray, key: SecretKey): ByteArray {
        DataInputStream(ByteArrayInputStream(data)).use { dis ->
            val nonce = ByteArray(GCM_NONCE_BYTES).also { dis.readFully(it) }
            val ciphertext = ByteArray(dis.readInt()).also { dis.readFully(it) }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, nonce))
            return cipher.doFinal(ciphertext)
        }
    }
}
