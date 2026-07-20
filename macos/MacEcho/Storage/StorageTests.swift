// StorageTests.swift — Phase 9
//
// XCTest suite for the Phase 9 storage contract.
//
// What these tests verify (macOS runtime required — runs under xcodebuild test):
//   ✓ DeviceIdentity struct has no private key fields (structural).
//   ✓ TrustEntry struct has no private key fields (structural).
//   ✓ TrustStatus enum matches 04_SECURITY_MODEL.md (TRUSTED, REVOKED).
//   ✓ DeviceIdentity equality.
//   ✓ TrustEntry equality and Codable round-trip.
//   ✓ KeychainManager full lifecycle: generate → load → delete → regenerate.
//   ✓ KeychainManager.generateIdentity is idempotent (same key returned twice).
//   ✓ loadIdentity returns nil before first generate.
//   ✓ Private keys are never exposed in DeviceIdentity or through loadIdentity.
//   ✓ TrustStore full lifecycle: add → get → remove → clear.
//   ✓ TrustStore starts empty.
//   ✓ TrustStore round-trip preserves all fields.
//   ✓ TrustStore contains() and count().
//   ✓ Device identifier format: lowercased UUID-style string.
//
// Note: Tests that exercise the Keychain and file system require macOS runtime
// and will not pass on Linux or the iOS simulator.

import CryptoKit
import Foundation
import XCTest

@testable import MacEcho

final class StorageTests: XCTestCase {

    // -----------------------------------------------------------------------
    // Setup / teardown
    // -----------------------------------------------------------------------

    // Unique per-test KeychainManager so tests don't interfere.
    // KeystoreManager does NOT expose a test service injection in Phase 9,
    // so we clean up the real Keychain entries before and after each test.

    override func setUp() {
        super.setUp()
        // Clean state: delete any residual identity from a previous test
        try? KeychainManager().deleteIdentity()
    }

    override func tearDown() {
        super.tearDown()
        try? KeychainManager().deleteIdentity()
        // TrustStore: clear any leftover entries
        try? TrustStore().clear()
    }

    // -----------------------------------------------------------------------
    // 1. DeviceIdentity — structural contract
    // -----------------------------------------------------------------------

    func testDeviceIdentityHasNoPrivateKeyFields() {
        // Structural guarantee: DeviceIdentity must never contain private key fields.
        let mirror = Mirror(reflecting: DeviceIdentity(
            deviceId: "test",
            deviceName: "Test",
            deviceType: "MACOS",
            x25519PublicKey: Curve25519.KeyAgreement.PrivateKey().publicKey,
            ed25519PublicKey: Curve25519.Signing.PrivateKey().publicKey
        ))
        let fieldNames = mirror.children.compactMap { $0.label }
        let hasPrivateField = fieldNames.contains { name in
            name.lowercased().contains("private") || name.lowercased().contains("secret")
        }
        XCTAssertFalse(
            hasPrivateField,
            "DeviceIdentity must NEVER expose private key fields. Found: \(fieldNames)"
        )
    }

    func testDeviceIdentityEquality() {
        let privX = Curve25519.KeyAgreement.PrivateKey()
        let privE = Curve25519.Signing.PrivateKey()
        let a = DeviceIdentity(
            deviceId: "abc", deviceName: "A", deviceType: "MACOS",
            x25519PublicKey: privX.publicKey, ed25519PublicKey: privE.publicKey
        )
        let b = DeviceIdentity(
            deviceId: "abc", deviceName: "A", deviceType: "MACOS",
            x25519PublicKey: privX.publicKey, ed25519PublicKey: privE.publicKey
        )
        XCTAssertEqual(a, b, "Same-content DeviceIdentity values must be equal")
    }

    func testDeviceIdentityInequalityDifferentId() {
        let priv = Curve25519.KeyAgreement.PrivateKey()
        let sign = Curve25519.Signing.PrivateKey()
        let a = DeviceIdentity(deviceId: "X", deviceName: "N", deviceType: "MACOS",
                               x25519PublicKey: priv.publicKey, ed25519PublicKey: sign.publicKey)
        let b = DeviceIdentity(deviceId: "Y", deviceName: "N", deviceType: "MACOS",
                               x25519PublicKey: priv.publicKey, ed25519PublicKey: sign.publicKey)
        XCTAssertNotEqual(a, b, "Different deviceId must produce unequal identities")
    }

    // -----------------------------------------------------------------------
    // 2. TrustStatus — enum contract
    // -----------------------------------------------------------------------

