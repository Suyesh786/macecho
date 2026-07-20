// ReplayGuard.swift — Phase 11
//
// Implements Stage 7 (Freshness Validation) of the packet validation pipeline
// defined in 07_PROTOCOL_SPECIFICATION.md §Packet Timestamp:
//
//   "Timestamp validation must tolerate reasonable clock differences between
//    devices. Packets received outside the allowed clock skew are rejected."
//
// Also implements the UUID-based half of Stage 8 (Duplicate Detection):
//
//   "Every packet identifier is compared against previously processed packets.
//    Duplicate packets, identified by Packet UUID or stale Session Sequence
//    Number, are ignored." (§Duplicate Detection)
//
// This class is deliberately separated from SequenceTracker because the two
// concerns are orthogonal:
//   - ReplayGuard      : clock-skew window + UUID cache (session-independent)
//   - SequenceTracker  : per-session ordered sequence numbers + OOO buffer
//
// Security requirements met (04_SECURITY_MODEL.md):
//   • "Prevent replay attacks."
//   • "Every security decision must be deterministic."
//
// Must NOT contain:
//   - Authentication logic           → Phase 12+
//   - Trust validation               → Phase 12+
//   - Decryption                     → Phase 12+
//   - Business logic of any kind
//
// ─── CONFIGURABLE PARAMETERS ──────────────────────────────────────────────
// The protocol specification does not mandate specific numeric values for:
//   • Clock skew tolerance
//   • UUID cache capacity
// Both parameters are configurable via ReplayGuardConfig. The defaults
// supplied here are *implementation defaults*, not protocol requirements.
// They can be replaced without modifying this struct.
// ──────────────────────────────────────────────────────────────────────────

import Foundation

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Configuration for ``ReplayGuard``.
///
/// - Parameter clockSkewToleranceMs: Maximum allowed difference (in
///   milliseconds) between a packet's `timestamp` and the current wall-clock
///   time. A packet is rejected if `|now - packet.timestamp| > tolerance`.
///   Per §Packet Timestamp. The protocol does not mandate a specific value;
///   `300_000` (5 minutes) is an **implementation default only**.
///
/// - Parameter maxCachedPacketIds: Upper bound on the number of processed
///   Packet UUIDs retained in memory. Once the cache reaches this limit the
///   oldest entries (insertion order) are evicted. The protocol does not
///   mandate a cache size; `2048` is an **implementation default only**.
struct ReplayGuardConfig {
    let clockSkewToleranceMs: Int64
    let maxCachedPacketIds: Int

    /// Implementation defaults — NOT protocol requirements.
    static let defaultClockSkewToleranceMs: Int64 = 5 * 60 * 1_000   // 5 minutes
    static let defaultMaxCachedPacketIds: Int = 2_048

    init(
        clockSkewToleranceMs: Int64 = ReplayGuardConfig.defaultClockSkewToleranceMs,
        maxCachedPacketIds: Int = ReplayGuardConfig.defaultMaxCachedPacketIds
    ) {
        self.clockSkewToleranceMs = clockSkewToleranceMs
        self.maxCachedPacketIds = maxCachedPacketIds
    }
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// Outcome of a ``ReplayGuard`` check. Used by ``PacketValidator`` to
/// populate Stage 7 and the UUID half of Stage 8 in the validation report.
enum ReplayGuardResult: Equatable {
    /// Packet timestamp is within the allowed clock skew window and UUID is fresh.
    case fresh
    /// Packet timestamp is outside the allowed clock skew window.
    case staleTimestamp(packetTimestampMs: Int64, nowMs: Int64, skewMs: Int64)
    /// Packet UUID has already been processed (duplicate / replay).
    case duplicatePacketId(String)
}

// ---------------------------------------------------------------------------
// ReplayGuard
// ---------------------------------------------------------------------------

/// Stateful guard that checks packet freshness and tracks processed Packet
/// UUIDs to prevent replay attacks and duplicate execution.
///
/// **Thread-safety**: NOT thread-safe. External synchronization required
/// if shared across threads.
///
/// - Parameter config: Configurable parameters (clock skew window, cache size).
/// - Parameter currentTimeMs: Function returning the current wall-clock time
///   in milliseconds. Injectable for deterministic testing without clock
///   manipulation.
final class ReplayGuard {

