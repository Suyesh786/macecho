package com.macecho.app.protocol

/**
 * SequenceTracker.kt — Phase 11
 *
 * Implements the sequence-number half of Stage 8 (Duplicate Detection /
 * Packet Ordering) of the packet validation pipeline defined in
 * 07_PROTOCOL_SPECIFICATION.md.
 *
 * Specification rules implemented:
 *
 *   §Sequence Numbers:
 *     "Sequence numbers are scoped to an individual communication session."
 *     "The sequence number starts at 1 per session."
 *     "Every outgoing packet increments the sequence number."
 *
 *   §Packet Ordering:
 *     "Packets should be processed in their intended logical order whenever
 *      ordering affects application behavior."
 *
 *   §Out-of-Order Packets:
 *     "Out-of-order packets are buffered temporarily until the missing
 *      sequence numbers arrive or recovery rules apply."
 *     "Safety always takes priority over speed."
 *
 *   §Duplicate Detection:
 *     "Duplicate packets, identified by Packet UUID or stale Session
 *      Sequence Number, are ignored."
 *
 *   §Recovery Philosophy:
 *     "Recovering quickly is less important than recovering correctly."
 *
 * Design:
 *   - [SequenceTracker] is per-session: one instance per active session.
 *   - The tracker maintains [nextExpected]: the sequence number the tracker
 *     expects to process next.
 *   - Packets with sequence numbers *below* [nextExpected] are stale.
 *   - Packets with sequence numbers *equal to* [nextExpected] are processed
 *     in order; afterwards buffered future packets may be drained.
 *   - Packets with sequence numbers *above* [nextExpected] are buffered.
 *   - The tracker is responsible for ordering validation only; it does NOT
 *     verify authentication, trust, or payload integrity.
 *
 * Must NOT contain:
 *   - Authentication logic     → Phase 12+
 *   - Trust validation         → Phase 12+
 *   - Decryption               → Phase 12+
 *   - Business logic
 *
 * ─── CONFIGURABLE PARAMETERS ───────────────────────────────────────────────
 * The protocol specification does not mandate numeric values for:
 *   • Maximum out-of-order buffer size
 *   • Staleness window (how far behind is "stale" vs "duplicate")
 * Both are configurable. The defaults are implementation defaults only.
 * ────────────────────────────────────────────────────────────────────────────
 */

/**
 * Configuration for [SequenceTracker].
 *
 * @property maxBufferedPackets
 *   Maximum number of future (out-of-order) packets held in the buffer
 *   simultaneously. Once the limit is reached the lowest-sequence buffered
 *   packet is evicted to make room. The protocol does not mandate a size.
 *   Default: 64 — implementation default only.
 *
 * @property stalenessThreshold
 *   A packet whose sequence number is strictly less than
 *   (nextExpected - stalenessThreshold) is considered a replay / stale
 *   duplicate rather than a recoverable out-of-order packet. Set to 0 to
 *   treat every packet below [nextExpected] as stale immediately.
 *   Default: 0 — implementation default only.
 */
data class SequenceTrackerConfig(
    val maxBufferedPackets: Int = DEFAULT_MAX_BUFFERED_PACKETS,
    val stalenessThreshold: Long = DEFAULT_STALENESS_THRESHOLD,
) {
    companion object {
        /**
         * Implementation default for the out-of-order buffer capacity.
         * NOT a protocol requirement — override via [SequenceTrackerConfig].
         */
        const val DEFAULT_MAX_BUFFERED_PACKETS: Int = 64

        /**
         * Implementation default for the staleness threshold.
         * NOT a protocol requirement — override via [SequenceTrackerConfig].
         */
        const val DEFAULT_STALENESS_THRESHOLD: Long = 0L
    }
}

/**
 * Outcome of a [SequenceTracker] evaluation for a single packet.
 */
sealed class SequenceCheckResult {
    /**
     * Packet is next in order and may be processed immediately.
     * [releasedFromBuffer] contains any previously buffered packets (in
     * ascending sequence order) that are now also ready to process.
     */
    data class InOrder(val releasedFromBuffer: List<Packet>) : SequenceCheckResult()

    /**
     * Packet arrived before its predecessor(s). The packet has been placed
     * into the temporary buffer per §Out-of-Order Packets.
     */
    data class Buffered(val sequenceNumber: Long) : SequenceCheckResult()

    /**
     * Packet's sequence number is below the staleness threshold.
     * Per §Duplicate Detection: ignored; command not re-executed.
     */
    data class Stale(val sequenceNumber: Long, val nextExpected: Long) : SequenceCheckResult()
}

/**
 * Tracks per-session packet ordering and maintains a temporary buffer for
 * out-of-order packets.
 *
 * Lifecycle: one [SequenceTracker] per communication session. Discard on
 * session end; never reuse across sessions.
 *
 * Thread-safety: NOT thread-safe. External synchronization required if shared
 * across threads.
 *
 * @param sessionId  Identifier of the session this tracker belongs to.
 *                   Informational; used in toString / logging only.
 * @param config     Configurable parameters.
 */
