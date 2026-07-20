// SequenceTrackerTests.swift — Phase 11 unit tests
//
// Coverage:
//   ✓ First packet in session (seq=1) is accepted
//   ✓ In-order packets advance nextExpected
//   ✓ Stale packet (below nextExpected) is Stale
//   ✓ Duplicate (same sequence, already seen) is Stale
//   ✓ Out-of-order future packet is buffered
//   ✓ Buffered packet released when missing predecessor arrives
//   ✓ Multiple buffered packets released in order
//   ✓ advanceTo skips a gap and releases buffered packets
//   ✓ Buffer evicts oldest when capacity exceeded
//   ✓ reset clears buffer and resets counters
//   ✓ nextOutgoingSequenceNumber starts at 1 and increments
//   ✓ checkStaleness does not modify state
//   ✓ Stale result contains correct fields

import XCTest
@testable import MacEcho

final class SequenceTrackerTests: XCTestCase {

    let sessionId = "test-session-\(UUID().uuidString)"

    private func makeTracker(maxBuffered: Int = 4, staleness: Int64 = 0) -> SequenceTracker {
        SequenceTracker(
            sessionId: sessionId,
            config: SequenceTrackerConfig(
                maxBufferedPackets: maxBuffered,
                stalenessThreshold: staleness
            )
        )
    }

    private func packet(seq: Int64) -> Packet {
        Packet(
            header: PacketHeader(
                protocolVersion: 1,
                packetType: .heartbeat,
                sessionId: sessionId,
                senderId: "device-a",
                packetId: UUID().uuidString,
                sequenceNumber: seq,
                timestamp: Int64(Date().timeIntervalSince1970 * 1_000)
            ),
            metadata: PacketMetadata(retryCount: 0, priority: .normal, messageCategory: .heartbeat),
            encryptedPayload: [0x01]
        )
    }

    // MARK: - In-order

    func testFirstPacketInSessionIsAccepted() {
        let tracker = makeTracker()
        let result = tracker.evaluate(packet(seq: 1))
        guard case .inOrder(let released) = result else {
            return XCTFail("Expected inOrder")
        }
        XCTAssertTrue(released.isEmpty)
        XCTAssertEqual(tracker.nextExpected, 2)
    }

    func testConsecutiveInOrderPacketsAdvanceExpected() {
        let tracker = makeTracker()
        for i in 1...5 {
            let result = tracker.evaluate(packet(seq: Int64(i)))
            guard case .inOrder = result else {
                return XCTFail("Packet \(i) should be inOrder")
            }
        }
        XCTAssertEqual(tracker.nextExpected, 6)
    }

    // MARK: - Stale

    func testSequenceNumberBelowNextExpectedIsStale() {
        let tracker = makeTracker()
        tracker.evaluate(packet(seq: 1)) // nextExpected = 2
        let result = tracker.evaluate(packet(seq: 1))
        guard case .stale(let seq, let next) = result else {
            return XCTFail("Expected stale")
        }
        XCTAssertEqual(seq, 1)
        XCTAssertEqual(next, 2)
    }

    func testOldPacketFarBelowNextExpectedIsStale() {
        let tracker = makeTracker()
        (1...5).forEach { tracker.evaluate(packet(seq: Int64($0))) }
        let result = tracker.evaluate(packet(seq: 2))
        guard case .stale = result else { return XCTFail("Expected stale") }
    }

    // MARK: - Out-of-order buffering

    func testFuturePacketIsBuffered() {
        let tracker = makeTracker()
        let result = tracker.evaluate(packet(seq: 3))
        guard case .buffered(let seq) = result else {
            return XCTFail("Expected buffered")
        }
        XCTAssertEqual(seq, 3)
        XCTAssertEqual(tracker.bufferedCount, 1)
        XCTAssertEqual(tracker.nextExpected, 1)
    }

    func testMissingPacketArrivalReleasesBuffer() {
        let tracker = makeTracker()
        tracker.evaluate(packet(seq: 3))
        tracker.evaluate(packet(seq: 2))
        XCTAssertEqual(tracker.bufferedCount, 2)

        let result = tracker.evaluate(packet(seq: 1))
        guard case .inOrder(let released) = result else {
            return XCTFail("Expected inOrder")
        }
        XCTAssertEqual(released.count, 2)
        XCTAssertEqual(released[0].header.sequenceNumber, 2)
        XCTAssertEqual(released[1].header.sequenceNumber, 3)
        XCTAssertEqual(tracker.nextExpected, 4)
        XCTAssertEqual(tracker.bufferedCount, 0)
    }

