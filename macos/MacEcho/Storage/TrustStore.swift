// TrustStore.swift — Phase 9
//
// Encrypted local storage for trusted device metadata per
// 04_SECURITY_MODEL.md §Local Trust Database and Architecture Decision 18.
//
// This is NOT the Apple Keychain (that is KeychainManager.swift).
// The Security Model explicitly separates:
//   - Private keys          → Apple Keychain (KeychainManager.swift)
//   - Trust metadata        → Encrypted local storage (this file)
//
// Trust metadata stored per entry (04_SECURITY_MODEL.md §Local Trust Database):
//   • Trusted Device Identifier
//   • Trusted Public Key (X25519 + Ed25519 raw representations)
//   • Pairing Timestamp
//   • Trust Status
//   • Device Metadata (name, type)
//
// Encryption:
//   A dedicated AES-256-GCM symmetric key is stored in the Keychain under the
//   "com.macecho.app.truststore" service. All trust data is encrypted with this
//   key before writing to the Application Support directory. The trust store key
//   is separate from the identity key (Architecture Decision 18: "Separating
//   metadata into encrypted local storage was preferred, since metadata does not
//   require hardware-backed key storage and benefits from simpler access patterns.")
//
// Serialization: Swift Codable → JSONEncoder → AES-GCM encrypted Data → file.
//
// Must NOT contain:
//   - Pairing logic          → Phase 12 (TrustStore is populated by Phase 12)
//   - Authentication logic   → Phase 13
//   - Transport              → Phase 7
//   - Private key material   → KeychainManager.swift
//   - AppKit, NSView, menu bar code
//   - Business logic of any kind
//
// Starts empty. Phase 12 (pairing) will call addOrUpdate(_:) to populate it.
//
// Storage file: ~/Library/Application Support/MacEcho/macecho_trust.enc
// Key in Keychain service: "com.macecho.app.truststore"
// Key account name: "trust.encryption.key"

import CryptoKit
import Foundation
import Security

// ---------------------------------------------------------------------------
// TrustStatus
// ---------------------------------------------------------------------------

/// Current trust status of a paired remote device.
///
/// - `trusted`: Pairing completed; device is recognized as a trusted peer.
/// - `revoked`: Trust removed by unpairing, key change, or explicit revocation.
enum TrustStatus: String, Codable, CaseIterable {
    case trusted = "TRUSTED"
    case revoked = "REVOKED"
}

// ---------------------------------------------------------------------------
// TrustEntry — one record in the local trust database
// ---------------------------------------------------------------------------

/// A single entry in the local trust database.
///
/// Represents one trusted (or previously trusted) remote device. Populated
/// by Phase 12 (pairing) and validated by Phase 13 (authentication).
///
/// Per `04_SECURITY_MODEL.md §Local Trust Database`:
/// - Never stores the other device's private key.
/// - The backend has no authority to modify this record.
/// - Only the local application may update trust records after successful
///   security validation.
struct TrustEntry: Codable, Equatable {
    /// The peer's cryptographically random device ID.
    let trustedDeviceId: String
    /// Peer's X25519 public key raw representation (32 bytes).
    let trustedX25519PublicKeyData: Data
    /// Peer's Ed25519 public key raw representation (32 bytes).
    let trustedEd25519PublicKeyData: Data
    /// Unix epoch milliseconds when pairing completed.
    let pairingTimestampMs: Int64
    /// Current trust status.
    let trustStatus: TrustStatus
    /// Human-readable peer device name (e.g. "Suyesh's Android").
    let deviceName: String
    /// Peer platform string (e.g. "ANDROID").
    let deviceType: String
}

// ---------------------------------------------------------------------------
// TrustStore errors
// ---------------------------------------------------------------------------

/// Errors that can occur during TrustStore operations.
enum TrustStoreError: Error, LocalizedError {
    case keychainKeyWriteFailed(OSStatus)
    case keychainKeyReadFailed
    case encryptionFailed
    case decryptionFailed
    case fileWriteFailed(Error)
    case fileReadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .keychainKeyWriteFailed(let status): return "Trust key Keychain write failed: OSStatus \(status)"
        case .keychainKeyReadFailed:              return "Trust encryption key not found in Keychain"
        case .encryptionFailed:                   return "Trust data encryption failed"
        case .decryptionFailed:                   return "Trust data decryption failed — data may be corrupt"
        case .fileWriteFailed(let e):             return "Trust store file write failed: \(e.localizedDescription)"
        case .fileReadFailed(let e):              return "Trust store file read failed: \(e.localizedDescription)"
        }
    }
}

// ---------------------------------------------------------------------------
// TrustStore
// ---------------------------------------------------------------------------

/// Encrypted local storage for trusted device metadata.
///
/// Operations are synchronous and safe to call from any thread. In production,
/// callers should dispatch to a background queue (e.g. `DispatchQueue.global(qos: .utility)`).
/// Thread safety is the caller's responsibility.
struct TrustStore {

    private static let keychainService = "com.macecho.app.truststore"
    private static let trustKeyAccount = "trust.encryption.key"
    private static let trustFileName   = "macecho_trust.enc"
    private static let appSupportSubdir = "MacEcho"

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Adds or updates a trust entry.
    ///
    /// If an entry with `entry.trustedDeviceId` already exists, it is replaced.
    /// Called by Phase 12 (pairing) after a successful pairing flow.
    ///
    /// - Throws: `TrustStoreError` if encryption or file write fails.
    func addOrUpdate(_ entry: TrustEntry) throws {
        var entries = try loadEntries()
        entries[entry.trustedDeviceId] = entry
        try saveEntries(entries)
    }

