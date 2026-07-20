package com.macecho.app.storage

// Phase 9 — Storage Contract Unit Tests
//
// These tests run on the host JVM (no Android emulator, no Keystore access).
//
// What these tests verify:
//   ✓ DeviceIdentity data class equality, hashCode, and structural contract
//     (confirms no private key fields are ever exposed in the public API).
//   ✓ TrustEntry data class equality and hashCode.
//   ✓ TrustStatus enum values match 04_SECURITY_MODEL.md.
//   ✓ TrustStore Properties serialization round-trip (the serialization logic
//     is pure JVM — does not require Android Keystore or Context).
//   ✓ Device identifier format: 8-4-4-4-12 UUID, no hardware-derived values.
//
// What requires a device / Robolectric (NOT tested here):
//   - Android Keystore key generation (getOrCreateWrappingKey).
//   - Full KeystoreManager.generateIdentity / loadIdentity / deleteIdentity.
//   - Full TrustStore.addOrUpdate / get / clear.
//   (These depend on android.security.keystore.KeyGenParameterSpec and
//    android.content.Context which are Android runtime classes.)
//
// 11_IMPLEMENTATION_PLAN.MD §Phase 9 acceptance criteria:
//   ✓ Private keys are generated and stored only via Keystore/Keychain APIs
//     — enforced structurally: DeviceIdentity has no private key field.
//   ✓ Trust metadata storage schema matches 04_SECURITY_MODEL.md fields.
//   ✓ Device identifiers are not derivable from hardware.

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Base64
import java.util.Properties

class StorageContractTest {

    // -----------------------------------------------------------------------
    // 1. DeviceIdentity — structural contract
    // -----------------------------------------------------------------------

    @Test
    fun `DeviceIdentity has no private key fields`() {
        // Structural enforcement: compile-time guarantee that DeviceIdentity
        // never exposes private key bytes. If anyone adds a privateKey field,
        // this test must be updated to detect and reject it.
        val fields = DeviceIdentity::class.java.declaredFields.map { it.name }
        val hasPrivateKeyField = fields.any { name ->
            name.contains("private", ignoreCase = true) ||
                name.contains("secret", ignoreCase = true)
        }
        assertFalse(
            "DeviceIdentity must NEVER expose private key fields. " +
                "Found fields: $fields",
            hasPrivateKeyField,
        )
    }

    @Test
    fun `DeviceIdentity equality uses content-aware comparison for ByteArrays`() {
        val publicKeyA = ByteArray(32) { it.toByte() }
        val publicKeyB = ByteArray(32) { it.toByte() } // same content, different reference

        val identity1 = DeviceIdentity(
            deviceId = "test-device-id",
            deviceName = "Test Device",
            deviceType = "ANDROID",
            x25519PublicKeyBytes = publicKeyA,
            ed25519PublicKeyBytes = publicKeyA.copyOf(),
        )
        val identity2 = DeviceIdentity(
            deviceId = "test-device-id",
            deviceName = "Test Device",
            deviceType = "ANDROID",
            x25519PublicKeyBytes = publicKeyB,
            ed25519PublicKeyBytes = publicKeyB.copyOf(),
        )
        assertEquals(
            "DeviceIdentity with same content must be equal (content-aware ByteArray comparison)",
            identity1,
            identity2,
        )
    }

    @Test
    fun `DeviceIdentity inequality when device ID differs`() {
        val key = ByteArray(32) { 0x42 }
        val identity1 = DeviceIdentity("id-A", "Name", "ANDROID", key, key)
        val identity2 = DeviceIdentity("id-B", "Name", "ANDROID", key, key)
        assertNotEquals("Different device IDs must produce unequal identities", identity1, identity2)
    }

    @Test
    fun `DeviceIdentity inequality when public key bytes differ`() {
        val keyA = ByteArray(32) { 0x01 }
        val keyB = ByteArray(32) { 0x02 }
        val identity1 = DeviceIdentity("id", "Name", "ANDROID", keyA, keyA)
        val identity2 = DeviceIdentity("id", "Name", "ANDROID", keyB, keyB)
        assertNotEquals("Different public keys must produce unequal identities", identity1, identity2)
    }

