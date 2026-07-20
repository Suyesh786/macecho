
// PacketSerializationTests.swift — Phase 10 unit tests
//
// Covers: valid packets, malformed packets, missing required fields,
// invalid packet types, and the documented validation stages 1-3
// (protocol version / structure / sender identity). Stages 4-10 are
// asserted to be `.deferred`, never `.passed`, confirming they cannot be
// mistaken for completed checks.

import XCTest
@testable import MacEcho

final class PacketSerializationTests: XCTestCase {

    private func samplePacket(
        protocolVersion: Int = 1,
        sessionId: String = UUID().uuidString,
        senderId: String = "device-abc",
        packetId: String = UUID().uuidString
    ) -> Packet {
        Packet(
            header: PacketHeader(
                protocolVersion: protocolVersion,
                packetType: .heartbeat,
                sessionId: sessionId,
                senderId: senderId,
                packetId: packetId,
                sequenceNumber: 1,
                timestamp: 1_700_000_000_000
            ),
            metadata: PacketMetadata(retryCount: 0, priority: .normal, messageCategory: .heartbeat),
            encryptedPayload: [0x01, 0x02, 0x03]
        )
    }

    // MARK: - Serialization round-trip

    func testValidPacketRoundTrips() throws {
        let packet = samplePacket()
        let data = try PacketSerializer.serialize(packet)
        let decoded = try PacketSerializer.deserialize(data)
        XCTAssertEqual(decoded.header.packetId, packet.header.packetId)
        XCTAssertEqual(decoded.header.senderId, packet.header.senderId)
        XCTAssertEqual(decoded.encryptedPayload, packet.encryptedPayload)
    }

    // MARK: - Malformed JSON

    func testMalformedJsonThrows() {
        let bad = "{ this is not valid json".data(using: .utf8)!
        XCTAssertThrowsError(try PacketSerializer.deserialize(bad)) { error in
            XCTAssertTrue(error is PacketSerializationError)
        }
    }

    // MARK: - Missing required fields

    func testMissingHeaderFieldThrows() {
        let json = """
        { "metadata": { "retryCount": 0, "priority": "NORMAL", "messageCategory": "HEARTBEAT" },
          "encryptedPayload": "AQID" }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try PacketSerializer.deserialize(json))
    }

    func testMissingPayloadFieldThrows() {
        let json = """
        { "header": { "protocolVersion": 1, "packetType": "HEARTBEAT",
            "sessionId": "\(UUID().uuidString)", "senderId": "d1",
            "packetId": "\(UUID().uuidString)", "sequenceNumber": 1, "timestamp": 1 },
          "metadata": { "retryCount": 0, "priority": "NORMAL", "messageCategory": "HEARTBEAT" } }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try PacketSerializer.deserialize(json))
    }

    // MARK: - Invalid packet type

    func testInvalidPacketTypeThrows() {
        let json = """
        { "header": { "protocolVersion": 1, "packetType": "NOT_A_REAL_TYPE",
            "sessionId": "\(UUID().uuidString)", "senderId": "d1",
            "packetId": "\(UUID().uuidString)", "sequenceNumber": 1, "timestamp": 1 },
          "metadata": { "retryCount": 0, "priority": "NORMAL", "messageCategory": "HEARTBEAT" },
          "encryptedPayload": "AQID" }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try PacketSerializer.deserialize(json))
    }

    // MARK: - PacketValidator: stage 1 (protocol version)

    func testUnsupportedProtocolVersionFails() {
        let packet = samplePacket(protocolVersion: 999)
        let report = PacketValidator.validate(packet, knownSenderIds: ["device-abc"])
        XCTAssertEqual(
            report.results[.protocolVersion],
            .failed(.unsupportedProtocolVersion(999))
        )
        XCTAssertFalse(report.passedImplementedStages)
    }

    // MARK: - PacketValidator: stage 2 (structure)

    func testMalformedPacketIdFailsStructureStage() {
        let packet = samplePacket(packetId: "not-a-uuid")
        let report = PacketValidator.validate(packet, knownSenderIds: ["device-abc"])
        if case .failed = report.results[.packetStructure]! {
            // expected
        } else {
            XCTFail("Expected packetStructure stage to fail for invalid UUID")
        }
    }

    func testEmptySessionIdFailsStructureStage() {
        let packet = samplePacket(sessionId: "")
        let report = PacketValidator.validate(packet, knownSenderIds: ["device-abc"])
        XCTAssertEqual(
            report.results[.packetStructure],
            .failed(.missingRequiredField("header.sessionId"))
        )
    }

    // MARK: - PacketValidator: stage 3 (sender identity / "invalid signatures" analog)
    //
    // The documentation's "invalid signatures" test case (10_TESTING_SPECIFICATION.md)
    // belongs to stage 5, which this phase explicitly defers. The nearest
    // Phase-10-owned analog — rejecting an unrecognized sender — is covered here.

    func testUnknownSenderFailsSenderIdentityStage() {
        let packet = samplePacket(senderId: "unknown-device")
        let report = PacketValidator.validate(packet, knownSenderIds: ["device-abc"])
        XCTAssertEqual(
            report.results[.senderIdentity],
            .failed(.unknownSenderIdentity)
        )
    }

    func testKnownSenderPassesSenderIdentityStage() {
        let packet = samplePacket(senderId: "device-abc")
        let report = PacketValidator.validate(packet, knownSenderIds: ["device-abc"])
        XCTAssertEqual(report.results[.senderIdentity], .passed)
    }

    // MARK: - Valid packet passes all implemented stages

    func testFullyValidPacketPassesImplementedStages() {
        let packet = samplePacket()
        let report = PacketValidator.validate(packet, knownSenderIds: ["device-abc"])
        XCTAssertTrue(report.passedImplementedStages)
        XCTAssertNil(report.firstFailure)
    }

    // MARK: - Deferred stages are never reported as passed

    func testStages4Through10AreAlwaysDeferredNeverPassed() {
        let packet = samplePacket()
        let report = PacketValidator.validate(packet, knownSenderIds: ["device-abc"])
        let deferredStages: [PacketValidationStage] = [
            .authenticationState, .signatureVerification, .integrityVerification,
            .freshnessValidation, .duplicateDetection, .payloadDecryption, .commandExecution,
        ]
        for stage in deferredStages {
            guard case .deferred = report.results[stage]! else {
                XCTFail("Stage \(stage) must be .deferred in Phase 10, was \(String(describing: report.results[stage]))")
                return
            }
        }
    }
}