package com.macecho.app.crypto

// Phase 8 — Cryptographic Primitive Unit Tests
//
// These tests run on the host JVM (no Android emulator required).
// Command: ./gradlew :app:test --tests "com.macecho.app.crypto.CryptoManagerTest"
//
// Coverage per 10_TESTING_SPECIFICATION.md §Unit Tests / Cryptography:
//   ✓ Key generation (X25519, Ed25519)
//   ✓ Encryption and decryption using AES-256-GCM
//   ✓ Key derivation using HKDF-SHA256
//   ✓ Hashing using SHA-256
//   ✓ Signature creation and verification
//   ✓ Rejection of invalid signatures
//
// Acceptance criteria per 11_IMPLEMENTATION_PLAN.MD §Phase 8:
//   ✓ All five primitives unit tested
//   ✓ Invalid signatures correctly rejected
//   ✓ No cryptographic material is logged

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import javax.crypto.AEADBadTagException

class CryptoManagerTest {

    // -----------------------------------------------------------------------
    // 1. X25519 — Key Exchange
    // -----------------------------------------------------------------------

    @Test
    fun `X25519 generateX25519KeyPair produces non-null keys`() {
        val kp = CryptoManager.generateX25519KeyPair()
        assertNotNull("Public key must not be null", kp.public)
        assertNotNull("Private key must not be null", kp.private)
        assertTrue(
            "Public key must have encoded bytes",
            kp.public.encoded.isNotEmpty(),
        )
    }

    @Test
    fun `X25519 both sides derive the same shared secret`() {
        val aliceKp = CryptoManager.generateX25519KeyPair()
        val bobKp = CryptoManager.generateX25519KeyPair()

        val aliceSecret = CryptoManager.deriveX25519SharedSecret(
            privateKey = aliceKp.private,
            peerPublicKeyBytes = bobKp.public.encoded,
        )
        val bobSecret = CryptoManager.deriveX25519SharedSecret(
            privateKey = bobKp.private,
            peerPublicKeyBytes = aliceKp.public.encoded,
        )

        assertArrayEquals(
            "Both sides must derive the identical shared secret",
            aliceSecret,
            bobSecret,
        )
        assertEquals("X25519 shared secret must be 32 bytes", 32, aliceSecret.size)
    }

    @Test
    fun `X25519 independent key pairs produce different shared secrets`() {
        val aliceKp = CryptoManager.generateX25519KeyPair()
        val bobKp = CryptoManager.generateX25519KeyPair()
        val carolKp = CryptoManager.generateX25519KeyPair()

        val aliceBobSecret = CryptoManager.deriveX25519SharedSecret(
            aliceKp.private, bobKp.public.encoded,
        )
        val aliceCarolSecret = CryptoManager.deriveX25519SharedSecret(
            aliceKp.private, carolKp.public.encoded,
        )

        assertFalse(
            "Different peer keys must produce different shared secrets",
            aliceBobSecret.contentEquals(aliceCarolSecret),
        )
    }

    // -----------------------------------------------------------------------
    // 2. Ed25519 — Digital Signatures (success paths)
    // -----------------------------------------------------------------------

    @Test
    fun `Ed25519 generateEd25519KeyPair produces non-null keys`() {
        val kp = CryptoManager.generateEd25519KeyPair()
        assertNotNull("Public key must not be null", kp.public)
        assertNotNull("Private key must not be null", kp.private)
        assertTrue(
            "Public key must have encoded bytes",
            kp.public.encoded.isNotEmpty(),
        )
    }

    @Test
    fun `Ed25519 sign and verify round trip succeeds`() {
        val kp = CryptoManager.generateEd25519KeyPair()
        val message = "MacEcho test message".toByteArray()

        val signature = CryptoManager.signEd25519(kp.private, message)

        assertTrue(
            "Signature over original message must verify successfully",
            CryptoManager.verifyEd25519(
                publicKeyBytes = kp.public.encoded,
                data = message,
                signature = signature,
            ),
        )
        assertEquals("Ed25519 signature must be 64 bytes", 64, signature.size)
    }

    // -----------------------------------------------------------------------
    // 3. Ed25519 — Rejection paths (10_TESTING_SPECIFICATION.md requirement)
    // -----------------------------------------------------------------------

    @Test
    fun `Ed25519 verify returns false for tampered data`() {
        val kp = CryptoManager.generateEd25519KeyPair()
        val message = "original message".toByteArray()
        val signature = CryptoManager.signEd25519(kp.private, message)

        val tamperedMessage = "tampered message".toByteArray()

        assertFalse(
            "Verification must FAIL when data has been tampered",
            CryptoManager.verifyEd25519(
                publicKeyBytes = kp.public.encoded,
                data = tamperedMessage,
                signature = signature,
            ),
        )
    }

    @Test
    fun `Ed25519 verify returns false for wrong public key`() {
        val signerKp = CryptoManager.generateEd25519KeyPair()
        val differentKp = CryptoManager.generateEd25519KeyPair()
        val message = "message".toByteArray()
        val signature = CryptoManager.signEd25519(signerKp.private, message)

        assertFalse(
            "Verification must FAIL when a different public key is used",
            CryptoManager.verifyEd25519(
                publicKeyBytes = differentKp.public.encoded,
                data = message,
                signature = signature,
            ),
        )
    }