    func testTrustStatusValues() {
        let cases = TrustStatus.allCases.map { $0.rawValue }
        XCTAssertTrue(cases.contains("TRUSTED"), "TrustStatus must have TRUSTED")
        XCTAssertTrue(cases.contains("REVOKED"), "TrustStatus must have REVOKED")
        XCTAssertEqual(2, cases.count, "TrustStatus must have exactly 2 values per Security Model")
    }

    func testTrustStatusCodableRoundTrip() throws {
        let trusted = TrustStatus.trusted
        let data = try JSONEncoder().encode(trusted)
        let decoded = try JSONDecoder().decode(TrustStatus.self, from: data)
        XCTAssertEqual(trusted, decoded)
    }

    // -----------------------------------------------------------------------
    // 3. TrustEntry — structural and Codable contract
    // -----------------------------------------------------------------------

    func testTrustEntryHasNoPrivateKeyFields() {
        let entry = makeTrustEntry(deviceId: "test")
        let mirror = Mirror(reflecting: entry)
        let fieldNames = mirror.children.compactMap { $0.label }
        let hasPrivate = fieldNames.contains { $0.lowercased().contains("private") }
        XCTAssertFalse(
            hasPrivate,
            "TrustEntry must NEVER store private key fields. Found: \(fieldNames)"
        )
    }

    func testTrustEntryContainsRequiredLocalTrustDatabaseFields() {
        // 04_SECURITY_MODEL.md §Local Trust Database requires all five field groups
        let entry = makeTrustEntry(deviceId: "test")
        let mirror = Mirror(reflecting: entry)
        let names = mirror.children.compactMap { $0.label }
        XCTAssertTrue(names.contains { $0.contains("DeviceId") || $0.contains("deviceId") }, "Must have trusted device ID")
        XCTAssertTrue(names.contains { $0.contains("25519") }, "Must have X25519 public key")
        XCTAssertTrue(names.contains { $0.contains("25519") }, "Must have Ed25519 public key")
        XCTAssertTrue(names.contains { $0.contains("Timestamp") || $0.contains("timestamp") }, "Must have pairing timestamp")
        XCTAssertTrue(names.contains { $0.contains("Status") || $0.contains("status") }, "Must have trust status")
        XCTAssertTrue(names.contains { $0.contains("Name") || $0.contains("name") }, "Must have device name")
        XCTAssertTrue(names.contains { $0.contains("Type") || $0.contains("type") }, "Must have device type")
    }

    func testTrustEntryCodableRoundTrip() throws {
        let original = makeTrustEntry(deviceId: "round-trip-test", status: .trusted, timestamp: 1_700_000_000_000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrustEntry.self, from: data)
        XCTAssertEqual(original, decoded, "TrustEntry must survive Codable round-trip unchanged")
    }

    func testTrustEntryEquality() {
        let a = makeTrustEntry(deviceId: "dev-1")
        let b = makeTrustEntry(deviceId: "dev-1")
        XCTAssertEqual(a, b, "Identical TrustEntries must be equal")
    }

    func testTrustEntryInequalityDifferentStatus() {
        let trusted = makeTrustEntry(deviceId: "dev", status: .trusted)
        let revoked = makeTrustEntry(deviceId: "dev", status: .revoked)
        XCTAssertNotEqual(trusted, revoked, "Different trust status must produce unequal entries")
    }

    // -----------------------------------------------------------------------
    // 4. KeychainManager lifecycle
    // -----------------------------------------------------------------------

    func testKeyChainManagerHasIdentityReturnsFalseBeforeGenerate() {
        let km = KeychainManager()
        XCTAssertFalse(km.hasIdentity(), "hasIdentity() must return false before generateIdentity() is called")
    }

    func testKeychainManagerLoadIdentityReturnsNilBeforeGenerate() throws {
        let km = KeychainManager()
        let identity = try km.loadIdentity()
        XCTAssertNil(identity, "loadIdentity() must return nil when no identity has been generated")
    }

    func testKeychainManagerGenerateIdentityReturnsPublicDataOnly() throws {
        let km = KeychainManager()
        let identity = try km.generateIdentity(deviceName: "Test Mac", deviceType: "MACOS")

        // Structural: verify returned identity has no private key properties
        let mirror = Mirror(reflecting: identity)
        let fieldNames = mirror.children.compactMap { $0.label }
        let hasPrivate = fieldNames.contains { $0.lowercased().contains("private") }
        XCTAssertFalse(hasPrivate, "generateIdentity must never return private keys. Fields: \(fieldNames)")
        XCTAssertFalse(identity.deviceId.isEmpty, "Device ID must be non-empty")
        XCTAssertEqual("Test Mac", identity.deviceName)
        XCTAssertEqual("MACOS", identity.deviceType)
    }