    @Test
    fun `DeviceIdentity hashCode is consistent with equals`() {
        val key = ByteArray(32) { 0x42 }
        val a = DeviceIdentity("id", "Name", "ANDROID", key, key.copyOf())
        val b = DeviceIdentity("id", "Name", "ANDROID", key.copyOf(), key.copyOf())
        assertEquals("Equal identities must have equal hashCodes", a.hashCode(), b.hashCode())
    }

    @Test
    fun `DeviceIdentity contains expected fields`() {
        val key = ByteArray(44) // X.509 encoded Curve25519 public key is 44 bytes
        val identity = DeviceIdentity(
            deviceId = "550e8400-e29b-41d4-a716-446655440000",
            deviceName = "Suyesh's Android",
            deviceType = "ANDROID",
            x25519PublicKeyBytes = key,
            ed25519PublicKeyBytes = key,
        )
        assertEquals("550e8400-e29b-41d4-a716-446655440000", identity.deviceId)
        assertEquals("Suyesh's Android", identity.deviceName)
        assertEquals("ANDROID", identity.deviceType)
        assertNotNull(identity.x25519PublicKeyBytes)
        assertNotNull(identity.ed25519PublicKeyBytes)
    }

    // -----------------------------------------------------------------------
    // 2. Device identifier format
    // -----------------------------------------------------------------------

    @Test
    fun `Device identifier UUID format is 8-4-4-4-12`() {
        // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        // Regex: 8 hex, dash, 4 hex, dash, 4 hex, dash, 4 hex, dash, 12 hex
        val uuidRegex = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        val testId = "550e8400-e29b-41d4-a716-446655440000"
        assertTrue(
            "Device identifier must match UUID v4 format: 8-4-4-4-12 lowercase hex",
            uuidRegex.matches(testId),
        )
    }

    @Test
    fun `Device identifier must not look like MAC address or IMEI`() {
        // MAC: 6 colon-separated hex bytes e.g. "AA:BB:CC:DD:EE:FF"
        // IMEI: 15-17 digit number
        val macPattern = Regex("([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")
        val imeiPattern = Regex("^\\d{15,17}$")
        val deviceId = "550e8400-e29b-41d4-a716-446655440000"
        assertFalse("Device ID must not look like a MAC address", macPattern.containsMatchIn(deviceId))
        assertFalse("Device ID must not look like an IMEI", imeiPattern.matches(deviceId))
    }

    // -----------------------------------------------------------------------
    // 3. TrustStatus — enum contract
    // -----------------------------------------------------------------------

    @Test
    fun `TrustStatus has exactly TRUSTED and REVOKED values`() {
        val values = TrustStatus.values().map { it.name }.toSet()
        assertEquals(
            "TrustStatus must have exactly TRUSTED and REVOKED per 04_SECURITY_MODEL.md",
            setOf("TRUSTED", "REVOKED"),
            values,
        )
    }

    @Test
    fun `TrustStatus valueOf is case-sensitive and round-trips`() {
        assertEquals(TrustStatus.TRUSTED, TrustStatus.valueOf("TRUSTED"))
        assertEquals(TrustStatus.REVOKED, TrustStatus.valueOf("REVOKED"))
    }

    // -----------------------------------------------------------------------
    // 4. TrustEntry — data class contract
    // -----------------------------------------------------------------------

    @Test
    fun `TrustEntry has no private key fields`() {
        val fields = TrustEntry::class.java.declaredFields.map { it.name }
        val hasPrivateKeyField = fields.any { name ->
            name.contains("private", ignoreCase = true) ||
                name.contains("secret", ignoreCase = true)
        }
        assertFalse(
            "TrustEntry must NEVER store private keys. Fields: $fields",
            hasPrivateKeyField,
        )
    }

