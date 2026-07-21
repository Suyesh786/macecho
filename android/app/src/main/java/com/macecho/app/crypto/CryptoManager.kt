package com.macecho.app.crypto

// Phase 8 — Cryptographic Primitives
//
// This object exposes the five mandatory cryptographic operations required
// by Architecture Decision 16 and 04_SECURITY_MODEL.md §End-to-End Encryption:
//
//   1. X25519  — Key exchange (key generation + shared secret derivation)
//   2. Ed25519 — Digital signatures (key generation, sign, verify)
//   3. AES-256-GCM — Symmetric encryption / decryption
//   4. HKDF-SHA256 — Key derivation
//   5. SHA-256 — Hashing
//
// Must NOT contain:
//   - Authentication or session logic   → Phase 13
//   - Pairing logic                     → Phase 12
//   - Packet encryption pipeline        → Phase 10
//   - Android Keystore storage          → Phase 9
//   - Replay protection                 → Protocol phases
//   - WebSocket, transport, or UI code
//   - Business logic of any kind
//
// Cryptographically Secure Randomness:
//   ALL random material (nonces, IVs, ephemeral values) is generated
//   exclusively via SecureRandom — the documented CSPRNG for this platform.
//   Non-cryptographic random sources (Random, Math.random, etc.) are
//   intentionally absent from this file.
//
// Secure Memory Handling:
//   Sensitive temporaries (shared secrets, plaintext key byte arrays, derived
//   keys) are used and immediately discarded — they are not stored as fields.
//   The SecureRandom instance is the only retained field; it holds no
//   sensitive key material. Java's garbage collector provides eventual
//   reclamation; no custom memory wiping is performed (JVM does not
//   guarantee zeroing on collection, and manual zeroing risks JIT reordering).
//
// API Compatibility:
//   - minSdk 29 (Android 10) — all five JCA algorithms available via
//     Conscrypt provider bundled with the Android runtime.
//   - JVM unit tests (host JDK 17+) — all five algorithms available natively.
//   - No third-party crypto libraries are used. Only java.security /
//     javax.crypto standard JCA APIs.
//
// Algorithm parameters (must not be changed without Architecture Decision update):
//   AES key size : 256 bits (32 bytes)
//   GCM nonce   : 96 bits (12 bytes) — NIST SP 800-38D recommended
//   GCM auth tag: 128 bits           — maximum tag length
//   HKDF hash   : SHA-256 (32-byte hash length)

