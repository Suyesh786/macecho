// KeychainManager.swift — Phase 9
//
// Provides Apple Keychain-backed storage for the device's long-term
// cryptographic identity (X25519 key exchange pair + Ed25519 signing pair
// + cryptographically random device identifier).
//
// Per Architecture Decision 18 and 04_SECURITY_MODEL.md §Secure Storage:
//   "macOS uses the Apple Keychain for private keys."
//
// Private keys are stored as kSecClassGenericPassword items in the system
// Keychain using the Security framework. They are retrieved by account name
// and never placed in UserDefaults, plain files, or logs.
//
// Private Key Exposure Rules:
//   - DeviceIdentity never contains private key objects.
//   - loadIdentity() reconstructs the public identity without decrypting
//     private keys (public keys are derived during generation and stored
//     separately in Keychain for fast access).
//   - sign() and deriveSharedSecret() decrypt private keys transiently
//     inside the function scope and never return them.
//
// Device Identifier:
//   Generated as a Version-4 UUID using Foundation's UUID() which on Apple
//   platforms uses SecRandomCopyBytes — the system CSPRNG.
//   NOT derived from: MAC address, IMEI, Android ID, Apple hardware ID,
//   email, phone number, or IP address — per 04_SECURITY_MODEL.md §Device Identifier.
//
// Must NOT contain:
//   - Authentication logic       → Phase 13
//   - Pairing logic              → Phase 12
//   - Transport                  → Phase 7
//   - Session management         → Phase 13
//   - TrustStore management      → TrustStore.swift
//   - AppKit, NSView, menu bar code
//   - Business logic of any kind
//
// Keychain service: "com.macecho.app.identity"
// Items stored (kSecClassGenericPassword):
//   "identity.x25519.private"  — X25519 private key raw representation (32 bytes)
//   "identity.x25519.public"   — X25519 public key raw representation (32 bytes)
//   "identity.ed25519.private" — Ed25519 private key raw representation (32 bytes)
//   "identity.ed25519.public"  — Ed25519 public key raw representation (32 bytes)
//   "identity.deviceId"        — Device UUID string as UTF-8 Data
//   "identity.deviceName"      — Device name as UTF-8 Data
//   "identity.deviceType"      — Device type string as UTF-8 Data

import CryptoKit
import Foundation
import Security

// ---------------------------------------------------------------------------
// DeviceIdentity — public-facing view of the device's cryptographic identity
// ---------------------------------------------------------------------------

/// The public, non-sensitive portion of the device's cryptographic identity.
///
/// Private keys are NEVER included in this struct. They remain in the system
/// Keychain and are only accessed transiently within `KeychainManager` for
/// internal cryptographic operations.
///
/// Per `04_SECURITY_MODEL.md §Device Identity`, the identity consists of:
/// Device Identifier, Device Name, Device Type, and the Cryptographic Public Key.
struct DeviceIdentity: Equatable {
    /// Version-4 UUID, generated from the system CSPRNG via `UUID()`.
    let deviceId: String
    /// Human-readable label (e.g. "Suyesh's MacBook Air").
    let deviceName: String
    /// Platform string (e.g. "MACOS").
    let deviceType: String
    /// X25519 public key (Curve25519 key agreement). Raw representation is 32 bytes.
    let x25519PublicKey: Curve25519.KeyAgreement.PublicKey
    /// Ed25519 public key (Curve25519 signing). Raw representation is 32 bytes.
    let ed25519PublicKey: Curve25519.Signing.PublicKey

    static func == (lhs: DeviceIdentity, rhs: DeviceIdentity) -> Bool {
        lhs.deviceId == rhs.deviceId &&
        lhs.deviceName == rhs.deviceName &&
        lhs.deviceType == rhs.deviceType &&
        lhs.x25519PublicKey.rawRepresentation == rhs.x25519PublicKey.rawRepresentation &&
        lhs.ed25519PublicKey.rawRepresentation == rhs.ed25519PublicKey.rawRepresentation
    }
}

// ---------------------------------------------------------------------------
// KeychainManager errors
// ---------------------------------------------------------------------------

/// Errors that can occur during Keychain identity operations.
enum KeychainManagerError: Error, LocalizedError {
    case keychainWriteFailed(OSStatus)
    case keychainReadFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case invalidKeyData
    case identityIncomplete

    var errorDescription: String? {
        switch self {
        case .keychainWriteFailed(let status):
            return "Keychain write failed with OSStatus \(status)"
        case .keychainReadFailed(let status):
            return "Keychain read failed with OSStatus \(status)"
        case .keychainDeleteFailed(let status):
            return "Keychain delete failed with OSStatus \(status)"
        case .invalidKeyData:
            return "Stored key data cannot be used to reconstruct a valid CryptoKit key"
        case .identityIncomplete:
            return "One or more identity fields are missing from Keychain"
        }
    }
}