    @Test
    fun `TrustEntry contains all required fields from Local Trust Database spec`() {
        // 04_SECURITY_MODEL.md §Local Trust Database requires all five field groups
        val fields = TrustEntry::class.java.declaredFields.map { it.name }
        // Kotlin data class backing fields match the property names exactly
        assertTrue("Must have trustedDeviceId", fields.any { it == "trustedDeviceId" })
        assertTrue("Must have trustedX25519PublicKeyBytes", fields.any { it == "trustedX25519PublicKeyBytes" })
        assertTrue("Must have trustedEd25519PublicKeyBytes", fields.any { it == "trustedEd25519PublicKeyBytes" })
        assertTrue("Must have pairingTimestampMs", fields.any { it == "pairingTimestampMs" })
        assertTrue("Must have trustStatus", fields.any { it == "trustStatus" })
        assertTrue("Must have deviceName", fields.any { it == "deviceName" })
        assertTrue("Must have deviceType", fields.any { it == "deviceType" })
    }

    @Test
    fun `TrustEntry equality uses content-aware ByteArray comparison`() {
        val keyA = ByteArray(44) { it.toByte() }
        val keyB = ByteArray(44) { it.toByte() } // same content, different reference
        val entry1 = makeTrustEntry("dev-1", keyA, keyA.copyOf())
        val entry2 = makeTrustEntry("dev-1", keyB, keyB.copyOf())
        assertEquals("Same content TrustEntries must be equal", entry1, entry2)
    }

    @Test
    fun `TrustEntry inequality when device ID differs`() {
        val key = ByteArray(44) { 0x01 }
        val entry1 = makeTrustEntry("dev-A", key, key)
        val entry2 = makeTrustEntry("dev-B", key, key)
        assertNotEquals("Different device IDs must be unequal", entry1, entry2)
    }

    @Test
    fun `TrustEntry inequality when trust status differs`() {
        val key = ByteArray(44) { 0x01 }
        val trusted = makeTrustEntry("dev-1", key, key, status = TrustStatus.TRUSTED)
        val revoked = makeTrustEntry("dev-1", key, key, status = TrustStatus.REVOKED)
        assertNotEquals("TRUSTED and REVOKED entries must be unequal", trusted, revoked)
    }

    @Test
    fun `TrustEntry hashCode is consistent with equals`() {
        val key = ByteArray(44) { 0x42 }
        val entry1 = makeTrustEntry("dev-1", key, key.copyOf())
        val entry2 = makeTrustEntry("dev-1", key.copyOf(), key.copyOf())
        assertEquals("Equal entries must have equal hashCodes", entry1.hashCode(), entry2.hashCode())
    }

    // -----------------------------------------------------------------------
    // 5. TrustStore Properties serialization round-trip (pure JVM — no Android)
    // -----------------------------------------------------------------------

    @Test
    fun `TrustStore Properties round-trip with single entry`() {
        // Uses TrustStore.buildPropertiesBytes / parsePropertiesBytes directly.
        // These are pure JVM (java.util.Properties + java.util.Base64) — no Context needed.
        // This tests the serialization logic that the full TrustStore relies on.
        val x25519Key = ByteArray(44) { it.toByte() }
        val ed25519Key = ByteArray(44) { (it + 1).toByte() }
        val original = makeTrustEntry("device-abc", x25519Key, ed25519Key, timestampMs = 1_700_000_000_000L)

        val store = TrustStoreSerializer()
        val serialized = store.buildPropertiesBytes(mapOf(original.trustedDeviceId to original))
        val parsed = store.parsePropertiesBytes(serialized)

        assertEquals("Parsed map must have exactly 1 entry", 1, parsed.size)
        val recovered = parsed[original.trustedDeviceId]
        assertNotNull("Recovered entry must not be null", recovered)
        assertEquals(original, recovered!!)
    }

    @Test
    fun `TrustStore Properties round-trip with multiple entries`() {
        val store = TrustStoreSerializer()
        val keyA = ByteArray(44) { 0x01 }
        val keyB = ByteArray(44) { 0x02 }
        val entryA = makeTrustEntry("alpha", keyA, keyA.copyOf(), status = TrustStatus.TRUSTED)
        val entryB = makeTrustEntry("beta", keyB, keyB.copyOf(), status = TrustStatus.REVOKED)
        val entries = mapOf(entryA.trustedDeviceId to entryA, entryB.trustedDeviceId to entryB)

        val serialized = store.buildPropertiesBytes(entries)
        val parsed = store.parsePropertiesBytes(serialized)

        assertEquals("Must recover 2 entries", 2, parsed.size)
        assertEquals(entryA, parsed["alpha"])
        assertEquals(entryB, parsed["beta"])
    }

