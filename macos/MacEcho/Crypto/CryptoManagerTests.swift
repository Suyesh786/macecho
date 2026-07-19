// CryptoManagerTests.swift — Phase 8
//
// XCTest unit tests for all five cryptographic primitives.
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
//
// Note on test target:
//   This file is structured for a standard XCTest target. The current Xcode
//   project has a single application target. A dedicated test target (added
//   in a later infrastructure phase) will reference this file. Until then,
//   tests can be run by adding this file to an Xcode unit test target
//   manually, or via `swift test` in a Package.swift context.

import CryptoKit
import Foundation
import XCTest

@testable import MacEcho

final class CryptoManagerTests: XCTestCase {

    // -----------------------------------------------------------------------
    // 1. X25519 — Key Exchange
    // -----------------------------------------------------------------------

    func testX25519KeyGenerationProducesValidKey() {
        let privateKey = CryptoManager.generateX25519PrivateKey()
        // Public key raw representation must be 32 bytes (Curve25519 point)
        XCTAssertEqual(
            privateKey.publicKey.rawRepresentation.count, 32,
            "X25519 public key must be 32 bytes"
        )
    }

    func testX25519BothSidesDeriveSameSharedSecret() throws {
        let alicePrivateKey = CryptoManager.generateX25519PrivateKey()
        let bobPrivateKey = CryptoManager.generateX25519PrivateKey()

        let aliceSecret = try CryptoManager.deriveX25519SharedSecret(
            privateKey: alicePrivateKey,
            peerPublicKey: bobPrivateKey.publicKey
        )
        let bobSecret = try CryptoManager.deriveX25519SharedSecret(
            privateKey: bobPrivateKey,
            peerPublicKey: alicePrivateKey.publicKey
        )

        // Both sides must derive the same shared secret
        let aliceBytes = aliceSecret.withUnsafeBytes { Data($0) }
        let bobBytes = bobSecret.withUnsafeBytes { Data($0) }
        XCTAssertEqual(aliceBytes, bobBytes, "Both sides must derive the identical shared secret")
        XCTAssertEqual(aliceBytes.count, 32, "X25519 shared secret must be 32 bytes")
    }

    func testX25519DifferentPeerKeyProducesDifferentSecret() throws {
        let alicePrivateKey = CryptoManager.generateX25519PrivateKey()
        let bobPrivateKey = CryptoManager.generateX25519PrivateKey()
        let carolPrivateKey = CryptoManager.generateX25519PrivateKey()

        let aliceBobSecret = try CryptoManager.deriveX25519SharedSecret(
            privateKey: alicePrivateKey,
            peerPublicKey: bobPrivateKey.publicKey
        )
        let aliceCarolSecret = try CryptoManager.deriveX25519SharedSecret(
            privateKey: alicePrivateKey,
            peerPublicKey: carolPrivateKey.publicKey
        )

        let bobBytes = aliceBobSecret.withUnsafeBytes { Data($0) }
        let carolBytes = aliceCarolSecret.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(bobBytes, carolBytes, "Different peers must produce different shared secrets")
    }

    // -----------------------------------------------------------------------
    // 2. Ed25519 — Digital Signatures (success paths)
    // -----------------------------------------------------------------------

    func testEd25519KeyGenerationProducesValidKey() {
        let privateKey = CryptoManager.generateEd25519PrivateKey()
        XCTAssertEqual(
            privateKey.publicKey.rawRepresentation.count, 32,
            "Ed25519 public key must be 32 bytes"
        )
    }

    func testEd25519SignAndVerifyRoundTripSucceeds() throws {
        let privateKey = CryptoManager.generateEd25519PrivateKey()
        let message = Data("MacEcho test message".utf8)

        let signature = try CryptoManager.signEd25519(privateKey: privateKey, data: message)

        XCTAssertEqual(signature.count, 64, "Ed25519 signature must be 64 bytes")
        XCTAssertTrue(
            CryptoManager.verifyEd25519(
                publicKey: privateKey.publicKey,
                data: message,
                signature: signature
            ),
            "Verification of a valid signature must succeed"
        )
    }

    // -----------------------------------------------------------------------
    // 3. Ed25519 — Rejection paths (required by 10_TESTING_SPECIFICATION.md)
    // -----------------------------------------------------------------------

