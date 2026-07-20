
package com.macecho.app.protocol

/**
 * PacketValidator.kt — Phase 11 (updated from Phase 10)
 *
 * Implements the packet validation pipeline defined in
 * 07_PROTOCOL_SPECIFICATION.md §Packet Validation Pipeline:
 *
 *   1. Validate protocol version.               [IMPLEMENTED — Phase 10]
 *   2. Validate packet structure.               [IMPLEMENTED — Phase 10]
 *   3. Validate sender identity.                [IMPLEMENTED — Phase 10]
 *   4. Validate authentication state.           [DEFERRED — later phase]
 *   5. Verify packet signature.                 [DEFERRED — later phase]
 *   6. Verify packet integrity.                 [DEFERRED — later phase]
 *   7. Validate packet freshness.               [IMPLEMENTED — Phase 11]
 *   8. Detect duplicate packet.                 [IMPLEMENTED — Phase 11]
 *   9. Decrypt payload.                         [DEFERRED — later phase]
 *   10. Execute command.                        [DEFERRED — later phase]
 *
 * "No implementation may change this processing order" (§Packet Validation
 * Pipeline). All ten stages are represented, in this exact order, in
 * [PacketValidator.validate]. Stages 4–6, 9–10 remain [Deferred].
 *
 * Phase 11 additions:
 *   Stage 7 — Freshness validation is performed by [ReplayGuard].
 *   Stage 8 — Duplicate detection is performed by [ReplayGuard] (UUID) and
 *             [SequenceTracker] (stale sequence number).
 *
 * Must NOT contain:
 *   - Authentication logic       → later phase (stage 4 is a stub here)
 *   - Signature verification     → later phase (stage 5 is a stub here)
 *   - Integrity verification     → later phase (stage 6 is a stub here)
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
    /** Stage 7: packet timestamp is outside the configured clock-skew window. */
    data class StaleTimestamp(val packetTimestampMs: Long, val nowMs: Long, val skewMs: Long) : PacketValidationFailureReason()
    /** Stage 8: Packet UUID has already been processed (replay/duplicate). */
    data class DuplicatePacketId(val packetId: String) : PacketValidationFailureReason()
    /** Stage 8: Sequence number is below the staleness threshold (stale/replay). */
    data class StaleSequenceNumber(val sequenceNumber: Long, val nextExpected: Long) : PacketValidationFailureReason()
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
    /**
     * Stages that are actually implemented (non-deferred) in this build.
     * Stages 1–3 are always implemented (Phase 10).
     * Stages 7–8 are implemented when [ReplayGuard] and [SequenceTracker]
     * are supplied to [PacketValidator.validate]; otherwise they remain
     * Deferred and are excluded from this list.
     */
    private val implementedStages: List<PacketValidationStage>
        get() = PacketValidationStage.entries.filter {
            results[it] !is PacketValidationStageResult.Deferred
        }

    /**
     * `true` only if every non-deferred stage passed. A packet where any
     * stage is [Deferred] is NOT safe to decrypt or execute — the deferred
     * stages must be enforced before any application logic touches the
     * packet (§Payload Processing).
     */
    val passedImplementedStages: Boolean
        get() = implementedStages.all { results[it] is PacketValidationStageResult.Passed }

    /** The first failure among the non-deferred stages, if any. */
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
     * report.
     *
     * Stages 1–3: always evaluated (Protocol Version, Structure, Sender Identity).
     * Stage  7:   evaluated when [replayGuard] is supplied (Freshness Validation).
     * Stage  8:   evaluated when [replayGuard] and [sequenceTracker] are both
     *             supplied (Duplicate Detection).
     * Stages 4–6, 9–10: always Deferred (implemented in later phases).
     *
     * @param knownSenderIds    Identifiers the caller currently recognizes.
     *   Per §Sender Identity: "Unknown sender identities are rejected
     *   immediately." Checks set membership only — NOT authentication or
     *   trust (stages 4/5, deferred).
     * @param replayGuard       Optional [ReplayGuard] for Stage 7 freshness
     *   and UUID duplicate detection. When null, stages 7 and 8 (UUID half)
     *   remain Deferred.
     * @param sequenceTracker   Optional [SequenceTracker] for Stage 8 stale-
     *   sequence-number detection. When null, the sequence-number check in
     *   Stage 8 remains Deferred. Must not be supplied without [replayGuard].
     */
    fun validate(
        packet: Packet,
        knownSenderIds: Set<String>,
        replayGuard: ReplayGuard? = null,
        sequenceTracker: SequenceTracker? = null,
    ): PacketValidationReport {
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

        // Stage 6 — Verify packet integrity.               [DEFERRED]
        results[PacketValidationStage.INTEGRITY_VERIFICATION] = PacketValidationStageResult.Deferred(
            "Integrity verification is part of the cryptographic pipeline and is not implemented here."
        )

        // Stage 7 — Validate packet freshness.             [IMPLEMENTED when replayGuard != null]
        results[PacketValidationStage.FRESHNESS_VALIDATION] = if (replayGuard != null) {
            validateFreshness(packet, replayGuard)
        } else {
            PacketValidationStageResult.Deferred(
                "Freshness validation requires a ReplayGuard instance (Phase 11)."
            )
        }

        // Stage 8 — Detect duplicate packet.              [IMPLEMENTED when guards supplied]
        // Evaluated only if Stage 7 passed (a stale packet is also a replay;
        // no need to redundantly check duplicate cache for already-rejected packets).
        results[PacketValidationStage.DUPLICATE_DETECTION] = when {
            replayGuard == null -> PacketValidationStageResult.Deferred(
                "Duplicate detection requires a ReplayGuard instance (Phase 11)."
            )
            results[PacketValidationStage.FRESHNESS_VALIDATION] is PacketValidationStageResult.Failed -> {
                // Already failed at stage 7; treat as implicitly rejected here too.
                PacketValidationStageResult.Deferred(
                    "Stage 7 failed; Stage 8 skipped to avoid polluting the UUID cache with a rejected packet."
                )
            }
            else -> validateDuplicate(packet, replayGuard, sequenceTracker)
        }

        // Stage 9 — Decrypt payload.                       [DEFERRED]
        results[PacketValidationStage.PAYLOAD_DECRYPTION] = PacketValidationStageResult.Deferred(
            "Payload decryption requires authenticated trust material and is not implemented here."
        )

        // Stage 10 — Execute command.                      [DEFERRED]
        results[PacketValidationStage.COMMAND_EXECUTION] = PacketValidationStageResult.Deferred(
            "Command execution is business logic and is not implemented here."
        )

        return PacketValidationReport(results)
    }

    // -------------------------------------------------------------------
    // Stage 7 — Freshness validation
    // -------------------------------------------------------------------

    private fun validateFreshness(packet: Packet, replayGuard: ReplayGuard): PacketValidationStageResult =
        when (val result = replayGuard.checkFreshnessOnly(packet)) {
            is ReplayGuardResult.Fresh -> PacketValidationStageResult.Passed
            is ReplayGuardResult.StaleTimestamp -> PacketValidationStageResult.Failed(
                PacketValidationFailureReason.StaleTimestamp(
                    result.packetTimestampMs,
                    result.nowMs,
                    result.skewMs,
                )
            )
            // checkFreshnessOnly never returns DuplicatePacketId
            is ReplayGuardResult.DuplicatePacketId -> PacketValidationStageResult.Passed
        }

    // -------------------------------------------------------------------
    // Stage 8 — Duplicate detection
    // -------------------------------------------------------------------

    private fun validateDuplicate(
        packet: Packet,
        replayGuard: ReplayGuard,
        sequenceTracker: SequenceTracker?,
    ): PacketValidationStageResult {
        // UUID-based duplicate check via ReplayGuard.
        val guardResult = replayGuard.checkDuplicateOnly(packet)
        if (guardResult is ReplayGuardResult.DuplicatePacketId) {
            return PacketValidationStageResult.Failed(
                PacketValidationFailureReason.DuplicatePacketId(guardResult.packetId)
            )
        }

        // Sequence-number staleness check via SequenceTracker.
        if (sequenceTracker != null) {
            val seqResult = sequenceTracker.checkStaleness(packet)
            if (seqResult is SequenceCheckResult.Stale) {
                return PacketValidationStageResult.Failed(
                    PacketValidationFailureReason.StaleSequenceNumber(
                        seqResult.sequenceNumber,
                        seqResult.nextExpected,
                    )
                )
            }
        }

        return PacketValidationStageResult.Passed
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