    func testKeychainManagerGenerateIsIdempotent() throws {
        let km = KeychainManager()
        let first = try km.generateIdentity(deviceName: "Test Mac", deviceType: "MACOS")
        let second = try km.generateIdentity(deviceName: "Test Mac", deviceType: "MACOS")
        // Must return SAME identity — keys generated only once
        XCTAssertEqual(first.deviceId, second.deviceId, "Device ID must be stable across calls")
        XCTAssertEqual(
            first.x25519PublicKey.rawRepresentation,
            second.x25519PublicKey.rawRepresentation,
            "X25519 public key must be stable — keys must NOT be regenerated"
        )
        XCTAssertEqual(
            first.ed25519PublicKey.rawRepresentation,
            second.ed25519PublicKey.rawRepresentation,
            "Ed25519 public key must be stable — keys must NOT be regenerated"
        )
    }

    func testKeychainManagerLoadReturnsSameIdentityAfterGenerate() throws {
        let km = KeychainManager()
        let generated = try km.generateIdentity(deviceName: "Test Mac", deviceType: "MACOS")
        let loaded = try km.loadIdentity()

        XCTAssertNotNil(loaded, "loadIdentity() must return identity after generateIdentity()")
        XCTAssertEqual(generated, loaded!, "Loaded identity must match generated identity")
    }

    func testKeychainManagerHasIdentityTrueAfterGenerate() throws {
        let km = KeychainManager()
        XCTAssertFalse(km.hasIdentity())
        _ = try km.generateIdentity(deviceName: "Test", deviceType: "MACOS")
        XCTAssertTrue(km.hasIdentity(), "hasIdentity() must return true after generateIdentity()")
    }

    func testKeychainManagerDeleteRemovesIdentity() throws {
        let km = KeychainManager()
        _ = try km.generateIdentity(deviceName: "Test", deviceType: "MACOS")
        XCTAssertTrue(km.hasIdentity())
        try km.deleteIdentity()
        XCTAssertFalse(km.hasIdentity(), "hasIdentity() must return false after deleteIdentity()")
        let loaded = try km.loadIdentity()
        XCTAssertNil(loaded, "loadIdentity() must return nil after deleteIdentity()")
    }

    func testKeychainManagerRegenerateAfterDelete() throws {
        let km = KeychainManager()
        let first = try km.generateIdentity(deviceName: "Test", deviceType: "MACOS")
        try km.deleteIdentity()
        let second = try km.generateIdentity(deviceName: "Test", deviceType: "MACOS")

        // After delete + regenerate, identity must be DIFFERENT (new key material)
        XCTAssertNotEqual(first.deviceId, second.deviceId, "Regenerated identity must have a new device ID")
        XCTAssertNotEqual(
            first.x25519PublicKey.rawRepresentation,
            second.x25519PublicKey.rawRepresentation,
            "Regenerated identity must have new X25519 key material"
        )
    }