    private let config: ReplayGuardConfig
    private let currentTimeMs: () -> Int64

    /// Insertion-ordered cache of processed Packet UUIDs.
    /// Using an array of (key, value) pairs to maintain insertion order for
    /// O(n) LRU eviction. For large caches use a real LRU implementation.
    private var processedIds: [String: Void] = [:]
    private var insertionOrder: [String] = []

    init(
        config: ReplayGuardConfig = ReplayGuardConfig(),
        currentTimeMs: @escaping () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1_000)
        }
    ) {
        self.config = config
        self.currentTimeMs = currentTimeMs
    }

    // -----------------------------------------------------------------------
    // Split stage methods (used by PacketValidator)
    // -----------------------------------------------------------------------

    /// Checks timestamp freshness ONLY (Stage 7). Does NOT access or modify
    /// the UUID cache. Use this from ``PacketValidator`` at Stage 7.
    func checkFreshnessOnly(_ packet: Packet) -> ReplayGuardResult {
        let now = currentTimeMs()
        let skew = abs(now - packet.header.timestamp)
        guard skew <= config.clockSkewToleranceMs else {
            return .staleTimestamp(
                packetTimestampMs: packet.header.timestamp,
                nowMs: now,
                skewMs: skew
            )
        }
        return .fresh
    }

    /// Checks UUID duplicate status ONLY (Stage 8, UUID half). If the UUID is
    /// new, records it in the cache. Use this from ``PacketValidator`` at
    /// Stage 8.
    func checkDuplicateOnly(_ packet: Packet) -> ReplayGuardResult {
        let packetId = packet.header.packetId
        if processedIds[packetId] != nil {
            return .duplicatePacketId(packetId)
        }
        recordId(packetId)
        return .fresh
    }

    // -----------------------------------------------------------------------
    // Convenience combined check
    // -----------------------------------------------------------------------

    /// Checks both freshness and UUID duplicate in one call (convenience for
    /// callers that do not need split stage results, e.g. integration tests).
    ///
    /// Evaluation order:
    ///   1. Timestamp freshness — §Packet Timestamp
    ///   2. UUID uniqueness     — §Duplicate Detection
    ///
    /// The UUID is recorded in the cache only when the timestamp check passes.
    func check(_ packet: Packet) -> ReplayGuardResult {
        let freshnessResult = checkFreshnessOnly(packet)
        guard case .fresh = freshnessResult else {
            return freshnessResult
        }
        return checkDuplicateOnly(packet)
    }

    // -----------------------------------------------------------------------
    // Manual cache management
    // -----------------------------------------------------------------------

    /// Explicitly records a Packet UUID as processed without performing any
    /// checks. Use when a packet has been accepted by the full pipeline but
    /// its UUID was not yet in the cache.
    func markProcessed(packetId: String) {
        if processedIds[packetId] == nil {
            recordId(packetId)
        }
    }

    /// Removes all entries from the processed-ID cache. Should be called when
    /// a session ends so memory is released promptly.
    ///
    /// Per §Resource Management: "Completed sessions should destroy temporary
    /// state."
    func clearCache() {
        processedIds.removeAll()
        insertionOrder.removeAll()
    }

    /// Number of Packet UUIDs currently tracked in the cache.
    var cachedIdCount: Int { processedIds.count }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    private func recordId(_ packetId: String) {
        if processedIds.count >= config.maxCachedPacketIds,
           let oldest = insertionOrder.first {
            processedIds.removeValue(forKey: oldest)
            insertionOrder.removeFirst()
        }
        processedIds[packetId] = ()
        insertionOrder.append(packetId)
    }
}
