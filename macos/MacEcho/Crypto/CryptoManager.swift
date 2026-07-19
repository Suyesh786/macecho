// CryptoManager.swift — Phase 8
//
// Exposes the five mandatory cryptographic primitives required by
// Architecture Decision 16 and 04_SECURITY_MODEL.md §End-to-End Encryption:
//
//   1. X25519  — Key exchange (Curve25519.KeyAgreement)
//   2. Ed25519 — Digital signatures (Curve25519.Signing)
//   3. AES-256-GCM — Symmetric encryption (AES.GCM)
//   4. HKDF-SHA256 — Key derivation (HKDF<SHA256>)
//   5. SHA-256 — Hashing (SHA256)
//
// All primitives are provided by Apple's CryptoKit framework.
// No custom cryptographic algorithm implementations are present.
// No Security framework bypass. No third-party libraries.
//
// Must NOT contain:
//   - Authentication or session logic   → Phase 13
//   - Pairing logic                     → Phase 12
//   - Packet encryption pipeline        → Phase 10
//   - Keychain storage                  → Phase 9
//   - Replay protection                 → Protocol phases
//   - AppKit, NSView, or menu bar code
//   - Business logic of any kind
//
// Cryptographically Secure Randomness:
//   CryptoKit uses the operating system's cryptographic random source
//   (Security framework SecRandomCopyBytes) internally for all key
//   generation and nonce generation. No application-level random number
//   generation is required — CryptoKit handles it correctly and securely.
//   Swift's standard random APIs are not used in this file.
//
// Secure Memory Handling:
//   CryptoKit's key types (PrivateKey, SymmetricKey, SharedSecret) are
//   memory-safe value types backed by secure allocations managed by the
//   framework. They are zeroed by the framework when they go out of scope.
//   Callers should hold references only as long as needed and allow them
//   to go out of scope immediately after use. No manual memory management
//   is performed here — CryptoKit handles cleanup correctly.
//
// Platform:
//   macOS 13.0+ (MACOSX_DEPLOYMENT_TARGET = 13.0)
//   Swift 6.0 (SWIFT_VERSION = 6.0)
//   CryptoKit is bundled with macOS — no additional dependencies required.

import CryptoKit
import Foundation

// CryptoManager is a caseless enum used as a namespace.
// It cannot be instantiated. All functions are static (static on enum = no self).
enum CryptoManager {

    // -----------------------------------------------------------------------
    // 1. X25519 — Key Exchange
    // -----------------------------------------------------------------------

    /// Generates a new X25519 key exchange private key.
    ///
    /// The corresponding public key is available via `privateKey.publicKey`.
    /// CryptoKit uses the system CSPRNG internally — no application-level
    /// randomness is required.
    ///
    /// - Returns: A freshly generated `Curve25519.KeyAgreement.PrivateKey`.
    static func generateX25519PrivateKey() -> Curve25519.KeyAgreement.PrivateKey {
        Curve25519.KeyAgreement.PrivateKey()
    }