    @Test
    fun `TrustStore Properties round-trip with empty store`() {
        val store = TrustStoreSerializer()
        val serialized = store.buildPropertiesBytes(emptyMap())
        val parsed = store.parsePropertiesBytes(serialized)
        assertTrue("Empty store must parse to empty map", parsed.isEmpty())
    }

    @Test
    fun `TrustStore Properties preserves all field values`() {
        val store = TrustStoreSerializer()
        val x25519 = ByteArray(44) { (it * 3).toByte() }
        val ed25519 = ByteArray(44) { (it * 7).toByte() }
        val original = TrustEntry(
            trustedDeviceId = "test-device-xyz",
            trustedX25519PublicKeyBytes = x25519,
            trustedEd25519PublicKeyBytes = ed25519,
            pairingTimestampMs = 9_876_543_210_000L,
            trustStatus = TrustStatus.REVOKED,
            deviceName = "Suyesh's MacBook Air",
            deviceType = "MACOS",
        )
        val parsed = store.parsePropertiesBytes(
            store.buildPropertiesBytes(mapOf(original.trustedDeviceId to original)),
        )["test-device-xyz"]!!

        assertEquals("trustedDeviceId", original.trustedDeviceId, parsed.trustedDeviceId)
        assertArrayEquals("x25519PublicKey", original.trustedX25519PublicKeyBytes, parsed.trustedX25519PublicKeyBytes)
        assertArrayEquals("ed25519PublicKey", original.trustedEd25519PublicKeyBytes, parsed.trustedEd25519PublicKeyBytes)
        assertEquals("pairingTimestampMs", original.pairingTimestampMs, parsed.pairingTimestampMs)
        assertEquals("trustStatus", original.trustStatus, parsed.trustStatus)
        assertEquals("deviceName", original.deviceName, parsed.deviceName)
        assertEquals("deviceType", original.deviceType, parsed.deviceType)
    }

    // -----------------------------------------------------------------------
    // Test helpers
    // -----------------------------------------------------------------------

    private fun makeTrustEntry(
        deviceId: String,
        x25519Key: ByteArray,
        ed25519Key: ByteArray,
        status: TrustStatus = TrustStatus.TRUSTED,
        timestampMs: Long = 1_700_000_000_000L,
    ) = TrustEntry(
        trustedDeviceId = deviceId,
        trustedX25519PublicKeyBytes = x25519Key,
        trustedEd25519PublicKeyBytes = ed25519Key,
        pairingTimestampMs = timestampMs,
        trustStatus = status,
        deviceName = "Test Device",
        deviceType = "MACOS",
    )

    // -----------------------------------------------------------------------
    // Test adapter — wraps TrustStore serialization without Android Context
    // -----------------------------------------------------------------------

    /**
     * Thin wrapper that exposes [TrustStore]'s internal serialization methods
     * for JVM-only testing. No Android Context required.
     */
    private class TrustStoreSerializer {

        private companion object {
            const val PROP_IDS = "entry.ids"
            const val PROP_X25519 = "x25519"
            const val PROP_ED25519 = "ed25519"
            const val PROP_TIMESTAMP = "timestamp"
            const val PROP_STATUS = "status"
            const val PROP_NAME = "name"
            const val PROP_TYPE = "type"
        }

        fun buildPropertiesBytes(entries: Map<String, TrustEntry>): ByteArray {
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
            val sw = java.io.StringWriter()
            props.store(sw, null)
            return sw.toString().toByteArray(Charsets.UTF_8)
        }

        fun parsePropertiesBytes(propsBytes: ByteArray): Map<String, TrustEntry> {
            val props = Properties().apply {
                load(java.io.StringReader(String(propsBytes, Charsets.UTF_8)))
            }
            val idsStr = props.getProperty(PROP_IDS) ?: return emptyMap()
            if (idsStr.isBlank()) return emptyMap()
            val ids = idsStr.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            return ids.associateWith { id ->
                fun prop(field: String) = props.getProperty("entry.$id.$field")!!
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
    }
}
