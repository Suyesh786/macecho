// SequenceTracker.swift — Phase 11
//
// Implements the sequence-number half of Stage 8 (Duplicate Detection /
// Packet Ordering) of the packet validation pipeline defined in
// 07_PROTOCOL_SPECIFICATION.md.
//
// Specification rules implemented:
//
//   §Sequence Numbers:
//     "Sequence numbers are scoped to an individual communication session."
//     "The sequence number starts at 1 per session."
//     "Every outgoing packet increments the sequence number."
//
//   §Packet Ordering:
//     "Packets should be processed in their intended logical order whenever
//      ordering affects application behavior."
//
//   §Out-of-Order Packets:
//     "Out-of-order packets are buffered temporarily until the missing
//      sequence numbers arrive or recovery rules apply."
//     "Safety always takes priority over speed."
//
//   §Duplicate Detection:
//     "Duplicate packets, identified by Packet UUID or stale Session
//      Sequence Number, are ignored."
//
//   §Recovery Philosophy:
//     "Recovering quickly is less important than recovering correctly."
//
// Design:
//   - SequenceTracker is per-session: one instance per active session.
//   - `nextExpected` is the sequence number the tracker expects next.
//   - Packets below `nextExpected` are stale.
//   - Packets equal to `nextExpected` are in-order; buffered packets drain.
//   - Packets above `nextExpected` are buffered.
//
// Must NOT contain:
//   - Authentication logic     → Phase 12+
//   - Trust validation         → Phase 12+
//   - Decryption               → Phase 12+
//   - Business logic
//
// ─── CONFIGURABLE PARAMETERS ──────────────────────────────────────────────
// The protocol specification does not mandate numeric values for:
//   • Maximum out-of-order buffer size
//   • Staleness threshold
// Both are configurable. Defaults are implementation defaults only.
// ──────────────────────────────────────────────────────────────────────────

import Foundation

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Configuration for ``SequenceTracker``.
///
/// - Parameter maxBufferedPackets: Maximum number of future (out-of-order)
///   packets held in the buffer simultaneously. Once the limit is reached
///   the lowest-sequence buffered packet is evicted to make room.
///   **Implementation default: 64** — not a protocol requirement.
///
/// - Parameter stalenessThreshold: A packet whose sequence number is strictly
///   less than `(nextExpected - stalenessThreshold)` is considered stale.
///   Set to 0 to treat every packet below `nextExpected` as stale immediately.
///   **Implementation default: 0** — not a protocol requirement.
struct SequenceTrackerConfig {
    let maxBufferedPackets: Int
    let stalenessThreshold: Int64

    /// Implementation defaults — NOT protocol requirements.
    static let defaultMaxBufferedPackets: Int = 64
    static let defaultStalenessThreshold: Int64 = 0

    init(
        maxBufferedPackets: Int = SequenceTrackerConfig.defaultMaxBufferedPackets,
        stalenessThreshold: Int64 = SequenceTrackerConfig.defaultStalenessThreshold
    ) {
        self.maxBufferedPackets = maxBufferedPackets
        self.stalenessThreshold = stalenessThreshold
    }
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// Outcome of a ``SequenceTracker`` evaluation for a single packet.
enum SequenceCheckResult: Equatable {
    /// Packet is next in order and may be processed immediately.
    /// `releasedFromBuffer` contains previously buffered packets (ascending
    /// sequence order) that are now also ready to process.
    case inOrder(releasedFromBuffer: [Packet])

    /// Packet arrived before its predecessor(s). Buffered per §Out-of-Order Packets.
    case buffered(sequenceNumber: Int64)

    /// Packet sequence number is below the staleness threshold.
    /// Per §Duplicate Detection: ignored; command not re-executed.
    case stale(sequenceNumber: Int64, nextExpected: Int64)
}

// ---------------------------------------------------------------------------
// SequenceTracker
// ---------------------------------------------------------------------------

/// Tracks per-session packet ordering and maintains a temporary buffer for
/// out-of-order packets.
///
/// **Lifecycle**: one ``SequenceTracker`` per communication session. Discard
/// on session end; never reuse across sessions.
///
/// **Thread-safety**: NOT thread-safe. External synchronization required if
/// shared across threads.
final class SequenceTracker {

    let sessionId: String
    private let config: SequenceTrackerConfig