    /// Derives a shared secret using X25519 Diffie-Hellman key agreement.
    ///
    /// Secure Memory: `SharedSecret` is a CryptoKit opaque type backed by a
    /// secure allocation. Pass it immediately to `hkdfSha256` and allow the
    /// reference to go out of scope. Do not store it as a property.
    ///
    /// - Parameters:
    ///   - privateKey: The local device's X25519 private key.
    ///   - peerPublicKey: The peer's X25519 public key.
    /// - Returns: The raw `SharedSecret` (32 bytes).
    /// - Throws: `CryptoKitError` if the key agreement fails (e.g., invalid point).
    static func deriveX25519SharedSecret(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> SharedSecret {
        try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
    }

    // -----------------------------------------------------------------------
    // 2. Ed25519 — Digital Signatures
    // -----------------------------------------------------------------------

    /// Generates a new Ed25519 signing key pair.
    ///
    /// The corresponding public key is available via `privateKey.publicKey`.
    /// CryptoKit uses the system CSPRNG internally.
    ///
    /// - Returns: A freshly generated `Curve25519.Signing.PrivateKey`.
    static func generateEd25519PrivateKey() -> Curve25519.Signing.PrivateKey {
        Curve25519.Signing.PrivateKey()
    }

    /// Signs [data] using Ed25519.
    ///
    /// - Parameters:
    ///   - privateKey: The signer's Ed25519 private key.
    ///   - data: The data to sign.
    /// - Returns: A 64-byte Ed25519 signature as `Data`.
    /// - Throws: `CryptoKitError` if signing fails.
    static func signEd25519(
        privateKey: Curve25519.Signing.PrivateKey,
        data: Data
    ) throws -> Data {
        try privateKey.signature(for: data)
    }

    /// Verifies an Ed25519 signature.
    ///
    /// Returns `false` for any invalid input — wrong key, tampered data,
    /// malformed signature — without throwing. Callers must treat `false`
    /// as an immediate rejection; do not process [data] if verification fails.
    ///
    /// - Parameters:
    ///   - publicKey: The signer's Ed25519 public key.
    ///   - data: The original signed data.
    ///   - signature: The Ed25519 signature to verify.
    /// - Returns: `true` if the signature is valid; `false` in all other cases.
    static func verifyEd25519(
        publicKey: Curve25519.Signing.PublicKey,
        data: Data,
        signature: Data
    ) -> Bool {
        publicKey.isValidSignature(signature, for: data)
    }

    // -----------------------------------------------------------------------
    // 3. AES-256-GCM — Symmetric Encryption
    // -----------------------------------------------------------------------

    /// Encrypts [plaintext] using AES-256-GCM.
    ///
    /// CryptoKit generates a fresh 12-byte nonce from the system CSPRNG for
    /// every call. The nonce is included in the returned `SealedBox` and
    /// must be transmitted alongside the ciphertext.
    ///
    /// Optional [authenticatedData] is authenticated but not encrypted.
    /// Pass the same value to `decryptAesGcm` for successful decryption.
    ///
    /// Secure Memory: Callers should allow the plaintext `Data` buffer to go
    /// out of scope immediately after this call. CryptoKit manages its own
    /// internal copy securely.
    ///
    /// - Parameters:
    ///   - key: A 256-bit (32-byte) `SymmetricKey`.
    ///   - plaintext: The data to encrypt.
    ///   - authenticatedData: Optional additional authenticated data.
    /// - Returns: A `SealedBox` containing nonce + ciphertext + 16-byte auth tag.
    /// - Throws: `CryptoKitError` if encryption fails.
    static func encryptAesGcm(
        key: SymmetricKey,
        plaintext: some DataProtocol,
        authenticatedData: (some DataProtocol)? = nil as Data?
    ) throws -> AES.GCM.SealedBox {
        if let aad = authenticatedData {
            return try AES.GCM.seal(plaintext, using: key, authenticating: aad)
        } else {
            return try AES.GCM.seal(plaintext, using: key)
        }
    }

    /// Decrypts and authenticates a `SealedBox` using AES-256-GCM.
    ///
    /// CryptoKit verifies the authentication tag before returning plaintext.
    /// If authentication fails (tampered ciphertext, wrong key, wrong nonce,
    /// wrong AAD), `CryptoKitError.authenticationFailure` is thrown and no
    /// plaintext is returned.
    ///
    /// - Parameters:
    ///   - key: The same 256-bit `SymmetricKey` used for encryption.
    ///   - sealedBox: The `SealedBox` produced by `encryptAesGcm`.
    ///   - authenticatedData: The same AAD provided during encryption.
    /// - Returns: The decrypted plaintext `Data`.
    /// - Throws: `CryptoKitError.authenticationFailure` if authentication fails.
    static func decryptAesGcm(
        key: SymmetricKey,
        sealedBox: AES.GCM.SealedBox,
        authenticatedData: (some DataProtocol)? = nil as Data?
    ) throws -> Data {
        if let aad = authenticatedData {
            return try AES.GCM.open(sealedBox, using: key, authenticating: aad)
        } else {
            return try AES.GCM.open(sealedBox, using: key)
        }
    }

    // -----------------------------------------------------------------------
    // 4. HKDF-SHA256 — Key Derivation
    // -----------------------------------------------------------------------

    /// Derives a `SymmetricKey` of [outputByteCount] bytes using HKDF with
    /// SHA-256, as specified in RFC 5869.
    ///
    /// Uses CryptoKit's built-in `HKDF<SHA256>` — no manual implementation.
    ///
    /// Secure Memory: [inputKeyMaterial] (typically the output of
    /// `deriveX25519SharedSecret`) should have its reference released
    /// immediately after this call. CryptoKit's `SymmetricKey` type manages
    /// its own secure allocation and is zeroed when it goes out of scope.
    ///
    /// - Parameters:
    ///   - inputKeyMaterial: The raw key material (e.g., X25519 shared secret).
    ///   - salt: Optional random salt `Data`. An empty or zero salt is valid
    ///           per RFC 5869 §2.2.
    ///   - info: Context-binding `Data`. Must be unique per derived key purpose.
    ///   - outputByteCount: Desired output key length in bytes.
    /// - Returns: A `SymmetricKey` of [outputByteCount] bytes.
    static func hkdfSha256(
        inputKeyMaterial: SharedSecret,
        salt: some DataProtocol,
        info: some DataProtocol,
        outputByteCount: Int
    ) -> SymmetricKey {
        inputKeyMaterial.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: info,
            outputByteCount: outputByteCount
        )
    }

    /// Derives a `SymmetricKey` from raw `Data` input key material.
    ///
    /// This overload accepts raw bytes (e.g., a previously derived key being
    /// re-derived for a different purpose). Uses HKDF<SHA256>.
    ///
    /// - Parameters:
    ///   - inputKeyMaterial: Raw key material as `Data`.
    ///   - salt: Optional random salt.
    ///   - info: Context-binding bytes.
    ///   - outputByteCount: Desired output key length in bytes.
    /// - Returns: A `SymmetricKey` of [outputByteCount] bytes.
    static func hkdfSha256(
        inputKeyMaterial: Data,
        salt: Data,
        info: Data,
        outputByteCount: Int
    ) -> SymmetricKey {
        // SymmetricKey(data:) requires ContiguousBytes; Data satisfies this.
        let ikm = SymmetricKey(data: inputKeyMaterial)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm,
            salt: salt,
            info: info,
            outputByteCount: outputByteCount
        )
    }

    // -----------------------------------------------------------------------
    // 5. SHA-256 — Hashing
    // -----------------------------------------------------------------------

    /// Produces a SHA-256 digest of [data].
    ///
    /// - Parameter data: The input bytes to hash.
    /// - Returns: A `SHA256Digest` (32 bytes). Use `.withUnsafeBytes { ... }`
    ///            or `Data(digest)` to access the raw bytes.
    static func sha256(_ data: some DataProtocol) -> SHA256Digest {
        SHA256.hash(data: data)
    }

    // -----------------------------------------------------------------------
    // Utility — SymmetricKey from raw bytes
    // -----------------------------------------------------------------------

    /// Creates a 256-bit `SymmetricKey` from a 32-byte raw key `Data`.
    ///
    /// - Parameter data: Exactly 32 bytes of raw key material.
    /// - Returns: A `SymmetricKey` with size `.bits256`.
    static func symmetricKey(from data: Data) -> SymmetricKey {
        SymmetricKey(data: data)
    }
}