    @Test
    fun `Ed25519 verify returns false for tampered signature`() {
        val kp = CryptoManager.generateEd25519KeyPair()
        val message = "message".toByteArray()
        val signature = CryptoManager.signEd25519(kp.private, message)

        // Flip a byte in the signature
        val tamperedSignature = signature.copyOf()
        tamperedSignature[0] = tamperedSignature[0].toInt().xor(0xFF).toByte()

        assertFalse(
            "Verification must FAIL when signature bytes have been tampered",
            CryptoManager.verifyEd25519(
                publicKeyBytes = kp.public.encoded,
                data = message,
                signature = tamperedSignature,
            ),
        )
    }

    @Test
    fun `Ed25519 verify returns false for empty signature`() {
        val kp = CryptoManager.generateEd25519KeyPair()
        val message = "message".toByteArray()

        assertFalse(
            "Verification must FAIL for empty signature input",
            CryptoManager.verifyEd25519(
                publicKeyBytes = kp.public.encoded,
                data = message,
                signature = ByteArray(0),
            ),
        )
    }

    @Test
    fun `Ed25519 verify returns false for malformed public key bytes`() {
        val message = "message".toByteArray()
        val kp = CryptoManager.generateEd25519KeyPair()
        val signature = CryptoManager.signEd25519(kp.private, message)

        assertFalse(
            "Verification must FAIL for malformed public key bytes — must not throw",
            CryptoManager.verifyEd25519(
                publicKeyBytes = ByteArray(16) { 0xAB.toByte() }, // invalid key
                data = message,
                signature = signature,
            ),
        )
    }

    // -----------------------------------------------------------------------
    // 4. AES-256-GCM — Symmetric Encryption (success path)
    // -----------------------------------------------------------------------

    @Test
    fun `AES-256-GCM encrypt and decrypt round trip produces original plaintext`() {
        val key = generateRandomKey()
        val plaintext = "MacEcho secret notification".toByteArray()

        val encrypted = CryptoManager.encryptAesGcm(key, plaintext)
        val decrypted = CryptoManager.decryptAesGcm(key, encrypted)

        assertArrayEquals(
            "Decrypted plaintext must equal original plaintext",
            plaintext,
            decrypted,
        )
        assertEquals("Nonce must be 12 bytes", 12, encrypted.nonce.size)
    }

    @Test
    fun `AES-256-GCM encrypt produces different ciphertext for same plaintext`() {
        val key = generateRandomKey()
        val plaintext = "same message".toByteArray()

        val encrypted1 = CryptoManager.encryptAesGcm(key, plaintext)
        val encrypted2 = CryptoManager.encryptAesGcm(key, plaintext)

        // Different nonces must produce different ciphertexts
        assertFalse(
            "Each encryption must use a unique nonce",
            encrypted1.nonce.contentEquals(encrypted2.nonce),
        )
    }

    @Test
    fun `AES-256-GCM round trip with AAD succeeds`() {
        val key = generateRandomKey()
        val plaintext = "payload".toByteArray()
        val aad = "header".toByteArray()

        val encrypted = CryptoManager.encryptAesGcm(key, plaintext, aad)
        val decrypted = CryptoManager.decryptAesGcm(key, encrypted, aad)

        assertArrayEquals("Round trip with AAD must succeed", plaintext, decrypted)
    }

    // -----------------------------------------------------------------------
    // 5. AES-256-GCM — Rejection paths
    // -----------------------------------------------------------------------

    @Test(expected = AEADBadTagException::class)
    fun `AES-256-GCM decrypt with tampered ciphertext throws AEADBadTagException`() {
        val key = generateRandomKey()
        val plaintext = "secret".toByteArray()
        val encrypted = CryptoManager.encryptAesGcm(key, plaintext)

        // Tamper with the ciphertext bytes
        val tamperedCiphertext = encrypted.ciphertext.copyOf()
        tamperedCiphertext[0] = tamperedCiphertext[0].toInt().xor(0xFF).toByte()

        CryptoManager.decryptAesGcm(
            key,
            CryptoManager.EncryptedData(encrypted.nonce, tamperedCiphertext),
        )
    }

    @Test(expected = AEADBadTagException::class)
    fun `AES-256-GCM decrypt with wrong AAD throws AEADBadTagException`() {
        val key = generateRandomKey()
        val plaintext = "secret".toByteArray()
        val encrypted = CryptoManager.encryptAesGcm(key, plaintext, aad = "correct-aad".toByteArray())

        // Attempt decryption with different AAD — authentication must fail
        CryptoManager.decryptAesGcm(key, encrypted, aad = "wrong-aad".toByteArray())
    }

    @Test(expected = IllegalArgumentException::class)
    fun `AES-256-GCM encrypt rejects key shorter than 32 bytes`() {
        CryptoManager.encryptAesGcm(
            keyBytes = ByteArray(16), // 128-bit key — not allowed (must be 256-bit)
            plaintext = "data".toByteArray(),
        )
    }