// ---------------------------------------------------------------------------
// KeychainManager
// ---------------------------------------------------------------------------

/// Manages the device's long-term cryptographic identity using the Apple Keychain.
///
/// Identity lifecycle:
///   1. `generateIdentity` — creates key pairs + device ID, stores in Keychain.
///      If an identity already exists, returns the existing identity without
///      modification (keys generated only once, reused on subsequent calls).
///   2. `loadIdentity` — returns public identity data. Returns nil when absent.
///   3. `deleteIdentity` — removes all identity items from Keychain.
///   4. `hasIdentity` — non-destructive existence check.
struct KeychainManager {

    // Keychain service name — all identity items use this service
    private static let service = "com.macecho.app.identity"

    // Keychain account names for each stored item
    private enum Account: String, CaseIterable {
        case x25519Private  = "identity.x25519.private"
        case x25519Public   = "identity.x25519.public"
        case ed25519Private = "identity.ed25519.private"
        case ed25519Public  = "identity.ed25519.public"
        case deviceId       = "identity.deviceId"
        case deviceName     = "identity.deviceName"
        case deviceType     = "identity.deviceType"
    }

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Returns `true` if a stored identity exists in the Keychain.
    func hasIdentity() -> Bool {
        keychainRead(account: .deviceId) != nil
    }

    /// Returns the stored device identity if it exists, otherwise generates
    /// a new one, persists it in Keychain, and returns it.
    ///
    /// Keys are generated only when absent. Calling this multiple times
    /// returns the same identity without regenerating key material.
    ///
    /// - Parameters:
    ///   - deviceName: Human-readable label (e.g. "Suyesh's MacBook Air").
    ///   - deviceType: Platform string (e.g. "MACOS").
    /// - Returns: `DeviceIdentity` (public data only — private keys not returned).
    /// - Throws: `KeychainManagerError` if a Keychain write fails.
    func generateIdentity(
        deviceName: String,
        deviceType: String
    ) throws -> DeviceIdentity {
        if let existing = try? loadIdentity() {
            return existing
        }
        return try createAndPersistIdentity(deviceName: deviceName, deviceType: deviceType)
    }