    func testEd25519VerifyReturnsFalseForTamperedData() throws {
        let privateKey = CryptoManager.generateEd25519PrivateKey()
        let message = Data("original message".utf8)
        let signature = try CryptoManager.signEd25519(privateKey: privateKey, data: message)

        let tamperedMessage = Data("tampered message".utf8)

        XCTAssertFalse(
            CryptoManager.verifyEd25519(
                publicKey: privateKey.publicKey,
                data: tamperedMessage,
                signature: signature
            ),
            "Verification must FAIL when data has been tampered"
        )
    }

    func testEd25519VerifyReturnsFalseForWrongPublicKey() throws {
        let signerKey = CryptoManager.generateEd25519PrivateKey()
        let differentKey = CryptoManager.generateEd25519PrivateKey()
        let message = Data("message".utf8)
        let signature = try CryptoManager.signEd25519(privateKey: signerKey, data: message)

        XCTAssertFalse(
            CryptoManager.verifyEd25519(
                publicKey: differentKey.publicKey,
                data: message,
                signature: signature
            ),
            "Verification must FAIL when a different public key is used"
        )
    }

    func testEd25519VerifyReturnsFalseForTamperedSignature() throws {
        let privateKey = CryptoManager.generateEd25519PrivateKey()
        let message = Data("message".utf8)
        var signature = try CryptoManager.signEd25519(privateKey: privateKey, data: message)

        // Flip the first byte of the signature
        signature[0] ^= 0xFF

        XCTAssertFalse(
            CryptoManager.verifyEd25519(
                publicKey: privateKey.publicKey,
                data: message,
                signature: signature
            ),
            "Verification must FAIL when the signature has been tampered"
        )
    }

    func testEd25519VerifyReturnsFalseForEmptySignature() throws {
        let privateKey = CryptoManager.generateEd25519PrivateKey()
        let message = Data("message".utf8)

        XCTAssertFalse(
            CryptoManager.verifyEd25519(
                publicKey: privateKey.publicKey,
                data: message,
                signature: Data()
            ),
            "Verification must FAIL for an empty signature"
        )
    }

    // -----------------------------------------------------------------------
    // 4. AES-256-GCM — Symmetric Encryption (success paths)
    // -----------------------------------------------------------------------

    func testAesGcmEncryptDecryptRoundTripProducesOriginalPlaintext() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("MacEcho secret notification".utf8)

        let sealedBox = try CryptoManager.encryptAesGcm(key: key, plaintext: plaintext)
        let decrypted = try CryptoManager.decryptAesGcm(key: key, sealedBox: sealedBox)