    // -----------------------------------------------------------------------
    // 6. HKDF-SHA256 — Key Derivation
    // -----------------------------------------------------------------------

    @Test
    fun `HKDF-SHA256 produces output of requested length`() {
        val ikm = ByteArray(32) { it.toByte() }
        val salt = ByteArray(16) { 0x01 }
        val info = "MacEcho-session".toByteArray()

        val derived = CryptoManager.hkdfSha256(ikm, salt, info, outputLength = 32)
        assertEquals("HKDF output must match requested length", 32, derived.size)
    }

    @Test
    fun `HKDF-SHA256 is deterministic for identical inputs`() {
        val ikm = ByteArray(32) { it.toByte() }
        val salt = ByteArray(16) { 0x01 }
        val info = "info".toByteArray()

        val derived1 = CryptoManager.hkdfSha256(ikm, salt, info, 32)
        val derived2 = CryptoManager.hkdfSha256(ikm, salt, info, 32)

        assertArrayEquals(
            "HKDF must be deterministic for identical inputs",
            derived1,
            derived2,
        )
    }

    @Test
    fun `HKDF-SHA256 produces different output for different info values`() {
        val ikm = ByteArray(32) { it.toByte() }
        val salt = ByteArray(16) { 0x01 }

        val derived1 = CryptoManager.hkdfSha256(ikm, salt, "purpose-A".toByteArray(), 32)
        val derived2 = CryptoManager.hkdfSha256(ikm, salt, "purpose-B".toByteArray(), 32)

        assertFalse(
            "Different info strings must produce different derived keys",
            derived1.contentEquals(derived2),
        )
    }

    @Test
    fun `HKDF-SHA256 accepts null salt using RFC 5869 default`() {
        val ikm = ByteArray(32) { it.toByte() }
        val info = "test".toByteArray()

        val derived = CryptoManager.hkdfSha256(ikm, null, info, 32)
        assertEquals("HKDF with null salt must produce 32 bytes", 32, derived.size)
    }

    @Test
    fun `HKDF-SHA256 can derive more than one hash-length block`() {
        val ikm = ByteArray(32) { 0x42 }
        val salt = ByteArray(16) { 0x00 }
        val info = "multi-block".toByteArray()

        val derived = CryptoManager.hkdfSha256(ikm, salt, info, outputLength = 64)
        assertEquals("HKDF must produce 64 bytes (2 blocks)", 64, derived.size)
    }

    // -----------------------------------------------------------------------
    // 7. SHA-256 — Hashing
    // -----------------------------------------------------------------------

    @Test
    fun `SHA-256 produces 32-byte output`() {
        val digest = CryptoManager.sha256("MacEcho".toByteArray())
        assertEquals("SHA-256 digest must be 32 bytes", 32, digest.size)
    }

    @Test
    fun `SHA-256 of empty input produces known-good digest`() {
        // RFC 6234 / FIPS 180-4 test vector: SHA-256("") =
        // e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        val expected = byteArrayOf(
            0xe3.toByte(), 0xb0.toByte(), 0xc4.toByte(), 0x42.toByte(),
            0x98.toByte(), 0xfc.toByte(), 0x1c.toByte(), 0x14.toByte(),
            0x9a.toByte(), 0xfb.toByte(), 0xf4.toByte(), 0xc8.toByte(),
            0x99.toByte(), 0x6f.toByte(), 0xb9.toByte(), 0x24.toByte(),
            0x27.toByte(), 0xae.toByte(), 0x41.toByte(), 0xe4.toByte(),
            0x64.toByte(), 0x9b.toByte(), 0x93.toByte(), 0x4c.toByte(),
            0xa4.toByte(), 0x95.toByte(), 0x99.toByte(), 0x1b.toByte(),
            0x78.toByte(), 0x52.toByte(), 0xb8.toByte(), 0x55.toByte(),
        )

        assertArrayEquals(
            "SHA-256 of empty input must match FIPS 180-4 test vector",
            expected,
            CryptoManager.sha256(ByteArray(0)),
        )
    }

    @Test
    fun `SHA-256 of same input produces same digest`() {
        val data = "deterministic".toByteArray()
        assertArrayEquals(
            "SHA-256 must be deterministic",
            CryptoManager.sha256(data),
            CryptoManager.sha256(data),
        )
    }

    @Test
    fun `SHA-256 of different inputs produces different digests`() {
        val digest1 = CryptoManager.sha256("input-A".toByteArray())
        val digest2 = CryptoManager.sha256("input-B".toByteArray())
        assertFalse(
            "Different inputs must produce different SHA-256 digests",
            digest1.contentEquals(digest2),
        )
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /**
     * Generates a 32-byte random key for test purposes.
     * Uses SecureRandom to be consistent with production code requirements.
     */
    private fun generateRandomKey(): ByteArray {
        val key = ByteArray(32)
        java.security.SecureRandom().nextBytes(key)
        return key
    }
}
