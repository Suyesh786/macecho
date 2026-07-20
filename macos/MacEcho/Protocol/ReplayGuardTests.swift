// ReplayGuardTests.swift — Phase 11 unit tests
//
// Coverage:
//   ✓ Fresh packet passes freshness check
//   ✓ Timestamp too far in the future is rejected
//   ✓ Timestamp too far in the past is rejected
//   ✓ Timestamp exactly at boundary passes
//   ✓ Timestamp one ms beyond boundary is rejected
//   ✓ Duplicate UUID rejected on second presentation
//   ✓ First UUID presentation passes
//   ✓ Distinct UUIDs each accepted
//   ✓ Cache evicts oldest when capacity reached
//   ✓ clearCache resets duplicate tracker
//   ✓ check() convenience: stale timestamp before UUID
//   ✓ check() convenience: duplicate UUID when timestamp fresh
//   ✓ markProcessed causes subsequent duplicate detection
//   ✓ cachedIdCount reflects actual count

import XCTest
@testable import MacEcho

final class ReplayGuardTests: XCTestCase {

    let fixedNow: Int64 = 1_700_000_000_000

    private func makeGuard(
        toleranceMs: Int64 = 30_000,
        maxIds: Int = 5
    ) -> ReplayGuard {
        ReplayGuard(
            config: ReplayGuardConfig(
                clockSkewToleranceMs: toleranceMs,
                maxCachedPacketIds: maxIds
            ),
            currentTimeMs: { [fixedNow] in fixedNow }
        )
    }

    private func packet(
        timestampMs: Int64? = nil,
        packetId: String? = nil
    ) -> Packet {
        Packet(
            header: PacketHeader(
                protocolVersion: 1,
                packetType: .heartbeat,
                sessionId: UUID().uuidString,
                senderId: "device-a",
                packetId: packetId ?? UUID().uuidString,
                sequenceNumber: 1,
                timestamp: timestampMs ?? fixedNow
            ),
            metadata: PacketMetadata(retryCount: 0, priority: .normal, messageCategory: .heartbeat),
            encryptedPayload: [0x01]
        )
    }

    // MARK: - Freshness checks

    func testFreshTimestampPassesFreshnessCheck() {
        let guard_ = makeGuard()
        XCTAssertEqual(guard_.checkFreshnessOnly(packet()), .fresh)
    }

    func testTimestampTooFarFutureFailsFreshness() {
        let guard_ = makeGuard()
        let result = guard_.checkFreshnessOnly(packet(timestampMs: fixedNow + 30_001))
        if case .staleTimestamp = result { /* expected */ } else {
            XCTFail("Expected staleTimestamp, got \(result)")
        }
    }

    func testTimestampTooFarPastFailsFreshness() {
        let guard_ = makeGuard()
        let result = guard_.checkFreshnessOnly(packet(timestampMs: fixedNow - 30_001))
        if case .staleTimestamp = result { /* expected */ } else {
            XCTFail("Expected staleTimestamp")
        }
    }

    func testTimestampExactlyAtBoundaryPasses() {
        let guard_ = makeGuard()
        let result = guard_.checkFreshnessOnly(packet(timestampMs: fixedNow - 30_000))
        XCTAssertEqual(result, .fresh, "Exact boundary should pass")
    }

    func testTimestampOneMillisecondBeyondBoundaryFails() {
        let guard_ = makeGuard()
        let result = guard_.checkFreshnessOnly(packet(timestampMs: fixedNow - 30_001))
        if case .staleTimestamp = result { /* expected */ } else {
            XCTFail("Expected staleTimestamp one ms over boundary")
        }
    }

    func testStaleTimestampResultContainsCorrectFields() {
        let guard_ = makeGuard()
        let ts: Int64 = fixedNow - 60_000
        let result = guard_.checkFreshnessOnly(packet(timestampMs: ts))
        guard case .staleTimestamp(let pTs, let now, let skew) = result else {
            return XCTFail("Expected staleTimestamp")
        }
        XCTAssertEqual(pTs, ts)
        XCTAssertEqual(now, fixedNow)
        XCTAssertEqual(skew, 60_000)
    }

