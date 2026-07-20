package com.macecho.app.protocol

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.util.UUID

/**
 * ReplayGuardTest.kt — Phase 11 unit tests
 *
 * Coverage:
 *   ✓ Fresh packet passes freshness check
 *   ✓ Packet timestamp too far in the future is rejected
 *   ✓ Packet timestamp too far in the past is rejected
 *   ✓ Packet exactly at clock-skew boundary passes
 *   ✓ Packet exactly one ms beyond boundary is rejected
 *   ✓ Duplicate UUID is rejected on second presentation
 *   ✓ First presentation of a UUID passes
 *   ✓ Distinct UUIDs are each accepted
 *   ✓ Cache evicts oldest entry when maxCachedPacketIds reached
 *   ✓ clearCache resets the duplicate tracker
 *   ✓ check() convenience method: stale timestamp reported before UUID check
 *   ✓ check() convenience method: duplicate UUID reported when timestamp is fresh
 *   ✓ markProcessed() causes subsequent duplicate detection
 *   ✓ cachedIdCount reflects actual cache size
 */
class ReplayGuardTest {

    private val fixedNow: Long = 1_700_000_000_000L // ms — arbitrary fixed point
    private lateinit var guard: ReplayGuard

    @Before
    fun setUp() {
        guard = ReplayGuard(
            config = ReplayGuardConfig(
                clockSkewToleranceMs = 30_000L,   // 30 seconds — test default
                maxCachedPacketIds = 5,
            ),
            currentTimeMs = { fixedNow },
        )
    }

    // -----------------------------------------------------------------------
    // Helper
    // -----------------------------------------------------------------------

    private fun packet(
        timestampMs: Long = fixedNow,
        packetId: String = UUID.randomUUID().toString(),
    ): Packet = Packet(
        header = PacketHeader(
            protocolVersion = 1,
            packetType = PacketType.HEARTBEAT,
            sessionId = UUID.randomUUID().toString(),
            senderId = "device-a",
            packetId = packetId,
            sequenceNumber = 1L,
            timestamp = timestampMs,
        ),
        metadata = PacketMetadata(0, PacketPriority.NORMAL, PacketType.HEARTBEAT),
        encryptedPayload = byteArrayOf(0x01),
    )

    // -----------------------------------------------------------------------
    // Freshness checks
    // -----------------------------------------------------------------------

    @Test
    fun freshTimestampPassesFreshnessCheck() {
        val result = guard.checkFreshnessOnly(packet(timestampMs = fixedNow))
        assertTrue("Expected Fresh", result is ReplayGuardResult.Fresh)
    }

    @Test
    fun timestampTooFarFutureFailsFreshness() {
        val future = fixedNow + 30_001L // one ms past tolerance
        val result = guard.checkFreshnessOnly(packet(timestampMs = future))
        assertTrue("Expected StaleTimestamp", result is ReplayGuardResult.StaleTimestamp)
    }

    @Test
    fun timestampTooFarPastFailsFreshness() {
        val past = fixedNow - 30_001L
        val result = guard.checkFreshnessOnly(packet(timestampMs = past))
        assertTrue("Expected StaleTimestamp", result is ReplayGuardResult.StaleTimestamp)
    }

    @Test
    fun timestampExactlyAtBoundaryPasses() {
        // skew == tolerance → should pass (|skew| <= tolerance)
        val atBoundary = fixedNow - 30_000L
        val result = guard.checkFreshnessOnly(packet(timestampMs = atBoundary))
        assertTrue("Expected Fresh at exact boundary", result is ReplayGuardResult.Fresh)
    }

    @Test
    fun timestampOneMillisecondBeyondBoundaryFails() {
        val justOver = fixedNow - 30_001L
        val result = guard.checkFreshnessOnly(packet(timestampMs = justOver))
        assertTrue("Expected StaleTimestamp one ms over boundary", result is ReplayGuardResult.StaleTimestamp)
    }

    @Test
    fun staleTimestampResultContainsCorrectFields() {
        val past = fixedNow - 60_000L
        val result = guard.checkFreshnessOnly(packet(timestampMs = past))
        assertTrue(result is ReplayGuardResult.StaleTimestamp)
        val stale = result as ReplayGuardResult.StaleTimestamp
        assertEquals(past, stale.packetTimestampMs)
        assertEquals(fixedNow, stale.nowMs)
        assertEquals(60_000L, stale.skewMs)
    }

    // -----------------------------------------------------------------------
    // Duplicate (UUID) checks
    // -----------------------------------------------------------------------

