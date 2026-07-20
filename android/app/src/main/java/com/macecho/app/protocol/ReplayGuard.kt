package com.macecho.app.protocol

/**
 * ReplayGuard.kt — Phase 11
 *
 * Implements Stage 7 (Freshness Validation) of the packet validation pipeline
 * defined in 07_PROTOCOL_SPECIFICATION.md §Packet Timestamp:
 *
 *   "Timestamp validation must tolerate reasonable clock differences between
 *    devices. Packets received outside the allowed clock skew are rejected."
 *
 * Also implements the UUID-based half of Stage 8 (Duplicate Detection):
 *
 *   "Every packet identifier is compared against previously processed packets.
 *    Duplicate packets, identified by Packet UUID or stale Session Sequence
 *    Number, are ignored." (§Duplicate Detection)
 *
 * This class is deliberately separated from [SequenceTracker] because the two
 * concerns are orthogonal:
 *   - [ReplayGuard]      : clock-skew window + UUID cache (session-independent)
 *   - [SequenceTracker]  : per-session ordered sequence numbers + OOO buffer
 *
 * Security requirements met (04_SECURITY_MODEL.md):
 *   • "Prevent replay attacks."
 *   • "Every security decision must be deterministic."
 *
 * Must NOT contain:
 *   - Authentication logic           → Phase 12+
 *   - Trust validation               → Phase 12+
 *   - Decryption                     → Phase 12+
 *   - Business logic of any kind
 *
 * ─── CONFIGURABLE PARAMETERS ───────────────────────────────────────────────
 * The protocol specification does not mandate specific numeric values for:
 *   • Clock skew tolerance
 *   • UUID cache capacity
 * Both parameters are configurable via [ReplayGuardConfig]. The defaults
 * supplied here are *implementation defaults*, not protocol requirements.
 * They can be replaced without modifying this class.
 * ────────────────────────────────────────────────────────────────────────────
 */

/**
 * Configuration for [ReplayGuard].
 *
 * @property clockSkewToleranceMs
 *   Maximum allowed difference (in milliseconds) between a packet's
 *   [PacketHeader.timestamp] and the current wall-clock time.
 *   A packet is rejected if:
 *       |now - packet.timestamp| > clockSkewToleranceMs
 *   Per §Packet Timestamp: "Packets received outside the allowed clock skew
 *   are rejected." The protocol does not mandate a specific value; this is
 *   an implementation default that can be overridden via [ReplayGuardConfig].
 *   Default: 300_000 ms (5 minutes) — implementation default only.
 *
 * @property maxCachedPacketIds
 *   Upper bound on the number of processed Packet UUIDs retained in memory.
 *   Once the cache reaches this limit the oldest entries are evicted (LRU).
 *   The protocol does not mandate a specific cache size; this is an
 *   implementation default.
 *   Default: 2_048 entries — implementation default only.
 */
data class ReplayGuardConfig(
    val clockSkewToleranceMs: Long = DEFAULT_CLOCK_SKEW_TOLERANCE_MS,
    val maxCachedPacketIds: Int = DEFAULT_MAX_CACHED_PACKET_IDS,
) {
    companion object {
        /**
         * Implementation default for clock skew tolerance.
         * NOT a protocol requirement — override via [ReplayGuardConfig].
         */
        const val DEFAULT_CLOCK_SKEW_TOLERANCE_MS: Long = 5 * 60 * 1_000L // 5 minutes

        /**
         * Implementation default for UUID cache size.
         * NOT a protocol requirement — override via [ReplayGuardConfig].
         */
        const val DEFAULT_MAX_CACHED_PACKET_IDS: Int = 2_048
    }
}

/**
 * Outcome of a [ReplayGuard] check. Used by [PacketValidator] to populate
 * Stage 7 and the UUID half of Stage 8 in the validation report.
 */
sealed class ReplayGuardResult {
    /** Packet timestamp is within the allowed clock skew window and UUID is fresh. */
    object Fresh : ReplayGuardResult()

    /** Packet timestamp is outside the allowed clock skew window. */
    data class StaleTimestamp(val packetTimestampMs: Long, val nowMs: Long, val skewMs: Long) :
        ReplayGuardResult()

    /** Packet UUID has already been processed (duplicate). */
    data class DuplicatePacketId(val packetId: String) : ReplayGuardResult()
}