    /// The next sequence number this tracker expects to receive.
    /// Starts at 1 per §Sequence Numbers.
    private(set) var nextExpected: Int64 = 1

    /// Outgoing sequence counter. Starts at 1 per §Sequence Numbers.
    private var nextOutgoingValue: Int64 = 1

    /// Buffer for future (out-of-order) packets awaiting their turn.
    /// Sorted by sequence number.
    private var buffer: [Int64: Packet] = [:]

    init(
        sessionId: String,
        config: SequenceTrackerConfig = SequenceTrackerConfig()
    ) {
        self.sessionId = sessionId
        self.config = config
    }

    // -----------------------------------------------------------------------
    // Outgoing
    // -----------------------------------------------------------------------

    /// Returns the next outgoing sequence number and advances the counter.
    /// Call once per packet before transmission.
    ///
    /// Per §Sequence Numbers: "Every outgoing packet increments the sequence
    /// number."
    func nextOutgoingSequenceNumber() -> Int64 {
        let seq = nextOutgoingValue
        nextOutgoingValue += 1
        return seq
    }

    // -----------------------------------------------------------------------
    // Incoming
    // -----------------------------------------------------------------------

    /// Read-only staleness check for use by ``PacketValidator`` at Stage 8.
    /// Does NOT modify buffer state or advance `nextExpected`.
    ///
    /// Returns `.stale` if `seq < nextExpected - stalenessThreshold`.
    /// Returns `.inOrder([])` for all non-stale sequence numbers.
    func checkStaleness(_ packet: Packet) -> SequenceCheckResult {
        let seq = packet.header.sequenceNumber
        if seq < nextExpected - config.stalenessThreshold {
            return .stale(sequenceNumber: seq, nextExpected: nextExpected)
        }
        return .inOrder(releasedFromBuffer: [])
    }

    /// Evaluates an incoming packet against the expected sequence.
    ///
    /// Outcomes:
    ///   `.inOrder`   — process now; drain any buffered packets.
    ///   `.buffered`  — hold; wait for missing predecessor.
    ///   `.stale`     — duplicate/replay; ignore.
    func evaluate(_ packet: Packet) -> SequenceCheckResult {
        let seq = packet.header.sequenceNumber

        // Stale / duplicate by sequence number.
        if seq < nextExpected - config.stalenessThreshold {
            return .stale(sequenceNumber: seq, nextExpected: nextExpected)
        }

        // Out-of-order: future packet — buffer it.
        if seq > nextExpected {
            bufferPacket(packet)
            return .buffered(sequenceNumber: seq)
        }

        // In-order (seq == nextExpected).
        nextExpected += 1
        let released = drainBuffer()
        return .inOrder(releasedFromBuffer: released)
    }

    /// Force-advances `nextExpected` to `sequenceNumber` and drains any
    /// now-available buffered packets. Use during protocol recovery.
    ///
    /// Per §Recovery Philosophy: callers must apply recovery only after the
    /// session-layer recovery protocol determines skipping is safe.
    ///
    /// - Returns: Packets released from the buffer in ascending order.
    @discardableResult
    func advanceTo(_ sequenceNumber: Int64) -> [Packet] {
        if sequenceNumber > nextExpected {
            nextExpected = sequenceNumber
        }
        return drainBuffer()
    }

    /// Discards all buffered out-of-order packets and resets the tracker.
    /// Call when the session ends.
    ///
    /// Per §Resource Management: "Completed sessions should destroy temporary
    /// state."
    func reset() {
        buffer.removeAll()
        nextExpected = 1
        nextOutgoingValue = 1
    }

    /// Number of packets currently held in the out-of-order buffer.
    var bufferedCount: Int { buffer.count }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    private func bufferPacket(_ packet: Packet) {
        let seq = packet.header.sequenceNumber
        // Already buffered by this sequence number; ignore.
        guard buffer[seq] == nil else { return }

        if buffer.count >= config.maxBufferedPackets,
           let lowestKey = buffer.keys.min() {
            buffer.removeValue(forKey: lowestKey)
        }
        buffer[seq] = packet
    }

    private func drainBuffer() -> [Packet] {
        var released: [Packet] = []
        while let packet = buffer[nextExpected] {
            released.append(packet)
            buffer.removeValue(forKey: nextExpected)
            nextExpected += 1
        }
        return released
    }
}
