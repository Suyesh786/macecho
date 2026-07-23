package com.macecho.app.storage

// Phase 9 — Secure Key Storage
//
// KeystoreManager provides Android Keystore-backed protection for the device's
// long-term cryptographic identity (X25519 key exchange pair + Ed25519 signing
// pair + cryptographically random device identifier).
//
// Responsibilities (this file only):
//   ✓ Generate device identity (key pairs + device ID)
//   ✓ Persist identity with private keys encrypted by a Keystore AES-256 wrapping key
//   ✓ Load identity (public data only — private keys never returned)
//   ✓ Delete identity (identity file + Keystore wrapping key)
//
// Must NOT contain:
//   - Authentication logic       → Phase 13
//   - Pairing logic              → Phase 12
//   - Transport                  → Phase 7
//   - Session management         → Phase 13
//   - TrustStore management      → TrustStore.kt
//   - Business logic of any kind
//
// Private Key Protection Strategy (Architecture Decision 18):
//   Android Keystore does not natively support X25519/Ed25519 key generation
//   inside the Keystore provider. The standard compensating control is:
//
//     1. Generate an AES-256-GCM wrapping key INSIDE the Android Keystore
//        (hardware-backed on devices with a Hardware Security Module).
//     2. Generate X25519 and Ed25519 key pairs via standard JCA (Phase 8 CryptoManager).
//     3. Encrypt the private key PKCS#8 bytes with the Keystore-backed AES key.
//     4. Write only the encrypted bytes to internal storage.
//
//   This ensures private key material NEVER exists unencrypted on disk.
//   The Keystore wrapping key is non-exportable and hardware-backed when available.
//
// Device Identifier Rules (04_SECURITY_MODEL.md §Device Identifier):
//   Generated as a Version-4 (random) UUID using SecureRandom — the CSPRNG.
//   NOT derived from: MAC address, IMEI, Android ID, Apple hardware ID,
//   email, phone number, or IP address.
//
// Secure Memory:
//   Private key bytes (PKCS#8 ByteArrays) are decrypted only transiently
//   inside this class for internal operations. They are never returned from
//   any public or internal function. They go out of scope immediately after use.
//   No private key bytes are logged.
//
// File stored in: context.filesDir / "macecho_identity.enc"
// Format: length-prefixed binary (DataOutputStream), private keys AES-GCM encrypted.

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.macecho.app.crypto.CryptoManager
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.security.KeyFactory
import java.security.KeyStore
import java.security.SecureRandom
import java.security.spec.PKCS8EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

// ---------------------------------------------------------------------------
// DeviceIdentity — public-facing view of the device's cryptographic identity
// ---------------------------------------------------------------------------

/**
 * The public, non-sensitive portion of the device's cryptographic identity.
 *
 * Private keys are NEVER included in this class. They remain encrypted inside
 * the Keystore-protected identity file and are only decrypted transiently
 * within [KeystoreManager] for internal cryptographic operations.
 *
 * Per 04_SECURITY_MODEL.md §Device Identity, the identity consists of:
 *   Device Identifier, Device Name, Device Type, Public Key (X25519 + Ed25519).
 *
 * @property deviceId        Version-4 UUID, cryptographically random (SecureRandom).
 * @property deviceName      Human-readable label (e.g. "Suyesh's Android").
 * @property deviceType      Platform string (e.g. "ANDROID").
 * @property x25519PublicKeyBytes  X.509/SubjectPublicKeyInfo encoded X25519 public key.
 * @property ed25519PublicKeyBytes X.509/SubjectPublicKeyInfo encoded Ed25519 public key.
 */
data class DeviceIdentity(
    val deviceId: String,
    val deviceName: String,
    val deviceType: String,
    val x25519PublicKeyBytes: ByteArray,
    val ed25519PublicKeyBytes: ByteArray,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is DeviceIdentity) return false
        return deviceId == other.deviceId &&
            deviceName == other.deviceName &&
            deviceType == other.deviceType &&
            x25519PublicKeyBytes.contentEquals(other.x25519PublicKeyBytes) &&
            ed25519PublicKeyBytes.contentEquals(other.ed25519PublicKeyBytes)
    }

    override fun hashCode(): Int {
        var h = deviceId.hashCode()
        h = 31 * h + deviceName.hashCode()
        h = 31 * h + deviceType.hashCode()
        h = 31 * h + x25519PublicKeyBytes.contentHashCode()
        h = 31 * h + ed25519PublicKeyBytes.contentHashCode()
        return h
    }
}

// ---------------------------------------------------------------------------
// KeystoreManager
// ---------------------------------------------------------------------------