    func testDeviceIdIsUUIDFormat() throws {
        let km = KeychainManager()
        let identity = try km.generateIdentity(deviceName: "Test", deviceType: "MACOS")
        // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (lowercase)
        let uuidPattern = try NSRegularExpression(pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        let range = NSRange(identity.deviceId.startIndex..., in: identity.deviceId)
        let matched = uuidPattern.firstMatch(in: identity.deviceId, range: range) != nil
        XCTAssertTrue(matched, "Device ID must match lowercase UUID v4 format. Got: \(identity.deviceId)")
    }

    // -----------------------------------------------------------------------
    // 5. TrustStore lifecycle
    // -----------------------------------------------------------------------

    func testTrustStoreStartsEmpty() {
        let store = TrustStore()
        XCTAssertTrue(store.getAll().isEmpty, "TrustStore must start empty")
        XCTAssertEqual(0, store.count(), "TrustStore count must be 0 when empty")
    }

    func testTrustStoreAddAndGet() throws {
        let store = TrustStore()
        let entry = makeTrustEntry(deviceId: "peer-device-1")
        try store.addOrUpdate(entry)

        let retrieved = store.get(deviceId: "peer-device-1")
        XCTAssertNotNil(retrieved, "get() must return entry after addOrUpdate()")
        XCTAssertEqual(entry, retrieved!, "Retrieved entry must match stored entry")
    }

    func testTrustStoreContains() throws {
        let store = TrustStore()
        XCTAssertFalse(store.contains(deviceId: "xyz"), "contains() must return false when entry is absent")
        try store.addOrUpdate(makeTrustEntry(deviceId: "xyz"))
        XCTAssertTrue(store.contains(deviceId: "xyz"), "contains() must return true after addOrUpdate()")
    }

    func testTrustStoreCount() throws {
        let store = TrustStore()
        XCTAssertEqual(0, store.count())
        try store.addOrUpdate(makeTrustEntry(deviceId: "a"))
        XCTAssertEqual(1, store.count())
        try store.addOrUpdate(makeTrustEntry(deviceId: "b"))
        XCTAssertEqual(2, store.count())
    }

    func testTrustStoreUpdateExistingEntry() throws {
        let store = TrustStore()
        try store.addOrUpdate(makeTrustEntry(deviceId: "peer", status: .trusted))
        XCTAssertEqual(.trusted, store.get(deviceId: "peer")?.trustStatus)

        try store.addOrUpdate(makeTrustEntry(deviceId: "peer", status: .revoked))
        XCTAssertEqual(.revoked, store.get(deviceId: "peer")?.trustStatus, "addOrUpdate must replace existing entry")
        XCTAssertEqual(1, store.count(), "Count must not increase on update")
    }

    func testTrustStoreGetAll() throws {
        let store = TrustStore()
        try store.addOrUpdate(makeTrustEntry(deviceId: "a"))
        try store.addOrUpdate(makeTrustEntry(deviceId: "b"))
        try store.addOrUpdate(makeTrustEntry(deviceId: "c"))
        XCTAssertEqual(3, store.getAll().count, "getAll() must return all 3 entries")
    }

    func testTrustStoreRemove() throws {
        let store = TrustStore()
        try store.addOrUpdate(makeTrustEntry(deviceId: "peer-1"))
        try store.addOrUpdate(makeTrustEntry(deviceId: "peer-2"))
        try store.remove(deviceId: "peer-1")
        XCTAssertNil(store.get(deviceId: "peer-1"), "Removed entry must not be retrievable")
        XCTAssertNotNil(store.get(deviceId: "peer-2"), "Non-removed entry must remain")
        XCTAssertEqual(1, store.count())
    }

    func testTrustStoreRemoveNonExistentIsIdempotent() {
        let store = TrustStore()
        // Must not throw when removing a non-existent entry
        XCTAssertNoThrow(try store.remove(deviceId: "does-not-exist"))
    }

    func testTrustStoreClear() throws {
        let store = TrustStore()
        try store.addOrUpdate(makeTrustEntry(deviceId: "a"))
        try store.addOrUpdate(makeTrustEntry(deviceId: "b"))
        try store.clear()
        XCTAssertTrue(store.getAll().isEmpty, "getAll() must be empty after clear()")
        XCTAssertEqual(0, store.count())
    }

    func testTrustStorePreservesAllFields() throws {
        let store = TrustStore()
        let x25519Data = Data(repeating: 0x42, count: 32)
        let ed25519Data = Data(repeating: 0x77, count: 32)
        let original = TrustEntry(
            trustedDeviceId: "full-field-test",
            trustedX25519PublicKeyData: x25519Data,
            trustedEd25519PublicKeyData: ed25519Data,
            pairingTimestampMs: 9_876_543_210_000,
            trustStatus: .revoked,
            deviceName: "Suyesh's MacBook Air",
            deviceType: "MACOS"
        )
        try store.addOrUpdate(original)
        let retrieved = store.get(deviceId: "full-field-test")!
        XCTAssertEqual(original.trustedDeviceId, retrieved.trustedDeviceId)
        XCTAssertEqual(original.trustedX25519PublicKeyData, retrieved.trustedX25519PublicKeyData)
        XCTAssertEqual(original.trustedEd25519PublicKeyData, retrieved.trustedEd25519PublicKeyData)
        XCTAssertEqual(original.pairingTimestampMs, retrieved.pairingTimestampMs)
        XCTAssertEqual(original.trustStatus, retrieved.trustStatus)
        XCTAssertEqual(original.deviceName, retrieved.deviceName)
        XCTAssertEqual(original.deviceType, retrieved.deviceType)
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private func makeTrustEntry(
        deviceId: String,
        status: TrustStatus = .trusted,
        timestamp: Int64 = 1_700_000_000_000
    ) -> TrustEntry {
        TrustEntry(
            trustedDeviceId: deviceId,
            trustedX25519PublicKeyData: Data(repeating: 0x01, count: 32),
            trustedEd25519PublicKeyData: Data(repeating: 0x02, count: 32),
            pairingTimestampMs: timestamp,
            trustStatus: status,
            deviceName: "Test Device",
            deviceType: "ANDROID"
        )
    }
}