class SequenceTracker(
    val sessionId: String,
    private val config: SequenceTrackerConfig = SequenceTrackerConfig(),
) {

    /**
     * The next sequence number this tracker expects to receive.
     * Starts at 1 per §Sequence Numbers: "The sequence number starts at 1
     * per session."
     */
    var nextExpected: Long = 1L
        private set

    /**
     * The sequence counter used when *sending* packets from this session.
     * Starts at 1 and increments on every outgoing packet per §Sequence
     * Numbers: "Every outgoing packet increments the sequence number."
     */
    private var nextOutgoing: Long = 1L

    /**
     * Checks whether [packet] has a stale sequence number WITHOUT performing
     * buffering. Use this from [PacketValidator] at Stage 8.
     *
     * Returns [SequenceCheckResult.Stale] if the sequence number is below the
     * staleness threshold. Returns [SequenceCheckResult.InOrder] (with an empty
     * released list) for all non-stale sequence numbers (including future ones —
     * buffering is not the responsibility of the validator stage).
     */
    fun checkStaleness(packet: Packet): SequenceCheckResult {
        val seq = packet.header.sequenceNumber
        return if (seq < nextExpected - config.stalenessThreshold) {
            SequenceCheckResult.Stale(seq, nextExpected)
        } else {
            SequenceCheckResult.InOrder(emptyList())
        }
    }

    /**
     * Buffer for future (out-of-order) packets awaiting their turn.
     * Keyed by sequence number for O(1) lookup and sorted iteration.
     */
    private val buffer: java.util.TreeMap<Long, Packet> = java.util.TreeMap()

    // -----------------------------------------------------------------------
    // Outgoing
    // -----------------------------------------------------------------------

    /**
     * Returns the next outgoing sequence number and advances the counter.
     * Call this once per packet before transmission.
     *
     * Per §Sequence Numbers: "Every outgoing packet increments the sequence
     * number." Sequence never resets mid-session.
     */
    fun nextOutgoingSequenceNumber(): Long = nextOutgoing++

    // -----------------------------------------------------------------------
    // Incoming
    // -----------------------------------------------------------------------

    /**
     * Evaluates an incoming [packet] against the expected sequence.
     *
     * Outcomes:
     *   [SequenceCheckResult.InOrder]   — process now; drain any buffered.
     *   [SequenceCheckResult.Buffered]  — hold; wait for missing predecessor.
     *   [SequenceCheckResult.Stale]     — duplicate/replay; ignore.
     *
     * Recovery: when a missing packet finally arrives, [SequenceCheckResult
     * .InOrder.releasedFromBuffer] contains the chain of buffered packets
     * ready for ordered processing, matching §Out-of-Order Packets recovery
     * rules.
     */
    fun evaluate(packet: Packet): SequenceCheckResult {
        val seq = packet.header.sequenceNumber

        // Stale / duplicate by sequence number.
        // Per §Duplicate Detection: stale sequence numbers are ignored.
        if (seq < nextExpected - config.stalenessThreshold) {
            return SequenceCheckResult.Stale(seq, nextExpected)
        }

        // Out-of-order: future packet — buffer it.
        if (seq > nextExpected) {
            bufferPacket(packet)
            return SequenceCheckResult.Buffered(seq)
        }

        // In-order packet (seq == nextExpected).
        nextExpected++

        // Drain contiguous buffered packets.
        val released = drainBuffer()
        return SequenceCheckResult.InOrder(released)
    }

    /**
     * Force-advances [nextExpected] to [sequenceNumber] and drains any
     * now-available buffered packets. Used when protocol recovery rules
     * determine that a missing packet will never arrive (e.g. session
     * recovery, per §Automatic Recovery and §State Refresh).
     *
     * Per §Recovery Philosophy: "Recovering quickly is less important than
     * recovering correctly." Callers must apply recovery only after the
     * session-layer recovery protocol has determined skipping is safe.
     *
     * @return Packets released from the buffer in ascending sequence order.
     */
    fun advanceTo(sequenceNumber: Long): List<Packet> {
        if (sequenceNumber > nextExpected) {
            nextExpected = sequenceNumber
        }
        return drainBuffer()
    }

    /**
     * Discards all buffered out-of-order packets and resets the tracker to
     * its initial state. Call when the session ends.
     *
     * Per §Resource Management: "Completed sessions should destroy temporary
     * state."
     */
    fun reset() {
        buffer.clear()
        nextExpected = 1L
        nextOutgoing = 1L
    }

    /** Number of packets currently held in the out-of-order buffer. */
    val bufferedCount: Int get() = buffer.size

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /**
     * Adds [packet] to the out-of-order buffer.
     * If the buffer is at capacity, the packet with the lowest sequence
     * number is evicted to make room. This prioritizes keeping more-recent
     * out-of-order packets, which are more likely to be needed soon.
     */
    private fun bufferPacket(packet: Packet) {
        // Already buffered (exact duplicate by sequence); ignore.
        val seq = packet.header.sequenceNumber
        if (buffer.containsKey(seq)) return

        if (buffer.size >= config.maxBufferedPackets) {
            // Evict oldest (lowest sequence) entry.
            buffer.pollFirstEntry()
        }
        buffer[seq] = packet
    }

    /**
     * Drains the buffer of any now-consecutive packets starting at
     * [nextExpected], advancing [nextExpected] for each one consumed.
     *
     * @return Packets in ascending sequence order, ready for processing.
     */
    private fun drainBuffer(): List<Packet> {
        val released = mutableListOf<Packet>()
        while (buffer.containsKey(nextExpected)) {
            released += buffer.remove(nextExpected)!!
            nextExpected++
        }
        return released
    }

    override fun toString(): String =
        "SequenceTracker(session=$sessionId, nextExpected=$nextExpected, buffered=${buffer.size})"
}