    func testChainedBufferReleaseWorksCorrectly() {
        let tracker = makeTracker(maxBuffered: 10)
        (2...5).forEach { tracker.evaluate(packet(seq: Int64($0))) }
        let result = tracker.evaluate(packet(seq: 1))
        guard case .inOrder(let released) = result else {
            return XCTFail("Expected inOrder")
        }
        XCTAssertEqual(released.map { $0.header.sequenceNumber }, [2, 3, 4, 5])
        XCTAssertEqual(tracker.nextExpected, 6)
    }

    func testSameSequenceNumberBufferedOnlyOnce() {
        let tracker = makeTracker()
        tracker.evaluate(packet(seq: 5))
        tracker.evaluate(packet(seq: 5))
        XCTAssertEqual(tracker.bufferedCount, 1)
    }

    // MARK: - Buffer capacity eviction

    func testBufferEvictsOldestWhenFull() {
        let tracker = makeTracker(maxBuffered: 4)
        (2...5).forEach { tracker.evaluate(packet(seq: Int64($0))) }
        XCTAssertEqual(tracker.bufferedCount, 4)

        tracker.evaluate(packet(seq: 6)) // evicts seq 2
        XCTAssertEqual(tracker.bufferedCount, 4)

        // Deliver seq 1. nextExpected becomes 2, but seq 2 was evicted —
        // the drain stops immediately because seq 2 is not in the buffer.
        let result = tracker.evaluate(packet(seq: 1))
        guard case .inOrder(let released) = result else {
            return XCTFail("Expected inOrder")
        }
        // No consecutive chain can start from seq 2 (evicted), so nothing is released.
        XCTAssertTrue(released.isEmpty, "No chain can start without seq 2 (evicted)")
        XCTAssertEqual(tracker.nextExpected, 2)
        XCTAssertEqual(tracker.bufferedCount, 4) // 3,4,5,6 still buffered
    }

    // MARK: - advanceTo (recovery)

    func testAdvanceToSkipsGapAndDrainsBuffer() {
        let tracker = makeTracker()
        tracker.evaluate(packet(seq: 3))
        tracker.evaluate(packet(seq: 4))
        let released = tracker.advanceTo(3)
        XCTAssertEqual(released.map { $0.header.sequenceNumber }, [3, 4])
        XCTAssertEqual(tracker.nextExpected, 5)
        XCTAssertEqual(tracker.bufferedCount, 0)
    }

    func testAdvanceToWithNoBufferJustAdvances() {
        let tracker = makeTracker()
        let released = tracker.advanceTo(10)
        XCTAssertTrue(released.isEmpty)
        XCTAssertEqual(tracker.nextExpected, 10)
    }

    func testAdvanceToLowerThanCurrentDoesNothing() {
        let tracker = makeTracker()
        tracker.evaluate(packet(seq: 1))
        tracker.evaluate(packet(seq: 2))
        tracker.advanceTo(1)
        XCTAssertEqual(tracker.nextExpected, 3)
    }

    // MARK: - reset

    func testResetClearsBufferAndResetsCounters() {
        let tracker = makeTracker()
        tracker.evaluate(packet(seq: 1))
        tracker.evaluate(packet(seq: 5))
        tracker.reset()
        XCTAssertEqual(tracker.nextExpected, 1)
        XCTAssertEqual(tracker.bufferedCount, 0)
    }

    // MARK: - Outgoing sequence number

    func testOutgoingSequenceNumberStartsAtOne() {
        let tracker = makeTracker()
        XCTAssertEqual(tracker.nextOutgoingSequenceNumber(), 1)
    }

    func testOutgoingSequenceNumberIncrements() {
        let tracker = makeTracker()
        XCTAssertEqual(tracker.nextOutgoingSequenceNumber(), 1)
        XCTAssertEqual(tracker.nextOutgoingSequenceNumber(), 2)
        XCTAssertEqual(tracker.nextOutgoingSequenceNumber(), 3)
    }

    // MARK: - checkStaleness (read-only for PacketValidator Stage 8)

    func testCheckStalenessDoesNotModifyState() {
        let tracker = makeTracker()
        tracker.evaluate(packet(seq: 1))
        let before = tracker.nextExpected
        tracker.checkStaleness(packet(seq: 1))
        XCTAssertEqual(tracker.nextExpected, before)
    }

    func testCheckStalenessReturnsStaleBelowThreshold() {
        let tracker = makeTracker()
        tracker.evaluate(packet(seq: 1))
        let result = tracker.checkStaleness(packet(seq: 1))
        guard case .stale = result else { return XCTFail("Expected stale") }
    }

    func testCheckStalenessReturnsInOrderForCurrentAndFuture() {
        let tracker = makeTracker()
        let current = tracker.checkStaleness(packet(seq: 1))
        guard case .inOrder = current else { return XCTFail("Expected inOrder for seq == nextExpected") }
        let future = tracker.checkStaleness(packet(seq: 99))
        guard case .inOrder = future else { return XCTFail("Expected inOrder for future seq") }
    }
}
