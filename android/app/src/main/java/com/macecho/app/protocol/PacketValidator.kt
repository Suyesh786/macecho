
package com.macecho.app.protocol

/**
 * PacketValidator.kt — Phase 10
 *
 * Implements the packet validation pipeline defined in
 * 07_PROTOCOL_SPECIFICATION.md §Packet Validation Pipeline:
 *
 *   1. Validate protocol version.
 *   2. Validate packet structure.
 *   3. Validate sender identity.
 *   4. Validate authentication state.        [DEFERRED — later phase]
 *   5. Verify packet signature.               [DEFERRED — later phase]
 *   6. Verify packet integrity.               [DEFERRED — later phase]
 *   7. Validate packet freshness.             [DEFERRED — later phase]
 *   8. Detect duplicate packet.               [DEFERRED — later phase]
 *   9. Decrypt payload.                       [DEFERRED — later phase]
 *   10. Execute command.                      [DEFERRED — later phase]
 *
 * "No implementation may change this processing order" (§Packet Validation
 * Pipeline). All ten stages are represented, in this exact order, in
 * [PacketValidator.validate]. Stages 1–3 are fully implemented per this
 * phase's scope. Stages 4–10 are explicit placeholder hooks: each returns
 * [PacketValidationStageResult.Deferred] and performs no security-relevant
 * check. A `Deferred` result must NEVER be treated as a passed check by
 * calling code.
 *
 * Must NOT contain:
 *   - Authentication logic       → later phase (stage 4 is a stub here)
 *   - Signature verification     → later phase (stage 5 is a stub here)
 *   - Replay / freshness logic   → later phase (stage 7 is a stub here)
 *   - Duplicate / sequence logic → later phase (stage 8 is a stub here)
 *   - Decryption                 → later phase (stage 9 is a stub here)
 *   - Command execution          → later phase (stage 10 is a stub here)
 *   - Business logic of any kind
 */

import java.util.UUID

// ---------------------------------------------------------------------------
// Supported protocol versions
// ---------------------------------------------------------------------------

/**
 * Protocol versions this build can process. Only Version 1 is defined by
 * the documentation (07_PROTOCOL_SPECIFICATION.md never defines a Version 2).
 */
object SupportedProtocolVersion {
    const val CURRENT = 1
    val SUPPORTED = setOf(1)
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/**
 * Reasons a packet may be rejected, per
 * 07_PROTOCOL_SPECIFICATION.md §Invalid Packet Handling.
 */
sealed class PacketValidationFailureReason {
    data class UnsupportedProtocolVersion(val version: Int) : PacketValidationFailureReason()
    data class MalformedStructure(val detail: String) : PacketValidationFailureReason()
    data class MissingRequiredField(val fieldName: String) : PacketValidationFailureReason()
    object UnknownSenderIdentity : PacketValidationFailureReason()
}

/**
 * The outcome of a single validation stage.
 *
 * [Deferred] is NOT a pass. It exists solely to make later-phase stages
 * structurally present in the pipeline (per documentation: "No
 * implementation may change this processing order") without performing,
 * or appearing to perform, the actual security check. Callers must treat
 * a packet as *not fully validated* by this phase's [PacketValidator]
 * alone whenever any stage result is [Deferred] — full accept/reject
 * authority for those stages belongs to the phase that implements them.
 */
sealed class PacketValidationStageResult {
    object Passed : PacketValidationStageResult()
    data class Failed(val reason: PacketValidationFailureReason) : PacketValidationStageResult()
    /** Explicit placeholder: this stage is NOT implemented in Phase 10. */
    data class Deferred(val reason: String) : PacketValidationStageResult()
}

/** Identifies each of the ten documented pipeline stages, in order. */
enum class PacketValidationStage {
    PROTOCOL_VERSION,
    PACKET_STRUCTURE,
    SENDER_IDENTITY,
    AUTHENTICATION_STATE,
    SIGNATURE_VERIFICATION,
    INTEGRITY_VERIFICATION,
    FRESHNESS_VALIDATION,
    DUPLICATE_DETECTION,
    PAYLOAD_DECRYPTION,
    COMMAND_EXECUTION,
}

/**
 * Full pipeline outcome: every stage's result, in documented order.
 *
 * @property results map keyed by stage, in the fixed documented order.
 */
data class PacketValidationReport(
    val results: Map<PacketValidationStage, PacketValidationStageResult>,
) {
    private val implementedStages = listOf(
        PacketValidationStage.PROTOCOL_VERSION,
        PacketValidationStage.PACKET_STRUCTURE,
        PacketValidationStage.SENDER_IDENTITY,
    )

    /**
     * `true` only if every implemented stage (1–3) passed. This does NOT
     * mean the packet is safe to decrypt or execute — stages 4–10 are
     * deferred to later phases and must be run by them before any
     * application logic touches this packet (§Payload Processing).
     */
    val passedImplementedStages: Boolean
        get() = implementedStages.all { results[it] is PacketValidationStageResult.Passed }

    /** The first failure among the implemented (non-deferred) stages, if any. */
    val firstFailure: PacketValidationFailureReason?
        get() = implementedStages
            .mapNotNull { (results[it] as? PacketValidationStageResult.Failed)?.reason }
            .firstOrNull()
}

// ---------------------------------------------------------------------------
// PacketValidator
// ---------------------------------------------------------------------------

/**
 * Executes the documented 10-stage validation pipeline against an already
 * JSON-decoded [Packet] (see [PacketSerializer.deserialize]).
 *
 * Stage order is fixed and must never be reordered, merged, or skipped
 * (§Packet Validation Pipeline: "No implementation may change this
 * processing order").
 */
object PacketValidator {