import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.PublicKey
import java.security.SecureRandom
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object CryptoManager {

    // -----------------------------------------------------------------------
    // Internal constants
    // -----------------------------------------------------------------------

    private const val AES_KEY_LENGTH_BYTES = 32   // 256-bit key
    private const val GCM_NONCE_LENGTH_BYTES = 12  // 96-bit nonce — NIST recommended
    private const val GCM_TAG_LENGTH_BITS = 128    // maximum GCM authentication tag
    private const val HMAC_SHA256_OUTPUT_BYTES = 32 // SHA-256 output length for HKDF

    // SecureRandom instance — CSPRNG, the only source of randomness in this module.
    // Holds no key material; safe to retain as a singleton.
    private val secureRandom = SecureRandom()

    // -----------------------------------------------------------------------
    // AES-256-GCM result carrier
    // -----------------------------------------------------------------------

    /**
     * Carries the output of an AES-256-GCM encryption operation.
     *
     * @property nonce      12-byte randomly-generated nonce for this operation.
     *                      Must be unique per (key, message) pair.
     *                      Must be transmitted alongside the ciphertext.
     * @property ciphertext Encrypted bytes. GCM appends the 16-byte
     *                      authentication tag to the ciphertext automatically.
     */
    data class EncryptedData(
        val nonce: ByteArray,
        val ciphertext: ByteArray,
    ) {
        // Custom equals/hashCode because ByteArray uses referential equality
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is EncryptedData) return false
            return nonce.contentEquals(other.nonce) &&
                ciphertext.contentEquals(other.ciphertext)
        }
        override fun hashCode(): Int = 31 * nonce.contentHashCode() + ciphertext.contentHashCode()
    }

    // -----------------------------------------------------------------------
    // 1. X25519 — Key Exchange
    // -----------------------------------------------------------------------

    /**
     * Generates an X25519 Diffie-Hellman key pair.
     *
     * The returned KeyPair's encoded bytes (via [PublicKey.encoded]) use the
     * X.509/SubjectPublicKeyInfo format, which is the required input format
     * for [deriveX25519SharedSecret].
     *
     * @return A freshly generated X25519 KeyPair.
     */
    fun generateX25519KeyPair(): KeyPair {
        val kpg = KeyPairGenerator.getInstance("X25519")
        return kpg.generateKeyPair()
    }

    /**
     * Performs X25519 Diffie-Hellman key agreement to derive a shared secret.
     *
     * Secure Memory: The returned ByteArray is the raw shared secret.
     * Callers must pass it immediately to [hkdfSha256] for key derivation
     * and allow the reference to go out of scope. Do not cache it.
     *
     * @param privateKey         The local device's X25519 private key.
     * @param peerPublicKeyBytes The peer's X25519 public key as raw 32 bytes
     *                           (CryptoKit rawRepresentation) or X.509 encoded.
     * @return The raw 32-byte shared secret.
     */
    fun deriveX25519SharedSecret(
        privateKey: PrivateKey,
        peerPublicKeyBytes: ByteArray,
    ): ByteArray {
        // CryptoKit sends 32 raw bytes. JCA expects 44-byte X.509 SubjectPublicKeyInfo.
        val x509Header = byteArrayOf(
            0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x6e, 0x03, 0x21, 0x00
        )
        val x509Bytes = if (peerPublicKeyBytes.size == 32) {
            x509Header + peerPublicKeyBytes
        } else {
            peerPublicKeyBytes
        }

        val keyFactory = KeyFactory.getInstance("X25519")
        val peerPublicKey: PublicKey = keyFactory.generatePublic(X509EncodedKeySpec(x509Bytes))
        val agreement = KeyAgreement.getInstance("X25519")
        agreement.init(privateKey)
        agreement.doPhase(peerPublicKey, true)
        // generateSecret() returns the raw shared secret; not cached here
        return agreement.generateSecret()
    }

    /**
     * Extracts the raw 32-byte public key from an X25519 KeyPair for transmission to CryptoKit.
     */
    fun getRawX25519PublicKey(keyPair: KeyPair): ByteArray {
        val encoded = keyPair.public.encoded
        return if (encoded.size == 44) encoded.copyOfRange(12, 44) else encoded
    }

    // -----------------------------------------------------------------------
    // 2. Ed25519 — Digital Signatures
    // -----------------------------------------------------------------------

    /**
     * Generates an Ed25519 signing key pair.
     *
     * The public key's encoded bytes (via [PublicKey.encoded]) use the
     * X.509/SubjectPublicKeyInfo format required by [verifyEd25519].
     *
     * @return A freshly generated Ed25519 KeyPair.
     */
    fun generateEd25519KeyPair(): KeyPair {
        val kpg = KeyPairGenerator.getInstance("Ed25519")
        return kpg.generateKeyPair()
    }

    /**
     * Produces an Ed25519 digital signature over [data].
     *
     * @param privateKey The signer's Ed25519 private key.
     * @param data       The data to sign. Not modified.
     * @return A 64-byte Ed25519 signature.
     */
    fun signEd25519(privateKey: PrivateKey, data: ByteArray): ByteArray {
        val sig = Signature.getInstance("Ed25519")
        sig.initSign(privateKey)
        sig.update(data)
        return sig.sign()
    }

    /**
     * Verifies an Ed25519 signature.
     *
     * Returns `false` for any invalid input including wrong key, tampered
     * data, malformed signature, or malformed public key bytes.
     * Never throws for invalid crypto material — all exceptions become `false`.
     *
     * @param publicKeyBytes The signer's Ed25519 public key in
     *                       X.509/SubjectPublicKeyInfo format.
     * @param data           The original signed data.
     * @param signature      The Ed25519 signature to verify.
     * @return `true` if the signature is valid; `false` in all other cases.
     */
    fun verifyEd25519(
        publicKeyBytes: ByteArray,
        data: ByteArray,
        signature: ByteArray,
    ): Boolean {
        return try {
            val keyFactory = KeyFactory.getInstance("Ed25519")
            val publicKey: PublicKey = keyFactory.generatePublic(X509EncodedKeySpec(publicKeyBytes))
            val sig = Signature.getInstance("Ed25519")
            sig.initVerify(publicKey)
            sig.update(data)
            sig.verify(signature)
        } catch (_: Exception) {
            // Any crypto exception — wrong key, tampered data, bad encoding
            false
        }
    }

    // -----------------------------------------------------------------------
    // 3. AES-256-GCM — Symmetric Encryption
    // -----------------------------------------------------------------------

    /**
     * Encrypts [plaintext] using AES-256-GCM.
     *
     * A fresh 12-byte nonce is generated from [SecureRandom] for every call.
     * The nonce must be transmitted alongside the ciphertext and is
     * included in the returned [EncryptedData].
     *
     * Optional Additional Authenticated Data ([aad]) is authenticated but
     * not encrypted. Pass it to [decryptAesGcm] using the same value.
     *
     * Secure Memory: [keyBytes] is used only within this function scope.
     * Callers should allow references to key material to go out of scope
     * immediately after this call.
     *
     * @param keyBytes  A 32-byte (256-bit) AES key.
     * @param plaintext The data to encrypt.
     * @param aad       Optional authenticated additional data. May be null.
     * @return An [EncryptedData] containing the nonce and ciphertext+tag.
     * @throws IllegalArgumentException if [keyBytes] is not 32 bytes.
     */
    fun encryptAesGcm(
        keyBytes: ByteArray,
        plaintext: ByteArray,
        aad: ByteArray? = null,
    ): EncryptedData {
        require(keyBytes.size == AES_KEY_LENGTH_BYTES) {
            "AES key must be exactly $AES_KEY_LENGTH_BYTES bytes (256 bits), got ${keyBytes.size}"
        }

        // Generate a cryptographically random nonce for this operation.
        // SecureRandom is the CSPRNG — no other random source is acceptable.
        val nonce = ByteArray(GCM_NONCE_LENGTH_BYTES)
        secureRandom.nextBytes(nonce)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val keySpec = SecretKeySpec(keyBytes, "AES")
        cipher.init(Cipher.ENCRYPT_MODE, keySpec, GCMParameterSpec(GCM_TAG_LENGTH_BITS, nonce))
        aad?.let { cipher.updateAAD(it) }
        val ciphertext = cipher.doFinal(plaintext)

        // keySpec reference goes out of scope here — JVM will GC it
        return EncryptedData(nonce = nonce, ciphertext = ciphertext)
    }

    /**
     * Decrypts and authenticates [encryptedData] using AES-256-GCM.
     *
     * GCM verifies the authentication tag before returning plaintext.
     * If the tag fails (tampered ciphertext, wrong key, wrong nonce, wrong
     * AAD), [javax.crypto.AEADBadTagException] is thrown and no plaintext
     * is returned.
     *
     * @param keyBytes      A 32-byte (256-bit) AES key.
     * @param encryptedData The [EncryptedData] produced by [encryptAesGcm].
     * @param aad           The same AAD passed during encryption. May be null.
     * @return The decrypted plaintext bytes.
     * @throws IllegalArgumentException if [keyBytes] is not 32 bytes.
     * @throws javax.crypto.AEADBadTagException if authentication fails.
     */
    fun decryptAesGcm(
        keyBytes: ByteArray,
        encryptedData: EncryptedData,
        aad: ByteArray? = null,
    ): ByteArray {
        require(keyBytes.size == AES_KEY_LENGTH_BYTES) {
            "AES key must be exactly $AES_KEY_LENGTH_BYTES bytes (256 bits), got ${keyBytes.size}"
        }

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val keySpec = SecretKeySpec(keyBytes, "AES")
        cipher.init(
            Cipher.DECRYPT_MODE,
            keySpec,
            GCMParameterSpec(GCM_TAG_LENGTH_BITS, encryptedData.nonce),
        )
        aad?.let { cipher.updateAAD(it) }
        // AEADBadTagException thrown automatically by JCA if tag verification fails
        return cipher.doFinal(encryptedData.ciphertext)
    }

    // -----------------------------------------------------------------------
    // 4. HKDF-SHA256 — Key Derivation
    // -----------------------------------------------------------------------

    /**
     * Derives a key of [outputLength] bytes using HKDF with HMAC-SHA256,
     * as specified in RFC 5869.
     *
     * This is NOT a custom cryptographic algorithm. It is the standard
     * IETF HKDF construction built from the standard HMAC-SHA256 primitive
     * available in the Android JCA. It is the only way to implement HKDF
     * using standard Android/JVM APIs without third-party libraries.
     *
     * Steps per RFC 5869:
     *   1. Extract: `PRK = HMAC-SHA256(salt, IKM)`
     *   2. Expand:  OKM = T(1) || T(2) || … where
     *               T(i) = HMAC-SHA256(PRK, T(i-1) || info || i)
     *
     * Secure Memory: [inputKeyMaterial] (the raw shared secret) should be
     * passed in and the reference released immediately after this call.
     * [prk] is a local variable that goes out of scope at function end.
     *
     * @param inputKeyMaterial The raw input key material (e.g., X25519 shared secret).
     * @param salt             Optional random salt. If null or empty, a
     *                         zero-filled byte array of hash length is used
     *                         per RFC 5869 §2.2.
     * @param info             Context-binding information string. Must be
     *                         unique per derived key purpose.
     * @param outputLength     Desired output key length in bytes.
     *                         Maximum: 255 × 32 = 8160 bytes.
     * @return The derived key bytes.
     * @throws IllegalArgumentException if [outputLength] is out of range.
     */
    fun hkdfSha256(
        inputKeyMaterial: ByteArray,
        salt: ByteArray?,
        info: ByteArray,
        outputLength: Int,
    ): ByteArray {
        require(outputLength > 0) { "outputLength must be positive" }
        require(outputLength <= 255 * HMAC_SHA256_OUTPUT_BYTES) {
            "outputLength exceeds HKDF maximum (255 × HashLen = ${255 * HMAC_SHA256_OUTPUT_BYTES})"
        }

        val hmacAlgorithm = "HmacSHA256"

        // Step 1: Extract
        // Default salt is a string of HashLen zeros per RFC 5869 §2.2
        val effectiveSalt: ByteArray =
            if (salt == null || salt.isEmpty()) ByteArray(HMAC_SHA256_OUTPUT_BYTES) else salt

        val extractMac = Mac.getInstance(hmacAlgorithm)
        extractMac.init(SecretKeySpec(effectiveSalt, hmacAlgorithm))
        val prk: ByteArray = extractMac.doFinal(inputKeyMaterial) // PRK is local, not retained

        // Step 2: Expand
        val numBlocks = (outputLength + HMAC_SHA256_OUTPUT_BYTES - 1) / HMAC_SHA256_OUTPUT_BYTES
        val okm = ByteArray(numBlocks * HMAC_SHA256_OUTPUT_BYTES)
        var previousBlock = ByteArray(0)

        for (blockIndex in 1..numBlocks) {
            val expandMac = Mac.getInstance(hmacAlgorithm)
            expandMac.init(SecretKeySpec(prk, hmacAlgorithm))
            expandMac.update(previousBlock)
            expandMac.update(info)
            expandMac.update(blockIndex.toByte())
            previousBlock = expandMac.doFinal()
            previousBlock.copyInto(
                destination = okm,
                destinationOffset = (blockIndex - 1) * HMAC_SHA256_OUTPUT_BYTES,
            )
        }

        // prk and previousBlock go out of scope here — JVM will reclaim
        return okm.copyOf(outputLength)
    }

    // -----------------------------------------------------------------------
    // 5. SHA-256 — Hashing
    // -----------------------------------------------------------------------

    /**
     * Produces a SHA-256 digest of [data].
     *
     * @param data The input bytes to hash.
     * @return A 32-byte SHA-256 digest.
     */
    fun sha256(data: ByteArray): ByteArray {
        return MessageDigest.getInstance("SHA-256").digest(data)
    }
}