    /// Returns the trust entry for `deviceId`, or nil if not found.
    ///
    /// Called by Phase 13 (authentication) to verify an incoming connection.
    func get(deviceId: String) -> TrustEntry? {
        (try? loadEntries())?[deviceId]
    }

    /// Returns all trust entries in the store. Order is not guaranteed.
    /// Returns an empty array if no devices have been paired.
    func getAll() -> [TrustEntry] {
        (try? loadEntries())?.values.map { $0 } ?? []
    }

    /// Returns `true` if a trust entry exists for `deviceId`.
    func contains(deviceId: String) -> Bool {
        (try? loadEntries())?[deviceId] != nil
    }

    /// Removes the trust entry for `deviceId`.
    ///
    /// Safe to call when `deviceId` is not present (idempotent).
    /// Called by Phase 12 (unpairing flow).
    ///
    /// - Throws: `TrustStoreError` if encryption or file write fails.
    func remove(deviceId: String) throws {
        var entries = try loadEntries()
        if entries.removeValue(forKey: deviceId) != nil {
            try saveEntries(entries)
        }
    }

    /// Removes all trust entries. The trust store file is overwritten with
    /// an empty encrypted store. Used by application reset flows.
    ///
    /// - Throws: `TrustStoreError` if file write fails.
    func clear() throws {
        try saveEntries([:])
    }

    /// Returns the number of trust entries currently stored.
    func count() -> Int {
        (try? loadEntries())?.count ?? 0
    }

    // -----------------------------------------------------------------------
    // Private implementation
    // -----------------------------------------------------------------------

    private func loadEntries() throws -> [String: TrustEntry] {
        let fileURL = trustStoreURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let encryptedData: Data
        do {
            encryptedData = try Data(contentsOf: fileURL)
        } catch {
            throw TrustStoreError.fileReadFailed(error)
        }
        let key = try getOrCreateTrustKey()
        let plaintext = try decrypt(encryptedData, key: key)
        let entries = try JSONDecoder().decode([String: TrustEntry].self, from: plaintext)
        return entries
    }

    private func saveEntries(_ entries: [String: TrustEntry]) throws {
        let key = try getOrCreateTrustKey()
        let plaintext: Data
        do {
            plaintext = try JSONEncoder().encode(entries)
        } catch {
            throw TrustStoreError.encryptionFailed
        }
        let encryptedData = try encrypt(plaintext, key: key)
        let fileURL = trustStoreURL()
        try ensureParentDirectory(for: fileURL)
        do {
            try encryptedData.write(to: fileURL, options: .atomic)
        } catch {
            throw TrustStoreError.fileWriteFailed(error)
        }
    }

    // -----------------------------------------------------------------------
    // Encryption (CryptoKit AES-256-GCM)
    // -----------------------------------------------------------------------

    private func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(plaintext, using: key)
            // combined: nonce + ciphertext + tag — self-contained for storage
            guard let combined = sealedBox.combined else {
                throw TrustStoreError.encryptionFailed
            }
            return combined
        } catch {
            throw TrustStoreError.encryptionFailed
        }
    }

    private func decrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw TrustStoreError.decryptionFailed
        }
    }

    // -----------------------------------------------------------------------
    // Trust encryption key (Keychain-backed)
    // -----------------------------------------------------------------------

    /// Returns the existing trust encryption key from Keychain, or generates
    /// a new 256-bit AES key and stores it in Keychain.
    ///
    /// This key is separate from the identity private keys in KeychainManager.
    /// Per Architecture Decision 18: "Trust metadata does not require hardware-backed
    /// key storage and benefits from simpler access patterns."
    private func getOrCreateTrustKey() throws -> SymmetricKey {
        // Try reading existing key
        if let keyData = keychainReadKey() {
            return SymmetricKey(data: keyData)
        }
        // Generate a new 256-bit key using CryptoKit (system CSPRNG)
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try keychainStoreKey(keyData)
        return newKey
    }

    private func keychainStoreKey(_ keyData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: TrustStore.keychainService,
            kSecAttrAccount as String: TrustStore.trustKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess { return }
        if addStatus == errSecDuplicateItem {
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: TrustStore.keychainService,
                kSecAttrAccount as String: TrustStore.trustKeyAccount,
            ]
            let updateAttr: [String: Any] = [kSecValueData as String: keyData]
            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttr as CFDictionary)
            if updateStatus == errSecSuccess { return }
            throw TrustStoreError.keychainKeyWriteFailed(updateStatus)
        }
        throw TrustStoreError.keychainKeyWriteFailed(addStatus)
    }

    private func keychainReadKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: TrustStore.keychainService,
            kSecAttrAccount as String: TrustStore.trustKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // -----------------------------------------------------------------------
    // File system
    // -----------------------------------------------------------------------

    private func trustStoreURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent(TrustStore.appSupportSubdir)
            .appendingPathComponent(TrustStore.trustFileName)
    }

    private func ensureParentDirectory(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
