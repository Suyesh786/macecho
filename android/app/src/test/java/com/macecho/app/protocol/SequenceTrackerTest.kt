package com.macecho.app.protocol

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.util.UUID

/**
 * SequenceTrackerTest.kt — Phase 11 unit tests
 *
 * Coverage:
 *   ✓ In-order packet is accepted and nextExpected advances
 *   ✓ First packet in session (seq=1) is accepted
 *   ✓ Stale packet (below nextExpected) is reported as Stale
 *   ✓ Duplicate (exact same sequence number already seen) is Stale
 *   ✓ Out-of-order future packet is buffered
 *   ✓ Buffered packet is released when missing predecessor arrives
 *   ✓ Multiple buffered packets released in order
 *   ✓ advanceTo skips a gap and releases buffered packets
 *   ✓ Buffer evicts oldest when capacity exceeded
 *   ✓ reset clears buffer and resets counters
 *   ✓ nextOutgoingSequenceNumber starts at 1 and increments
 *   ✓ checkStaleness does not modify state
 *   ✓ StaleSequenceNumber result contains correct fields
 */
class SequenceTrackerTest {

    private val sessionId = "test-session-${UUID.randomUUID()}"
    private lateinit var tracker: SequenceTracker

    @Before
    fun setUp() {
        tracker = SequenceTracker(
            sessionId = sessionId,
            config = SequenceTrackerConfig(
                maxBufferedPackets = 4,
                stalenessThreshold = 0L,
            ),
        )
    }

    // -----------------------------------------------------------------------
    // Helper
    // -----------------------------------------------------------------------

    private fun packet(seq: Long): Packet = Packet(
        header = PacketHeader(
            protocolVersion = 1,
            packetType = PacketType.HEARTBEAT,
            sessionId = sessionId,
            senderId = "device-a",
            packetId = UUID.randomUUID().toString(),
            sequenceNumber = seq,
            timestamp = System.currentTimeMillis(),
        ),
        metadata = PacketMetadata(0, PacketPriority.NORMAL, PacketType.HEARTBEAT),
        encryptedPayload = byteArrayOf(0x01),
    )

    // -----------------------------------------------------------------------
    // In-order
    // -----------------------------------------------------------------------

    @Test
    fun firstPacketInSessionIsAccepted() {
        val result = tracker.evaluate(packet(1L))
        assertTrue(result is SequenceCheckResult.InOrder)
        val inOrder = result as SequenceCheckResult.InOrder
        assertTrue("No buffered packets on first in-order", inOrder.releasedFromBuffer.isEmpty())
        assertEquals(2L, tracker.nextExpected)
    }

    @Test
    fun consecutiveInOrderPacketsAdvanceExpected() {
        repeat(5) { i ->
            val result = tracker.evaluate(packet(i.toLong() + 1L))
            assertTrue("Packet ${i + 1} should be in order", result is SequenceCheckResult.InOrder)
        }
        assertEquals(6L, tracker.nextExpected)
    }

    // -----------------------------------------------------------------------
    // Stale / duplicate by sequence number
    // -----------------------------------------------------------------------

    @Test
    fun sequenceNumberBelowNextExpectedIsStale() {
        tracker.evaluate(packet(1L)) // accept seq 1; nextExpected = 2
        val result = tracker.evaluate(packet(1L)) // replay of seq 1
        assertTrue("Replay must be Stale", result is SequenceCheckResult.Stale)
        val stale = result as SequenceCheckResult.Stale
        assertEquals(1L, stale.sequenceNumber)
        assertEquals(2L, stale.nextExpected)
    }

    @Test
    fun oldPacketFarBelowNextExpectedIsStale() {
        (1L..5L).forEach { tracker.evaluate(packet(it)) }
        val result = tracker.evaluate(packet(2L))
        assertTrue("Old packet must be Stale", result is SequenceCheckResult.Stale)
    }

    // -----------------------------------------------------------------------
    // Out-of-order buffering
    // -----------------------------------------------------------------------

    @Test
    fun futurePacketIsBuffered() {
        val result = tracker.evaluate(packet(3L)) // expecting 1, got 3
        assertTrue("Future packet must be Buffered", result is SequenceCheckResult.Buffered)
        assertEquals(3L, (result as SequenceCheckResult.Buffered).sequenceNumber)
        assertEquals(1, tracker.bufferedCount)
        assertEquals(1L, tracker.nextExpected) // NOT advanced
    }

    @Test
    fun missingPacketArrivalReleasesBuffer() {
        tracker.evaluate(packet(3L)) // buffer seq 3
        tracker.evaluate(packet(2L)) // buffer seq 2
        assertEquals(2, tracker.bufferedCount)

        val result = tracker.evaluate(packet(1L)) // fills the gap
        assertTrue(result is SequenceCheckResult.InOrder)
        val inOrder = result as SequenceCheckResult.InOrder
        // Should release seq 2 and seq 3 in order
        assertEquals(2, inOrder.releasedFromBuffer.size)
        assertEquals(2L, inOrder.releasedFromBuffer[0].header.sequenceNumber)
        assertEquals(3L, inOrder.releasedFromBuffer[1].header.sequenceNumber)
        assertEquals(4L, tracker.nextExpected)
        assertEquals(0, tracker.bufferedCount)
    }