/**
 * Stateful guard that checks packet freshness and tracks processed Packet
 * UUIDs to prevent replay attacks and duplicate execution.
 *
 * Thread-safety: this class is NOT thread-safe. External synchronization is
 * required if the guard is shared across threads.
 *
 * @param config       Configurable parameters (clock skew window, cache size).
 * @param currentTimeMs Function returning the current wall-clock time in
 *                      milliseconds. Injectable for deterministic testing
 *                      without clock manipulation.
 */
class ReplayGuard(
    private val config: ReplayGuardConfig = ReplayGuardConfig(),
    private val currentTimeMs: () -> Long = System::currentTimeMillis,
) {

    /**
     * LRU-evicting cache of processed Packet UUIDs.
     * LinkedHashMap with accessOrder=false gives insertion-order eviction
     * (oldest-inserted is evicted first), which is correct for replay
     * protection: we discard the UUIDs of the oldest processed packets.
     */
    private val processedIds: LinkedHashMap<String, Unit> =
        object : LinkedHashMap<String, Unit>(config.maxCachedPacketIds, 0.75f, false) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Unit>): Boolean =
                size > config.maxCachedPacketIds
        }

    /**
     * Checks timestamp freshness ONLY (Stage 7). Does NOT access or modify
     * the UUID cache. Use this from [PacketValidator] at Stage 7.
     */
    fun checkFreshnessOnly(packet: Packet): ReplayGuardResult {
        val now = currentTimeMs()
        val skew = Math.abs(now - packet.header.timestamp)
        return if (skew > config.clockSkewToleranceMs) {
            ReplayGuardResult.StaleTimestamp(
                packetTimestampMs = packet.header.timestamp,
                nowMs = now,
                skewMs = skew,
            )
        } else {
            ReplayGuardResult.Fresh
        }
    }

    /**
     * Checks UUID duplicate status ONLY (Stage 8, UUID half). If the UUID is
     * new, records it in the cache. Use this from [PacketValidator] at Stage 8.
     */
    fun checkDuplicateOnly(packet: Packet): ReplayGuardResult {
        val packetId = packet.header.packetId
        return if (processedIds.containsKey(packetId)) {
            ReplayGuardResult.DuplicatePacketId(packetId)
        } else {
            processedIds[packetId] = Unit
            ReplayGuardResult.Fresh
        }
    }

    /**
     * Checks both freshness and UUID duplicate in one call (convenience for
     * callers that do not need split stage results, e.g. integration tests).
     *
     * Evaluation order:
     *   1. Timestamp freshness — §Packet Timestamp
     *   2. UUID uniqueness     — §Duplicate Detection
     *
     * The UUID is recorded in the cache only when the timestamp check passes.
     */
    fun check(packet: Packet): ReplayGuardResult {
        // Stage 7 — Freshness validation
        val now = currentTimeMs()
        val skew = Math.abs(now - packet.header.timestamp)
        if (skew > config.clockSkewToleranceMs) {
            return ReplayGuardResult.StaleTimestamp(
                packetTimestampMs = packet.header.timestamp,
                nowMs = now,
                skewMs = skew,
            )
        }

        // Stage 8 (UUID half) — Duplicate detection
        val packetId = packet.header.packetId
        if (processedIds.containsKey(packetId)) {
            return ReplayGuardResult.DuplicatePacketId(packetId)
        }

        // Mark as seen; this is the authoritative record for duplicate prevention.
        processedIds[packetId] = Unit
        return ReplayGuardResult.Fresh
    }

    /**
     * Explicitly records a Packet UUID as processed without performing any
     * checks. Use this when a packet has been accepted by the full pipeline
     * but its UUID was not yet in the cache (e.g. the first packet in a session
     * whose UUID slot was available). In normal [check] flow this is handled
     * automatically; this method is provided for integration with callers that
     * run [check] and later confirm processing.
     */
    fun markProcessed(packetId: String) {
        processedIds[packetId] = Unit
    }

    /**
     * Removes all entries from the processed-ID cache. Should be called when
     * a session ends so that memory is released promptly.
     *
     * Per §Resource Management: "Completed sessions should destroy temporary
     * state. Long-lived unused protocol state is discouraged."
     */
    fun clearCache() {
        processedIds.clear()
    }

    /** Returns the number of Packet UUIDs currently tracked in the cache. */
    val cachedIdCount: Int get() = processedIds.size
}