    /**
     * Runs all ten pipeline stages in documented order and returns a full
     * report. Stages 4–10 always return [PacketValidationStageResult.Deferred]
     * in this phase.
     *
     * @param knownSenderIds identifiers the caller currently recognizes
     *   (e.g. from an existing session/trust listing). Per §Sender Identity,
     *   ("Unknown sender identities are rejected immediately") — this stage
     *   only checks set membership, NOT authentication or trust (stages 4/5,
     *   deferred).
     */
    fun validate(packet: Packet, knownSenderIds: Set<String>): PacketValidationReport {
        val results = mutableMapOf<PacketValidationStage, PacketValidationStageResult>()

        // Stage 1 — Validate protocol version.
        results[PacketValidationStage.PROTOCOL_VERSION] =
            validateProtocolVersion(packet.header.protocolVersion)

        // Stage 2 — Validate packet structure.
        // By the time a Packet value exists, JSON structural decoding
        // (required fields, JSON correctness) has already succeeded via
        // PacketSerializer.deserialize(). This stage re-affirms that
        // outcome and checks structural invariants the type system alone
        // cannot express (e.g. non-empty / well-formed identifiers).
        results[PacketValidationStage.PACKET_STRUCTURE] = validatePacketStructure(packet)

        // Stage 3 — Validate sender identity.
        results[PacketValidationStage.SENDER_IDENTITY] =
            validateSenderIdentity(packet.header.senderId, knownSenderIds)

        // Stage 4 — Validate authentication state.        [DEFERRED]
        results[PacketValidationStage.AUTHENTICATION_STATE] = PacketValidationStageResult.Deferred(
            "Authentication state validation belongs to the authentication phase (Phase 13) and is not implemented here."
        )

        // Stage 5 — Verify packet signature.               [DEFERRED]
        results[PacketValidationStage.SIGNATURE_VERIFICATION] = PacketValidationStageResult.Deferred(
            "Signature verification requires trust/key material from later phases and is not implemented here."
        )

        // Stage 6 — Verify packet integrity.                [DEFERRED]
        results[PacketValidationStage.INTEGRITY_VERIFICATION] = PacketValidationStageResult.Deferred(
            "Integrity verification is part of the cryptographic pipeline and is not implemented here."
        )

        // Stage 7 — Validate packet freshness.              [DEFERRED]
        results[PacketValidationStage.FRESHNESS_VALIDATION] = PacketValidationStageResult.Deferred(
            "Freshness / clock-skew / replay validation is not implemented here."
        )

        // Stage 8 — Detect duplicate packet.                [DEFERRED]
        results[PacketValidationStage.DUPLICATE_DETECTION] = PacketValidationStageResult.Deferred(
            "Duplicate detection requires a processed-packet-ID cache maintained by a later phase and is not implemented here."
        )

        // Stage 9 — Decrypt payload.                        [DEFERRED]
        results[PacketValidationStage.PAYLOAD_DECRYPTION] = PacketValidationStageResult.Deferred(
            "Payload decryption is out of scope for Phase 10; native clients decrypt only after all preceding stages are genuinely enforced."
        )

        // Stage 10 — Execute command.                       [DEFERRED]
        results[PacketValidationStage.COMMAND_EXECUTION] = PacketValidationStageResult.Deferred(
            "Command execution is business logic and is not implemented here."
        )

        return PacketValidationReport(results)
    }

    // -------------------------------------------------------------------
    // Stage 1 — Protocol version
    // -------------------------------------------------------------------

    private fun validateProtocolVersion(version: Int): PacketValidationStageResult =
        if (SupportedProtocolVersion.SUPPORTED.contains(version)) {
            PacketValidationStageResult.Passed
        } else {
            PacketValidationStageResult.Failed(
                PacketValidationFailureReason.UnsupportedProtocolVersion(version)
            )
        }

    // -------------------------------------------------------------------
    // Stage 2 — Packet structure
    // -------------------------------------------------------------------

    private fun validatePacketStructure(packet: Packet): PacketValidationStageResult {
        if (packet.header.sessionId.isEmpty()) {
            return PacketValidationStageResult.Failed(
                PacketValidationFailureReason.MissingRequiredField("header.sessionId")
            )
        }
        if (packet.header.senderId.isEmpty()) {
            return PacketValidationStageResult.Failed(
                PacketValidationFailureReason.MissingRequiredField("header.senderId")
            )
        }
        if (packet.header.packetId.isEmpty()) {
            return PacketValidationStageResult.Failed(
                PacketValidationFailureReason.MissingRequiredField("header.packetId")
            )
        }
        if (!isValidUuid(packet.header.packetId)) {
            return PacketValidationStageResult.Failed(
                PacketValidationFailureReason.MalformedStructure("header.packetId is not a valid UUID")
            )
        }
        if (!isValidUuid(packet.header.sessionId)) {
            return PacketValidationStageResult.Failed(
                PacketValidationFailureReason.MalformedStructure("header.sessionId is not a valid UUID")
            )
        }
        return PacketValidationStageResult.Passed
    }

    private fun isValidUuid(value: String): Boolean =
        try {
            UUID.fromString(value)
            true
        } catch (e: IllegalArgumentException) {
            false
        }

    // -------------------------------------------------------------------
    // Stage 3 — Sender identity
    // -------------------------------------------------------------------

    private fun validateSenderIdentity(
        senderId: String,
        knownSenderIds: Set<String>,
    ): PacketValidationStageResult {
        if (senderId.isEmpty()) {
            return PacketValidationStageResult.Failed(
                PacketValidationFailureReason.MissingRequiredField("header.senderId")
            )
        }
        return if (knownSenderIds.contains(senderId)) {
            PacketValidationStageResult.Passed
        } else {
            PacketValidationStageResult.Failed(PacketValidationFailureReason.UnknownSenderIdentity)
        }
    }
}