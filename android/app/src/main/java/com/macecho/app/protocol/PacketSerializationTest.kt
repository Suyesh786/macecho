
package com.macecho.app.protocol

import org.junit.Assert.*
import org.junit.Test
import java.util.UUID

/**
 * PacketSerializationTest.kt — Phase 10 unit tests
 *
 * Covers: valid packets, malformed packets, missing required fields,
 * invalid packet types, and validation stages 1-3. Stages 4-10 are
 * asserted to always be Deferred, never Passed.
 */
class PacketSerializationTest {

    private fun samplePacket(
        protocolVersion: Int = 1,
        sessionId: String = UUID.randomUUID().toString(),
        senderId: String = "device-abc",
        packetId: String = UUID.randomUUID().toString(),
    ): Packet = Packet(
        header = PacketHeader(
            protocolVersion = protocolVersion,
            packetType = PacketType.HEARTBEAT,
            sessionId = sessionId,
            senderId = senderId,
            packetId = packetId,
            sequenceNumber = 1L,
            timestamp = 1_700_000_000_000L,
        ),
        metadata = PacketMetadata(
            retryCount = 0,
            priority = PacketPriority.NORMAL,
            messageCategory = PacketType.HEARTBEAT,
        ),
        encryptedPayload = byteArrayOf(1, 2, 3),
    )

    // -- Serialization round-trip --

    @Test
    fun validPacketRoundTrips() {
        val packet = samplePacket()
        val json = PacketSerializer.serialize(packet)
        val decoded = PacketSerializer.deserialize(json)
        assertEquals(packet.header.packetId, decoded.header.packetId)
        assertEquals(packet.header.senderId, decoded.header.senderId)
        assertArrayEquals(packet.encryptedPayload, decoded.encryptedPayload)
    }

    // -- Malformed JSON --

    @Test(expected = PacketSerializationException.DecodingFailed::class)
    fun malformedJsonThrows() {
        PacketSerializer.deserialize("{ this is not valid json")
    }

    // -- Missing required fields --

    @Test(expected = PacketSerializationException.DecodingFailed::class)
    fun missingHeaderFieldThrows() {
        val json = """
            { "metadata": { "retryCount": 0, "priority": "NORMAL", "messageCategory": "HEARTBEAT" },
              "encryptedPayload": "AQID" }
        """.trimIndent()
        PacketSerializer.deserialize(json)
    }

    @Test(expected = PacketSerializationException.DecodingFailed::class)
    fun missingPayloadFieldThrows() {
        val json = """
            { "header": { "protocolVersion": 1, "packetType": "HEARTBEAT",
                "sessionId": "${UUID.randomUUID()}", "senderId": "d1",
                "packetId": "${UUID.randomUUID()}", "sequenceNumber": 1, "timestamp": 1 },
              "metadata": { "retryCount": 0, "priority": "NORMAL", "messageCategory": "HEARTBEAT" } }
        """.trimIndent()
        PacketSerializer.deserialize(json)
    }

    // -- Invalid packet type --

    @Test(expected = PacketSerializationException.DecodingFailed::class)
    fun invalidPacketTypeThrows() {
        val json = """
            { "header": { "protocolVersion": 1, "packetType": "NOT_A_REAL_TYPE",
                "sessionId": "${UUID.randomUUID()}", "senderId": "d1",
                "packetId": "${UUID.randomUUID()}", "sequenceNumber": 1, "timestamp": 1 },
              "metadata": { "retryCount": 0, "priority": "NORMAL", "messageCategory": "HEARTBEAT" },
              "encryptedPayload": "AQID" }
        """.trimIndent()
        PacketSerializer.deserialize(json)
    }

    // -- PacketValidator: stage 1 (protocol version) --

    @Test
    fun unsupportedProtocolVersionFails() {
        val packet = samplePacket(protocolVersion = 999)
        val report = PacketValidator.validate(packet, setOf("device-abc"))
        val result = report.results[PacketValidationStage.PROTOCOL_VERSION]
        assertTrue(result is PacketValidationStageResult.Failed)
        assertFalse(report.passedImplementedStages)
    }

    // -- PacketValidator: stage 2 (structure) --

    @Test
    fun malformedPacketIdFailsStructureStage() {
        val packet = samplePacket(packetId = "not-a-uuid")
        val report = PacketValidator.validate(packet, setOf("device-abc"))
        assertTrue(report.results[PacketValidationStage.PACKET_STRUCTURE] is PacketValidationStageResult.Failed)
    }

    @Test
    fun emptySessionIdFailsStructureStage() {
        val packet = samplePacket(sessionId = "")
        val report = PacketValidator.validate(packet, setOf("device-abc"))
        val result = report.results[PacketValidationStage.PACKET_STRUCTURE]
        assertTrue(result is PacketValidationStageResult.Failed)
        assertEquals(
            PacketValidationFailureReason.MissingRequiredField("header.sessionId"),
            (result as PacketValidationStageResult.Failed).reason,
        )
    }

    // -- PacketValidator: stage 3 (sender identity) --

    @Test
    fun unknownSenderFailsSenderIdentityStage() {
        val packet = samplePacket(senderId = "unknown-device")
        val report = PacketValidator.validate(packet, setOf("device-abc"))
        val result = report.results[PacketValidationStage.SENDER_IDENTITY]
        assertEquals(
            PacketValidationFailureReason.UnknownSenderIdentity,
            (result as PacketValidationStageResult.Failed).reason,
        )
    }

    @Test
    fun knownSenderPassesSenderIdentityStage() {
        val packet = samplePacket(senderId = "device-abc")
        val report = PacketValidator.validate(packet, setOf("device-abc"))
        assertEquals(PacketValidationStageResult.Passed, report.results[PacketValidationStage.SENDER_IDENTITY])
    }

    // -- Valid packet passes all implemented stages --

    @Test
    fun fullyValidPacketPassesImplementedStages() {
        val packet = samplePacket()
        val report = PacketValidator.validate(packet, setOf("device-abc"))
        assertTrue(report.passedImplementedStages)
        assertNull(report.firstFailure)
    }

    // -- Deferred stages are never reported as passed --

    @Test
    fun stages4Through10AreAlwaysDeferredNeverPassed() {
        val packet = samplePacket()
        val report = PacketValidator.validate(packet, setOf("device-abc"))
        val deferredStages = listOf(
            PacketValidationStage.AUTHENTICATION_STATE,
            PacketValidationStage.SIGNATURE_VERIFICATION,
            PacketValidationStage.INTEGRITY_VERIFICATION,
            PacketValidationStage.FRESHNESS_VALIDATION,
            PacketValidationStage.DUPLICATE_DETECTION,
            PacketValidationStage.PAYLOAD_DECRYPTION,
            PacketValidationStage.COMMAND_EXECUTION,
        )
        for (stage in deferredStages) {
            val result = report.results[stage]
            assertTrue("Stage $stage must be Deferred, was $result", result is PacketValidationStageResult.Deferred)
        }
    }
}