    /// Loads and returns the stored device identity.
    ///
    /// Only public data is returned. Private keys are not read from Keychain
    /// during this call — the stored public key raw representations are read
    /// directly for fast access without private key decryption.
    ///
    /// - Returns: `DeviceIdentity` or `nil` if no identity has been generated.
    /// - Throws: `KeychainManagerError.invalidKeyData` if stored key data is corrupt.
    func loadIdentity() throws -> DeviceIdentity? {
        guard let deviceIdData = keychainRead(account: .deviceId),
              let deviceId = String(data: deviceIdData, encoding: .utf8),
              let deviceNameData = keychainRead(account: .deviceName),
              let deviceName = String(data: deviceNameData, encoding: .utf8),
              let deviceTypeData = keychainRead(account: .deviceType),
              let deviceType = String(data: deviceTypeData, encoding: .utf8),
              let x25519PublicData = keychainRead(account: .x25519Public),
              let ed25519PublicData = keychainRead(account: .ed25519Public)
        else {
            return nil
        }
        do {
            let x25519PublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: x25519PublicData)
            let ed25519PublicKey = try Curve25519.Signing.PublicKey(rawRepresentation: ed25519PublicData)
            return DeviceIdentity(
                deviceId: deviceId,
                deviceName: deviceName,
                deviceType: deviceType,
                x25519PublicKey: x25519PublicKey,
                ed25519PublicKey: ed25519PublicKey
            )
        } catch {
            throw KeychainManagerError.invalidKeyData
        }
    }

    /// Deletes all identity items from the Keychain.
    ///
    /// After deletion: `hasIdentity()` returns false. Calling `generateIdentity`
    /// produces a completely new identity (new device ID, new key pairs).
    /// The previous trust relationship with paired devices is permanently lost.
    ///
    /// Safe to call when no identity exists (idempotent).
    func deleteIdentity() throws {
        for account in Account.allCases {
            try keychainDelete(account: account)
        }
    }

    // -----------------------------------------------------------------------
    // Internal operations — reserved for Phase 13 (authentication)
    // Not yet called from any application flow.
    // -----------------------------------------------------------------------

    /// Signs `data` using the stored Ed25519 private key.
    ///
    /// The private key is loaded from Keychain transiently inside this function
    /// and is never returned. The CryptoKit `PrivateKey` object goes out of
    /// scope at function end, triggering CryptoKit's secure cleanup.
    ///
    /// Reserved for Phase 13 (authentication). Not yet wired to any flow.
    ///
    /// - Returns: 64-byte Ed25519 signature, or nil if no identity is stored.
    internal func sign(data: Data) throws -> Data? {
        guard let privateKeyData = keychainRead(account: .ed25519Private) else { return nil }
        do {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
            // privateKey goes out of scope after this return — CryptoKit handles cleanup
            return try privateKey.signature(for: data)
        } catch {
            throw KeychainManagerError.invalidKeyData
        }
    }

    /// Derives an X25519 shared secret with a peer's public key.
    ///
    /// The private key is loaded from Keychain transiently and never returned.
    /// Pass the result immediately to HKDF and allow the reference to go
    /// out of scope.
    ///
    /// Reserved for Phase 13 (authentication). Not yet wired to any flow.
    ///
    /// - Parameter peerPublicKeyData: Peer's X25519 public key raw representation (32 bytes).
    /// - Returns: `SharedSecret` or nil if no identity is stored.
    internal func deriveSharedSecret(peerPublicKeyData: Data) throws -> SharedSecret? {
        guard let privateKeyData = keychainRead(account: .x25519Private) else { return nil }
        do {
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
            let peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKeyData)
            // privateKey goes out of scope after this return
            return try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
        } catch {
            throw KeychainManagerError.invalidKeyData
        }
    }

    // -----------------------------------------------------------------------
    // Private implementation
    // -----------------------------------------------------------------------

    private func createAndPersistIdentity(
        deviceName: String,
        deviceType: String
    ) throws -> DeviceIdentity {
        // Generate device identifier — UUID() uses SecRandomCopyBytes on Apple platforms.
        // NOT derived from: MAC, IMEI, Android ID, hardware, email, phone, IP address.
        let deviceId = UUID().uuidString.lowercased()

        // Generate X25519 and Ed25519 key pairs.
        // CryptoKit uses system CSPRNG internally for key generation.
        let x25519PrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let ed25519PrivateKey = Curve25519.Signing.PrivateKey()

        // Store all items in Keychain.
        // Private keys stored as rawRepresentation (32-byte scalar).
        // kSecAttrAccessibleWhenUnlockedThisDeviceOnly: keys accessible only
        // when device is unlocked; never migrate to another device (iCloud/backup).
        try keychainStore(
            x25519PrivateKey.rawRepresentation,
            account: .x25519Private
        )
        try keychainStore(
            x25519PrivateKey.publicKey.rawRepresentation,
            account: .x25519Public
        )
        try keychainStore(
            ed25519PrivateKey.rawRepresentation,
            account: .ed25519Private
        )
        try keychainStore(
            ed25519PrivateKey.publicKey.rawRepresentation,
            account: .ed25519Public
        )
        try keychainStore(
            Data(deviceId.utf8),
            account: .deviceId
        )
        try keychainStore(
            Data(deviceName.utf8),
            account: .deviceName
        )
        try keychainStore(
            Data(deviceType.utf8),
            account: .deviceType
        )

        // Private key objects go out of scope here — CryptoKit zeroes them
        return DeviceIdentity(
            deviceId: deviceId,
            deviceName: deviceName,
            deviceType: deviceType,
            x25519PublicKey: x25519PrivateKey.publicKey,
            ed25519PublicKey: ed25519PrivateKey.publicKey
        )
    }

    // -----------------------------------------------------------------------
    // Keychain CRUD — low-level Security framework wrappers
    // -----------------------------------------------------------------------

    private func keychainStore(_ data: Data, account: Account) throws {
        // First attempt: add new item
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess { return }

        // If item already exists, update it
        if addStatus == errSecDuplicateItem {
            let searchQuery = baseQuery(account: account)
            let updateAttributes: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
            if updateStatus == errSecSuccess { return }
            throw KeychainManagerError.keychainWriteFailed(updateStatus)
        }

        throw KeychainManagerError.keychainWriteFailed(addStatus)
    }

    private func keychainRead(account: Account) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func keychainDelete(account: Account) throws {
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound is acceptable (idempotent delete)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainManagerError.keychainDeleteFailed(status)
        }
    }

    private func baseQuery(account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainManager.service,
            kSecAttrAccount as String: account.rawValue,
            // Ensure keys are NOT synchronized to iCloud — private keys must
            // never leave the originating device (04_SECURITY_MODEL.md §Private Keys)
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]
    }
}