    @Test
    fun firstPresentationOfUuidPasses() {
        val id = UUID.randomUUID().toString()
        val result = guard.checkDuplicateOnly(packet(packetId = id))
        assertTrue("First presentation must be Fresh", result is ReplayGuardResult.Fresh)
    }

    @Test
    fun secondPresentationOfSameUuidFails() {
        val id = UUID.randomUUID().toString()
        guard.checkDuplicateOnly(packet(packetId = id))
        val result = guard.checkDuplicateOnly(packet(packetId = id))
        assertTrue("Duplicate must be rejected", result is ReplayGuardResult.DuplicatePacketId)
    }

    @Test
    fun distinctUuidsAreEachAccepted() {
        repeat(10) {
            val result = guard.checkDuplicateOnly(packet())
            assertTrue("Distinct UUID $it must be Fresh", result is ReplayGuardResult.Fresh)
        }
    }

    @Test
    fun duplicatePacketIdResultContainsId() {
        val id = UUID.randomUUID().toString()
        guard.checkDuplicateOnly(packet(packetId = id))
        val result = guard.checkDuplicateOnly(packet(packetId = id))
        assertEquals(id, (result as ReplayGuardResult.DuplicatePacketId).packetId)
    }

    // -----------------------------------------------------------------------
    // Cache eviction
    // -----------------------------------------------------------------------

    @Test
    fun cacheEvictsOldestWhenCapacityReached() {
        val ids = (1..5).map { UUID.randomUUID().toString() }
        ids.forEach { id -> guard.checkDuplicateOnly(packet(packetId = id)) }
        assertEquals(5, guard.cachedIdCount)

        // Add a 6th — should evict the first.
        val newId = UUID.randomUUID().toString()
        guard.checkDuplicateOnly(packet(packetId = newId))
        assertEquals(5, guard.cachedIdCount)

        // The first ID should now be forgotten (no longer in cache),
        // so presenting it again returns Fresh.
        val reuseResult = guard.checkDuplicateOnly(packet(packetId = ids[0]))
        assertTrue("Evicted ID should be accepted again", reuseResult is ReplayGuardResult.Fresh)
    }

    // -----------------------------------------------------------------------
    // clearCache
    // -----------------------------------------------------------------------

    @Test
    fun clearCacheResetsUuidTracker() {
        val id = UUID.randomUUID().toString()
        guard.checkDuplicateOnly(packet(packetId = id))
        guard.clearCache()
        assertEquals(0, guard.cachedIdCount)
        val result = guard.checkDuplicateOnly(packet(packetId = id))
        assertTrue("After clearCache ID must be Fresh again", result is ReplayGuardResult.Fresh)
    }

    // -----------------------------------------------------------------------
    // Convenience check()
    // -----------------------------------------------------------------------

    @Test
    fun checkConvenienceReturnsFreshForValidPacket() {
        val result = guard.check(packet())
        assertTrue(result is ReplayGuardResult.Fresh)
    }

    @Test
    fun checkConvenienceReportsStaleTimestampBeforeUuidCheck() {
        val id = UUID.randomUUID().toString()
        val result = guard.check(packet(timestampMs = fixedNow - 60_000L, packetId = id))
        assertTrue("Stale timestamp must short-circuit before UUID check", result is ReplayGuardResult.StaleTimestamp)
    }

    @Test
    fun checkConvenienceReportsDuplicateWhenTimestampFresh() {
        val id = UUID.randomUUID().toString()
        guard.check(packet(packetId = id))
        val result = guard.check(packet(packetId = id))
        assertTrue(result is ReplayGuardResult.DuplicatePacketId)
    }

    // -----------------------------------------------------------------------
    // markProcessed
    // -----------------------------------------------------------------------

    @Test
    fun markProcessedCausesSubsequentDuplicateDetection() {
        val id = UUID.randomUUID().toString()
        guard.markProcessed(id)
        val result = guard.checkDuplicateOnly(packet(packetId = id))
        assertTrue("markProcessed should cause duplicate detection", result is ReplayGuardResult.DuplicatePacketId)
    }

    // -----------------------------------------------------------------------
    // cachedIdCount
    // -----------------------------------------------------------------------

    @Test
    fun cachedIdCountReflectsActualCacheSize() {
        assertEquals(0, guard.cachedIdCount)
        guard.checkDuplicateOnly(packet())
        assertEquals(1, guard.cachedIdCount)
        guard.checkDuplicateOnly(packet())
        assertEquals(2, guard.cachedIdCount)
        guard.clearCache()
        assertEquals(0, guard.cachedIdCount)
    }
}