/**
 * Manages the device's long-term cryptographic identity using the Android Keystore.
 *
 * Identity lifecycle:
 *   1. [generateIdentity] — creates key pairs + device ID, stores securely.
 *      If an identity already exists, returns the existing identity (keys
 *      generated only once, reused on subsequent calls).
 *   2. [loadIdentity] — returns public identity data. Returns null when absent.
 *   3. [deleteIdentity] — removes identity file and Keystore wrapping key.
 *      Produces a clean-slate state. Safe to call when no identity exists.
 *   4. [hasIdentity] — non-destructive existence check.
 *
 * @param context Android [Context] used to access internal files directory.
 */
class KeystoreManager(private val context: Context) {

    private companion object {
        const val ANDROID_KEYSTORE_PROVIDER = "AndroidKeyStore"
        const val WRAPPING_KEY_ALIAS = "com.macecho.identity.wrapping"
        const val IDENTITY_FILE_NAME = "macecho_identity.enc"
        const val GCM_NONCE_BYTES = 12
        const val GCM_TAG_BITS = 128

        // Serialized binary format version tag (future-proofing)
        const val FORMAT_VERSION: Byte = 1
    }

    // CSPRNG — sole source of all random material in this class
    private val secureRandom = SecureRandom()

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /**
     * Returns `true` if a stored identity exists in the identity file.
     * Does not access the Android Keystore.
     */
    fun hasIdentity(): Boolean = identityFile().exists()

    /**
     * Returns the stored device identity if it already exists, otherwise
     * generates a new one, persists it, and returns it.
     *
     * Keys are generated only when absent. Calling this multiple times
     * returns the same identity without regenerating key material.
     *
     * @param deviceName Human-readable label (e.g. "Suyesh's Android").
     * @param deviceType Platform string (e.g. "ANDROID").
     * @return DeviceIdentity (public data only — private keys never returned).
     */
    fun generateIdentity(
        deviceName: String,
        deviceType: String,
    ): DeviceIdentity {
        loadIdentity()?.let { return it }
        return createAndPersistIdentity(deviceName, deviceType)
    }

    /**
     * Loads and returns the stored device identity.
     *
     * Only public data (device ID, public keys) is returned. Private keys
     * are not decrypted during this call — they remain encrypted in the
     * identity file.
     *
     * @return DeviceIdentity or null if no identity has been generated.
     */
    fun loadIdentity(): DeviceIdentity? {
        val file = identityFile()
        if (!file.exists()) return null
        return runCatching {
            deserializePublicData(file.readBytes())
        }.getOrNull()
    }