    @Test
    fun chainedBufferReleaseWorksCorrectly() {
        (2L..5L).forEach { tracker.evaluate(packet(it)) } // all buffered
        assertEquals(4, tracker.bufferedCount)

        val result = tracker.evaluate(packet(1L))
        assertTrue(result is SequenceCheckResult.InOrder)
        val released = (result as SequenceCheckResult.InOrder).releasedFromBuffer
        assertEquals(4, released.size)
        assertEquals((2L..5L).toList(), released.map { it.header.sequenceNumber })
        assertEquals(6L, tracker.nextExpected)
        assertEquals(0, tracker.bufferedCount)
    }

    @Test
    fun sameSequenceNumberBufferedOnlyOnce() {
        tracker.evaluate(packet(5L))
        tracker.evaluate(packet(5L)) // duplicate future — should not double-buffer
        assertEquals(1, tracker.bufferedCount)
    }

    // -----------------------------------------------------------------------
    // Buffer capacity eviction
    // -----------------------------------------------------------------------

    @Test
    fun bufferEvictsOldestWhenFull() {
        // Buffer capacity = 4 (configured in setUp)
        (2L..5L).forEach { tracker.evaluate(packet(it)) }
        assertEquals(4, tracker.bufferedCount)

        // Adding seq 6 when at capacity evicts seq 2 (lowest).
        tracker.evaluate(packet(6L))
        assertEquals(4, tracker.bufferedCount)

        // Deliver seq 1. nextExpected becomes 2, but seq 2 was evicted —
        // the drain stops immediately because there is no seq 2 in the buffer.
        val result = tracker.evaluate(packet(1L))
        assertTrue("Expected InOrder for seq 1", result is SequenceCheckResult.InOrder)
        val released = (result as SequenceCheckResult.InOrder).releasedFromBuffer
        // No consecutive chain can start from 2 (evicted), so nothing is released.
        assertTrue("No chain can start without seq 2 (evicted)", released.isEmpty())
        // nextExpected is now 2 (stalled waiting for the evicted packet).
        assertEquals(2L, tracker.nextExpected)
        // The buffer still holds 3, 4, 5, 6.
        assertEquals(4, tracker.bufferedCount)
    }

    // -----------------------------------------------------------------------
    // advanceTo (recovery)
    // -----------------------------------------------------------------------

    @Test
    fun advanceToSkipsGapAndDrainsBuffer() {
        tracker.evaluate(packet(3L)) // buffer
        tracker.evaluate(packet(4L)) // buffer
        val released = tracker.advanceTo(3L)
        // nextExpected jumps to 3, drains 3 and 4
        assertEquals(listOf(3L, 4L), released.map { it.header.sequenceNumber })
        assertEquals(5L, tracker.nextExpected)
        assertEquals(0, tracker.bufferedCount)
    }

    @Test
    fun advanceToWithNoBufferedPacketsJustAdvances() {
        val released = tracker.advanceTo(10L)
        assertTrue(released.isEmpty())
        assertEquals(10L, tracker.nextExpected)
    }

    @Test
    fun advanceToLowerThanCurrentDoesNothing() {
        tracker.evaluate(packet(1L)) // nextExpected = 2
        tracker.evaluate(packet(2L)) // nextExpected = 3
        tracker.advanceTo(1L)
        assertEquals(3L, tracker.nextExpected)
    }

    // -----------------------------------------------------------------------
    // reset
    // -----------------------------------------------------------------------

    @Test
    fun resetClearsBufferAndResetsCounters() {
        tracker.evaluate(packet(1L))
        tracker.evaluate(packet(5L)) // buffered
        tracker.reset()
        assertEquals(1L, tracker.nextExpected)
        assertEquals(0, tracker.bufferedCount)
    }

    // -----------------------------------------------------------------------
    // Outgoing sequence number
    // -----------------------------------------------------------------------

    @Test
    fun outgoingSequenceNumberStartsAtOne() {
        assertEquals(1L, tracker.nextOutgoingSequenceNumber())
    }

    @Test
    fun outgoingSequenceNumberIncrementsEachCall() {
        assertEquals(1L, tracker.nextOutgoingSequenceNumber())
        assertEquals(2L, tracker.nextOutgoingSequenceNumber())
        assertEquals(3L, tracker.nextOutgoingSequenceNumber())
    }

    // -----------------------------------------------------------------------
    // checkStaleness (read-only for PacketValidator stage 8)
    // -----------------------------------------------------------------------

    @Test
    fun checkStalenessDoesNotModifyState() {
        tracker.evaluate(packet(1L)) // nextExpected = 2
        val before = tracker.nextExpected

        // Check stale on an old packet — should not change nextExpected
        tracker.checkStaleness(packet(1L))
        assertEquals(before, tracker.nextExpected)
    }

    @Test
    fun checkStalenessReturnsStaleBelowThreshold() {
        tracker.evaluate(packet(1L)) // nextExpected = 2
        val result = tracker.checkStaleness(packet(1L)) // seq 1 < nextExpected 2
        assertTrue(result is SequenceCheckResult.Stale)
    }

    @Test
    fun checkStalenessReturnsInOrderForCurrentAndFutureSeqs() {
        // For seq >= nextExpected, checkStaleness returns InOrder (not buffering)
        val result = tracker.checkStaleness(packet(1L))
        assertTrue(result is SequenceCheckResult.InOrder)
        val futureResult = tracker.checkStaleness(packet(99L))
        assertTrue(futureResult is SequenceCheckResult.InOrder)
    }
}