        XCTAssertEqual(decrypted, plaintext, "Decrypted plaintext must equal original plaintext")
        XCTAssertEqual(sealedBox.nonce.withUnsafeBytes { Data($0) }.count, 12, "GCM nonce must be 12 bytes")
    }

    func testAesGcmEachEncryptionUsesUniqueNonce() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("same message".utf8)

        let sealed1 = try CryptoManager.encryptAesGcm(key: key, plaintext: plaintext)
        let sealed2 = try CryptoManager.encryptAesGcm(key: key, plaintext: plaintext)

        let nonce1 = sealed1.nonce.withUnsafeBytes { Data($0) }
        let nonce2 = sealed2.nonce.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(nonce1, nonce2, "Each encryption must use a unique randomly-generated nonce")
    }

    func testAesGcmRoundTripWithAadSucceeds() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("payload".utf8)
        let aad = Data("header".utf8)

        let sealed = try CryptoManager.encryptAesGcm(key: key, plaintext: plaintext, authenticatedData: aad)
        let decrypted = try CryptoManager.decryptAesGcm(key: key, sealedBox: sealed, authenticatedData: aad)

        XCTAssertEqual(decrypted, plaintext, "Round trip with AAD must succeed")
    }

    // -----------------------------------------------------------------------
    // 5. AES-256-GCM — Rejection paths
    // -----------------------------------------------------------------------

    func testAesGcmDecryptWithWrongKeyThrows() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let plaintext = Data("secret".utf8)

        let sealed = try CryptoManager.encryptAesGcm(key: key1, plaintext: plaintext)

        XCTAssertThrowsError(
            try CryptoManager.decryptAesGcm(key: key2, sealedBox: sealed),
            "Decryption with wrong key must throw CryptoKit authentication error"
        )
    }

    func testAesGcmDecryptWithWrongAadThrows() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("secret".utf8)
        let correctAad = Data("correct-aad".utf8)
        let wrongAad = Data("wrong-aad".utf8)

        let sealed = try CryptoManager.encryptAesGcm(
            key: key, plaintext: plaintext, authenticatedData: correctAad
        )

        XCTAssertThrowsError(
            try CryptoManager.decryptAesGcm(key: key, sealedBox: sealed, authenticatedData: wrongAad),
            "Decryption with wrong AAD must throw due to authentication failure"
        )
    }

    // -----------------------------------------------------------------------
    // 6. HKDF-SHA256 — Key Derivation
    // -----------------------------------------------------------------------

    func testHkdfSha256ProducesOutputOfRequestedSize() throws {
        let aliceKey = CryptoManager.generateX25519PrivateKey()
        let bobKey = CryptoManager.generateX25519PrivateKey()
        let sharedSecret = try CryptoManager.deriveX25519SharedSecret(
            privateKey: aliceKey,
            peerPublicKey: bobKey.publicKey
        )

        let derived = CryptoManager.hkdfSha256(
            inputKeyMaterial: sharedSecret,
            salt: Data(),
            info: Data("MacEcho-session".utf8),
            outputByteCount: 32
        )

        derived.withUnsafeBytes { bytes in
            XCTAssertEqual(bytes.count, 32, "HKDF output must be 32 bytes")
        }
    }

    func testHkdfSha256IsDeterministicForIdenticalInputs() throws {
        let sharedSecret = Data(repeating: 0x42, count: 32)
        let salt = Data(repeating: 0x01, count: 16)
        let info = Data("info".utf8)

        let derived1 = CryptoManager.hkdfSha256(
            inputKeyMaterial: sharedSecret,
            salt: salt,
            info: info,
            outputByteCount: 32
        )
        let derived2 = CryptoManager.hkdfSha256(
            inputKeyMaterial: sharedSecret,
            salt: salt,
            info: info,
            outputByteCount: 32
        )

        let key1 = derived1.withUnsafeBytes { Data($0) }
        let key2 = derived2.withUnsafeBytes { Data($0) }
        XCTAssertEqual(key1, key2, "HKDF must be deterministic for identical inputs")
    }

    func testHkdfSha256ProducesDifferentOutputForDifferentInfo() throws {
        let sharedSecret = Data(repeating: 0x42, count: 32)
        let salt = Data(repeating: 0x01, count: 16)

        let derivedA = CryptoManager.hkdfSha256(
            inputKeyMaterial: sharedSecret,
            salt: salt,
            info: Data("purpose-A".utf8),
            outputByteCount: 32
        )
        let derivedB = CryptoManager.hkdfSha256(
            inputKeyMaterial: sharedSecret,
            salt: salt,
            info: Data("purpose-B".utf8),
            outputByteCount: 32
        )

        let keyA = derivedA.withUnsafeBytes { Data($0) }
        let keyB = derivedB.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(keyA, keyB, "Different info values must produce different derived keys")
    }

    // -----------------------------------------------------------------------
    // 7. SHA-256 — Hashing
    // -----------------------------------------------------------------------

    func testSha256Produces32ByteOutput() {
        let digest = CryptoManager.sha256(Data("MacEcho".utf8))
        XCTAssertEqual(
            Data(digest).count, 32,
            "SHA-256 digest must be 32 bytes"
        )
    }

    func testSha256EmptyInputMatchesFipsTestVector() {
        // RFC 6234 / FIPS 180-4 test vector:
        // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb924
        //               27ae41e4649b934ca495991b7852b855
        let expected = Data([
            0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
            0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
            0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
            0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
        ])

        let actual = Data(CryptoManager.sha256(Data()))
        XCTAssertEqual(actual, expected, "SHA-256 of empty input must match FIPS 180-4 test vector")
    }

    func testSha256IsDeterministicForIdenticalInputs() {
        let data = Data("deterministic".utf8)
        XCTAssertEqual(
            Data(CryptoManager.sha256(data)),
            Data(CryptoManager.sha256(data)),
            "SHA-256 must be deterministic"
        )
    }

    func testSha256DifferentInputsProduceDifferentDigests() {
        let digest1 = Data(CryptoManager.sha256(Data("input-A".utf8)))
        let digest2 = Data(CryptoManager.sha256(Data("input-B".utf8)))
        XCTAssertNotEqual(digest1, digest2, "Different inputs must produce different SHA-256 digests")
    }
}