    /**
     * Deletes the stored identity and removes the Android Keystore wrapping key.
     *
     * After deletion: [hasIdentity] returns false. Calling [generateIdentity]
     * produces a completely new identity (new device ID, new key pairs).
     * The previous trust relationship with paired devices is permanently lost.
     *
     * Safe to call when no identity exists (idempotent).
     */
    fun deleteIdentity() {
        identityFile().delete()
        runCatching {
            val ks = KeyStore.getInstance(ANDROID_KEYSTORE_PROVIDER).apply { load(null) }
            if (ks.containsAlias(WRAPPING_KEY_ALIAS)) {
                ks.deleteEntry(WRAPPING_KEY_ALIAS)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Internal operations — reserved for Phase 13 (authentication)
    // Not yet called from any application flow.
    // -----------------------------------------------------------------------

    /**
     * Signs [data] using the stored Ed25519 private key.
     *
     * The private key is decrypted transiently inside this function and is
     * never returned. The decrypted byte array goes out of scope at function end.
     *
     * Reserved for Phase 13 (authentication). Not yet wired to any flow.
     *
     * @return 64-byte Ed25519 signature, or null if no identity is stored.
     */
    internal fun sign(data: ByteArray): ByteArray? {
        val file = identityFile()
        if (!file.exists()) return null
        return runCatching {
            val wrappingKey = getOrCreateWrappingKey()
            val stored = deserializeAll(file.readBytes(), wrappingKey)
            val privateKey = KeyFactory.getInstance("Ed25519")
                .generatePrivate(PKCS8EncodedKeySpec(stored.ed25519PrivateKeyBytes))
            // Decrypted ed25519PrivateKeyBytes go out of scope after this call
            CryptoManager.signEd25519(privateKey, data)
        }.getOrNull()
    }

    /**
     * Derives an X25519 shared secret with a peer's public key.
     *
     * The X25519 private key is decrypted transiently inside this function
     * and never returned. The decrypted byte array goes out of scope at
     * function end. Pass the result immediately to HKDF and release the reference.
     *
     * Reserved for Phase 13 (authentication). Not yet wired to any flow.
     *
     * @param peerPublicKeyBytes Peer's X25519 public key in X.509 encoding.
     * @return 32-byte raw shared secret, or null if no identity is stored.
     */
    internal fun deriveSharedSecret(peerPublicKeyBytes: ByteArray): ByteArray? {
        val file = identityFile()
        if (!file.exists()) return null
        return runCatching {
            val wrappingKey = getOrCreateWrappingKey()
            val stored = deserializeAll(file.readBytes(), wrappingKey)
            val privateKey = KeyFactory.getInstance("X25519")
                .generatePrivate(PKCS8EncodedKeySpec(stored.x25519PrivateKeyBytes))
            // Decrypted x25519PrivateKeyBytes go out of scope after this call
            CryptoManager.deriveX25519SharedSecret(privateKey, peerPublicKeyBytes)
        }.getOrNull()
    }

    // -----------------------------------------------------------------------
    // Private implementation
    // -----------------------------------------------------------------------

    private fun identityFile(): File = File(context.filesDir, IDENTITY_FILE_NAME)

    private fun createAndPersistIdentity(
        deviceName: String,
        deviceType: String,
    ): DeviceIdentity {
        // Generate device identifier — CSPRNG-derived, not from hardware/personal data
        val deviceId = generateSecureDeviceId()

        // Generate cryptographic key pairs via Phase 8 CryptoManager (standard JCA)
        val x25519Pair = CryptoManager.generateX25519KeyPair()
        val ed25519Pair = CryptoManager.generateEd25519KeyPair()

        val wrappingKey = getOrCreateWrappingKey()

        // Encrypt private keys with Keystore-backed AES key before writing to disk.
        // Private key bytes (PKCS#8 encoded) are encrypted and immediately discarded
        // from the local scope — they are not stored in any field.
        val encX25519 = encryptBlob(x25519Pair.private.encoded, wrappingKey)
        val encEd25519 = encryptBlob(ed25519Pair.private.encoded, wrappingKey)

        val identity = DeviceIdentity(
            deviceId = deviceId,
            deviceName = deviceName,
            deviceType = deviceType,
            x25519PublicKeyBytes = x25519Pair.public.encoded,
            ed25519PublicKeyBytes = ed25519Pair.public.encoded,
        )

        identityFile().writeBytes(serialize(identity, encX25519, encEd25519))
        return identity
    }

    /**
     * Generates a Version-4 UUID from [SecureRandom].
     *
     * NOT derived from: MAC address, IMEI, Android ID, hardware identifier,
     * email, phone number, or IP address — per 04_SECURITY_MODEL.md §Device Identifier.
     */
    private fun generateSecureDeviceId(): String {
        val b = ByteArray(16)
        secureRandom.nextBytes(b)
        // RFC 4122 §4.4: set version bits to 0100 (v4) and variant bits to 10xx
        b[6] = (b[6].toInt() and 0x0F or 0x40).toByte()
        b[8] = (b[8].toInt() and 0x3F or 0x80).toByte()
        return buildString {
            b.forEachIndexed { i, byte ->
                if (i == 4 || i == 6 || i == 8 || i == 10) append('-')
                append("%02x".format(byte.toInt() and 0xFF))
            }
        }
    }

    /**
     * Returns the existing Keystore wrapping key or creates a new AES-256-GCM key
     * inside the Android Keystore (hardware-backed on devices with HSM).
     */
    private fun getOrCreateWrappingKey(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE_PROVIDER).apply { load(null) }
        if (ks.containsAlias(WRAPPING_KEY_ALIAS)) {
            return (ks.getEntry(WRAPPING_KEY_ALIAS, null) as KeyStore.SecretKeyEntry).secretKey
        }
        val kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE_PROVIDER)
        kg.init(
            KeyGenParameterSpec.Builder(
                WRAPPING_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return kg.generateKey()
    }

    private data class EncryptedBlob(val nonce: ByteArray, val ciphertext: ByteArray)

    private fun encryptBlob(plaintext: ByteArray, key: SecretKey): EncryptedBlob {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val nonce = cipher.iv
        return EncryptedBlob(nonce = nonce, ciphertext = cipher.doFinal(plaintext))
    }

    private fun decryptBlob(blob: EncryptedBlob, key: SecretKey): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, blob.nonce))
        return cipher.doFinal(blob.ciphertext)
    }