    // MARK: - Duplicate (UUID) checks

    func testFirstPresentationOfUuidPasses() {
        let guard_ = makeGuard()
        XCTAssertEqual(guard_.checkDuplicateOnly(packet()), .fresh)
    }

    func testSecondPresentationOfSameUuidFails() {
        let guard_ = makeGuard()
        let id = UUID().uuidString
        guard_.checkDuplicateOnly(packet(packetId: id))
        let result = guard_.checkDuplicateOnly(packet(packetId: id))
        XCTAssertEqual(result, .duplicatePacketId(id))
    }

    func testDistinctUuidsEachAccepted() {
        let guard_ = makeGuard(maxIds: 100)
        for _ in 0..<10 {
            XCTAssertEqual(guard_.checkDuplicateOnly(packet()), .fresh)
        }
    }

    // MARK: - Cache eviction

    func testCacheEvictsOldestWhenCapacityReached() {
        let guard_ = makeGuard(maxIds: 5)
        let ids = (0..<5).map { _ in UUID().uuidString }
        ids.forEach { id in guard_.checkDuplicateOnly(packet(packetId: id)) }
        XCTAssertEqual(guard_.cachedIdCount, 5)

        // Inserting a 6th evicts the first.
        guard_.checkDuplicateOnly(packet())
        XCTAssertEqual(guard_.cachedIdCount, 5)

        // First id should now be evicted and accepted again.
        XCTAssertEqual(guard_.checkDuplicateOnly(packet(packetId: ids[0])), .fresh)
    }

    // MARK: - clearCache

    func testClearCacheResetsUuidTracker() {
        let guard_ = makeGuard()
        let id = UUID().uuidString
        guard_.checkDuplicateOnly(packet(packetId: id))
        guard_.clearCache()
        XCTAssertEqual(guard_.cachedIdCount, 0)
        XCTAssertEqual(guard_.checkDuplicateOnly(packet(packetId: id)), .fresh)
    }

    // MARK: - Convenience check()

    func testCheckConvenienceReturnsFreshForValidPacket() {
        let guard_ = makeGuard()
        XCTAssertEqual(guard_.check(packet()), .fresh)
    }

    func testCheckConvenienceReportsStaleTimestampBeforeUuid() {
        let guard_ = makeGuard()
        let id = UUID().uuidString
        let result = guard_.check(packet(timestampMs: fixedNow - 60_000, packetId: id))
        if case .staleTimestamp = result { /* expected */ } else {
            XCTFail("Expected staleTimestamp to short-circuit before UUID check")
        }
    }

    func testCheckConvenienceReportsDuplicateWhenTimestampFresh() {
        let guard_ = makeGuard()
        let id = UUID().uuidString
        guard_.check(packet(packetId: id))
        let result = guard_.check(packet(packetId: id))
        XCTAssertEqual(result, .duplicatePacketId(id))
    }

    // MARK: - markProcessed

    func testMarkProcessedCausesSubsequentDuplicateDetection() {
        let guard_ = makeGuard()
        let id = UUID().uuidString
        guard_.markProcessed(packetId: id)
        XCTAssertEqual(guard_.checkDuplicateOnly(packet(packetId: id)), .duplicatePacketId(id))
    }

    // MARK: - cachedIdCount

    func testCachedIdCountReflectsActualCacheSize() {
        let guard_ = makeGuard()
        XCTAssertEqual(guard_.cachedIdCount, 0)
        guard_.checkDuplicateOnly(packet())
        XCTAssertEqual(guard_.cachedIdCount, 1)
        guard_.clearCache()
        XCTAssertEqual(guard_.cachedIdCount, 0)
    }
}