    // -----------------------------------------------------------------------
    // Binary serialization
    //
    // Format (written by DataOutputStream, little-endian int lengths):
    //
    //   [1 byte]  FORMAT_VERSION
    //   [4 bytes] deviceId length    [N bytes] deviceId UTF-8
    //   [4 bytes] deviceName length  [N bytes] deviceName UTF-8
    //   [4 bytes] deviceType length  [N bytes] deviceType UTF-8
    //
    //   [GCM_NONCE_BYTES] X25519 private key GCM nonce
    //   [4 bytes] X25519 encrypted private key ciphertext length
    //   [N bytes] X25519 encrypted private key ciphertext (PKCS#8, AES-256-GCM encrypted)
    //   [4 bytes] X25519 public key length
    //   [N bytes] X25519 public key bytes (X.509 encoded)
    //
    //   [GCM_NONCE_BYTES] Ed25519 private key GCM nonce
    //   [4 bytes] Ed25519 encrypted private key ciphertext length
    //   [N bytes] Ed25519 encrypted private key ciphertext (PKCS#8, AES-256-GCM encrypted)
    //   [4 bytes] Ed25519 public key length
    //   [N bytes] Ed25519 public key bytes (X.509 encoded)
    // -----------------------------------------------------------------------

    private fun serialize(
        identity: DeviceIdentity,
        encX25519: EncryptedBlob,
        encEd25519: EncryptedBlob,
    ): ByteArray {
        val baos = ByteArrayOutputStream()
        DataOutputStream(baos).use { dos ->
            dos.write(FORMAT_VERSION.toInt())
            fun writeBytes(b: ByteArray) { dos.writeInt(b.size); dos.write(b) }
            fun writeString(s: String) = writeBytes(s.toByteArray(Charsets.UTF_8))
            writeString(identity.deviceId)
            writeString(identity.deviceName)
            writeString(identity.deviceType)
            dos.write(encX25519.nonce)
            writeBytes(encX25519.ciphertext)
            writeBytes(identity.x25519PublicKeyBytes)
            dos.write(encEd25519.nonce)
            writeBytes(encEd25519.ciphertext)
            writeBytes(identity.ed25519PublicKeyBytes)
        }
        return baos.toByteArray()
    }

    /**
     * Reads only public fields. Does NOT decrypt private key blobs.
     * Private keys remain encrypted on disk.
     */
    private fun deserializePublicData(bytes: ByteArray): DeviceIdentity {
        DataInputStream(ByteArrayInputStream(bytes)).use { dis ->
            dis.read() // FORMAT_VERSION (consumed but not used in v1)
            fun readBytes(): ByteArray = ByteArray(dis.readInt()).also { dis.readFully(it) }
            fun readString() = String(readBytes(), Charsets.UTF_8)
            fun skipBlob() { // skip nonce + encrypted bytes
                dis.readFully(ByteArray(GCM_NONCE_BYTES))
                dis.readFully(ByteArray(dis.readInt()))
            }
            val deviceId = readString()
            val deviceName = readString()
            val deviceType = readString()
            skipBlob() // skip X25519 encrypted private key
            val x25519PublicKeyBytes = readBytes()
            skipBlob() // skip Ed25519 encrypted private key
            val ed25519PublicKeyBytes = readBytes()
            return DeviceIdentity(deviceId, deviceName, deviceType, x25519PublicKeyBytes, ed25519PublicKeyBytes)
        }
    }

    /** Decrypts all fields including private keys — used only by internal signing/key-agreement. */
    private data class StoredIdentityAll(
        val identity: DeviceIdentity,
        val x25519PrivateKeyBytes: ByteArray, // PKCS#8 — decrypted transiently, never cached
        val ed25519PrivateKeyBytes: ByteArray, // PKCS#8 — decrypted transiently, never cached
    )

    private fun deserializeAll(bytes: ByteArray, wrappingKey: SecretKey): StoredIdentityAll {
        DataInputStream(ByteArrayInputStream(bytes)).use { dis ->
            dis.read() // FORMAT_VERSION
            fun readBytes(): ByteArray = ByteArray(dis.readInt()).also { dis.readFully(it) }
            fun readString() = String(readBytes(), Charsets.UTF_8)
            fun readBlob(): EncryptedBlob {
                val nonce = ByteArray(GCM_NONCE_BYTES).also { dis.readFully(it) }
                return EncryptedBlob(nonce, readBytes())
            }
            val deviceId = readString()
            val deviceName = readString()
            val deviceType = readString()
            val encX25519 = readBlob()
            val x25519PublicBytes = readBytes()
            val encEd25519 = readBlob()
            val ed25519PublicBytes = readBytes()
            return StoredIdentityAll(
                identity = DeviceIdentity(deviceId, deviceName, deviceType, x25519PublicBytes, ed25519PublicBytes),
                x25519PrivateKeyBytes = decryptBlob(encX25519, wrappingKey),
                ed25519PrivateKeyBytes = decryptBlob(encEd25519, wrappingKey),
            )
        }
    }
}
