
// PacketValidator.swift — Phase 11 (updated from Phase 10)
//
// Implements the packet validation pipeline defined in
// 07_PROTOCOL_SPECIFICATION.md §Packet Validation Pipeline:
//
//   1. Validate protocol version.               [IMPLEMENTED — Phase 10]
//   2. Validate packet structure.               [IMPLEMENTED — Phase 10]
//   3. Validate sender identity.                [IMPLEMENTED — Phase 10]
//   4. Validate authentication state.           [DEFERRED — later phase]
//   5. Verify packet signature.                 [DEFERRED — later phase]
//   6. Verify packet integrity.                 [DEFERRED — later phase]
//   7. Validate packet freshness.               [IMPLEMENTED — Phase 11]
//   8. Detect duplicate packet.                 [IMPLEMENTED — Phase 11]
//   9. Decrypt payload.                         [DEFERRED — later phase]
//   10. Execute command.                        [DEFERRED — later phase]
//
// "No implementation may change this processing order" (§Packet Validation
// Pipeline). All ten stages are represented, in this exact order, in
// `PacketValidator.validate(_:)`. Stages 4–6, 9–10 remain `.deferred`.
//
// Phase 11 additions:
//   Stage 7 — Freshness validation is performed by ReplayGuard.
//   Stage 8 — Duplicate detection is performed by ReplayGuard (UUID) and
//             SequenceTracker (stale sequence number).
//
// Must NOT contain:
//   - Authentication logic       → later phase (stage 4 is a stub here)
//   - Signature verification     → later phase (stage 5 is a stub here)
//   - Integrity verification     → later phase (stage 6 is a stub here)
//   - Decryption                 → later phase (stage 9 is a stub here)
//   - Command execution          → later phase (stage 10 is a stub here)
//   - Business logic of any kind

import Foundation

// ---------------------------------------------------------------------------
// Supported protocol versions
// ---------------------------------------------------------------------------

/// Protocol versions this build can process. Only Version 1 is defined by
/// the documentation (07_PROTOCOL_SPECIFICATION.md never defines a Version 2).
enum SupportedProtocolVersion {
    static let current = 1
    static let supported: Set<Int> = [1]
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// The outcome of a single validation stage.
///
/// `.deferred` is NOT a pass. It exists solely to make later-phase stages
/// structurally present in the pipeline (per documentation: "No
/// implementation may change this processing order") without performing,
/// or appearing to perform, the actual security check. Callers must treat
/// a packet as *not fully validated* by this phase's `PacketValidator`
/// alone whenever any stage result is `.deferred` — full accept/reject
/// authority for those stages belongs to the phase that implements them.
enum PacketValidationStageResult: Equatable {
    case passed
    case failed(PacketValidationFailureReason)
    /// Explicit placeholder: this stage is NOT implemented in Phase 10.
    case deferred(reason: String)
}

/// Reasons a packet may be rejected, per
/// 07_PROTOCOL_SPECIFICATION.md §Invalid Packet Handling.
enum PacketValidationFailureReason: Equatable {
    case unsupportedProtocolVersion(Int)
    case malformedStructure(String)
    case missingRequiredField(String)
    case unknownSenderIdentity
    /// Stage 7: packet timestamp is outside the configured clock-skew window.
    case staleTimestamp(packetTimestampMs: Int64, nowMs: Int64, skewMs: Int64)
    /// Stage 8: Packet UUID has already been processed (replay/duplicate).
    case duplicatePacketId(String)
    /// Stage 8: Sequence number is below the staleness threshold.
    case staleSequenceNumber(sequenceNumber: Int64, nextExpected: Int64)
}

/// Identifies each of the ten documented pipeline stages, in order.
enum PacketValidationStage: Int, CaseIterable {
    case protocolVersion = 1
    case packetStructure = 2
    case senderIdentity = 3
    case authenticationState = 4
    case signatureVerification = 5
    case integrityVerification = 6
    case freshnessValidation = 7
    case duplicateDetection = 8
    case payloadDecryption = 9
    case commandExecution = 10
}

/// Full pipeline outcome: every stage's result, in documented order, plus
/// a convenience `passedImplementedStages` flag.
struct PacketValidationReport {
    let results: [PacketValidationStage: PacketValidationStageResult]

    /// `true` only if every non-deferred stage passed. A packet where any
    /// stage is `.deferred` is NOT safe to decrypt or execute — the deferred
    /// stages must be enforced before any application logic touches this
    /// packet (§Payload Processing).
    var passedImplementedStages: Bool {
        PacketValidationStage.allCases
            .filter { if case .deferred = results[$0]! { return false }; return true }
            .allSatisfy { results[$0] == .passed }
    }

    /// The first failure encountered among the non-deferred stages, if any.
    var firstFailure: PacketValidationFailureReason? {
        for stage in PacketValidationStage.allCases {
            guard let result = results[stage] else { continue }
            if case .deferred = result { continue }
            if case .failed(let reason) = result { return reason }
        }
        return nil
    }
}

// ---------------------------------------------------------------------------
// PacketValidator
// ---------------------------------------------------------------------------

/// Executes the documented 10-stage validation pipeline against an already
/// JSON-decoded `Packet` (see `PacketSerializer.deserialize(_:)`).
///
/// Stage order is fixed and must never be reordered, merged, or skipped
/// (§Packet Validation Pipeline: "No implementation may change this
/// processing order").
enum PacketValidator {

    /// Runs all ten pipeline stages in documented order and returns a full
    /// report.
    ///
    /// Stages 1–3: always evaluated (Protocol Version, Structure, Sender Identity).
    /// Stage  7:   evaluated when `replayGuard` is supplied (Freshness Validation).
    /// Stage  8:   evaluated when `replayGuard` and `sequenceTracker` are both
    ///             supplied (Duplicate Detection).
    /// Stages 4–6, 9–10: always `.deferred` (implemented in later phases).
    ///
    /// - Parameter knownSenderIds: Identifiers the caller currently recognizes.
    ///   Per §Sender Identity: "Unknown sender identities are rejected
    ///   immediately." Checks set membership only — NOT authentication/trust.
    /// - Parameter replayGuard: Optional `ReplayGuard` for Stage 7 freshness
    ///   and UUID duplicate detection. When `nil`, stages 7 and 8 (UUID half)
    ///   remain `.deferred`.
    /// - Parameter sequenceTracker: Optional `SequenceTracker` for Stage 8
    ///   stale-sequence-number detection. Must not be supplied without
    ///   `replayGuard`.
    static func validate(
        _ packet: Packet,
        knownSenderIds: Set<String>,
        replayGuard: ReplayGuard? = nil,
        sequenceTracker: SequenceTracker? = nil
    ) -> PacketValidationReport {
        var results: [PacketValidationStage: PacketValidationStageResult] = [:]

        // Stage 1 — Validate protocol version.
        results[.protocolVersion] = validateProtocolVersion(packet.header.protocolVersion)

        // Stage 2 — Validate packet structure.
        results[.packetStructure] = validatePacketStructure(packet)

        // Stage 3 — Validate sender identity.
        results[.senderIdentity] = validateSenderIdentity(
            packet.header.senderId,
            knownSenderIds: knownSenderIds
        )

        // Stage 4 — Validate authentication state.        [DEFERRED]
        results[.authenticationState] = .deferred(
            reason: "Authentication state validation belongs to the authentication phase (Phase 13) and is not implemented here."
        )

        // Stage 5 — Verify packet signature.               [DEFERRED]
        results[.signatureVerification] = .deferred(
            reason: "Signature verification requires trust/key material from later phases and is not implemented here."
        )

        // Stage 6 — Verify packet integrity.               [DEFERRED]
        results[.integrityVerification] = .deferred(
            reason: "Integrity verification is part of the cryptographic pipeline and is not implemented here."
        )

        // Stage 7 — Validate packet freshness.             [IMPLEMENTED when replayGuard != nil]
        if let guard7 = replayGuard {
            results[.freshnessValidation] = validateFreshness(packet, replayGuard: guard7)
        } else {
            results[.freshnessValidation] = .deferred(
                reason: "Freshness validation requires a ReplayGuard instance (Phase 11)."
            )
        }

        // Stage 8 — Detect duplicate packet.              [IMPLEMENTED when guards supplied]
        // Only evaluated when Stage 7 passed; if Stage 7 failed we skip Stage 8
        // to avoid polluting the UUID cache with a rejected packet.
        let stage7Result = results[.freshnessValidation]!
        if let guard8 = replayGuard {
            if case .failed = stage7Result {
                results[.duplicateDetection] = .deferred(
                    reason: "Stage 7 failed; Stage 8 skipped to avoid polluting the UUID cache."
                )
            } else {
                results[.duplicateDetection] = validateDuplicate(
                    packet,
                    replayGuard: guard8,
                    sequenceTracker: sequenceTracker
                )
            }
        } else {
            results[.duplicateDetection] = .deferred(
                reason: "Duplicate detection requires a ReplayGuard instance (Phase 11)."
            )
        }

        // Stage 9 — Decrypt payload.                       [DEFERRED]
        results[.payloadDecryption] = .deferred(
            reason: "Payload decryption requires authenticated trust material and is not implemented here."
        )

        // Stage 10 — Execute command.                      [DEFERRED]
        results[.commandExecution] = .deferred(
            reason: "Command execution is business logic and is not implemented here."
        )

        return PacketValidationReport(results: results)
    }

    // -----------------------------------------------------------------------
    // Stage 7 — Freshness validation
    // -----------------------------------------------------------------------

    private static func validateFreshness(
        _ packet: Packet,
        replayGuard: ReplayGuard
    ) -> PacketValidationStageResult {
        switch replayGuard.checkFreshnessOnly(packet) {
        case .fresh:
            return .passed
        case .staleTimestamp(let ts, let now, let skew):
            return .failed(.staleTimestamp(packetTimestampMs: ts, nowMs: now, skewMs: skew))
        case .duplicatePacketId:
            // checkFreshnessOnly never returns this case
            return .passed
        }
    }

    // -----------------------------------------------------------------------
    // Stage 8 — Duplicate detection
    // -----------------------------------------------------------------------

    private static func validateDuplicate(
        _ packet: Packet,
        replayGuard: ReplayGuard,
        sequenceTracker: SequenceTracker?
    ) -> PacketValidationStageResult {
        // UUID-based duplicate check via ReplayGuard.
        switch replayGuard.checkDuplicateOnly(packet) {
        case .duplicatePacketId(let id):
            return .failed(.duplicatePacketId(id))
        default:
            break
        }

        // Sequence-number staleness check via SequenceTracker.
        if let tracker = sequenceTracker {
            switch tracker.checkStaleness(packet) {
            case .stale(let seq, let expected):
                return .failed(.staleSequenceNumber(sequenceNumber: seq, nextExpected: expected))
            default:
                break
            }
        }

        return .passed
    }

    // -----------------------------------------------------------------------
    // Stage 1 — Protocol version
    // -----------------------------------------------------------------------

    private static func validateProtocolVersion(_ version: Int) -> PacketValidationStageResult {
        SupportedProtocolVersion.supported.contains(version)
            ? .passed
            : .failed(.unsupportedProtocolVersion(version))
    }

    // -----------------------------------------------------------------------
    // Stage 2 — Packet structure
    // -----------------------------------------------------------------------

    private static func validatePacketStructure(_ packet: Packet) -> PacketValidationStageResult {
        if packet.header.sessionId.isEmpty {
            return .failed(.missingRequiredField("header.sessionId"))
        }
        if packet.header.senderId.isEmpty {
            return .failed(.missingRequiredField("header.senderId"))
        }
        if packet.header.packetId.isEmpty {
            return .failed(.missingRequiredField("header.packetId"))
        }
        if UUID(uuidString: packet.header.packetId) == nil {
            return .failed(.malformedStructure("header.packetId is not a valid UUID"))
        }
        if UUID(uuidString: packet.header.sessionId) == nil {
            return .failed(.malformedStructure("header.sessionId is not a valid UUID"))
        }
        return .passed
    }

    // -----------------------------------------------------------------------
    // Stage 3 — Sender identity
    // -----------------------------------------------------------------------

    /// Per §Sender Identity: "Unknown sender identities are rejected
    /// immediately." This phase checks only that the sender identifier is
    /// present in the caller-supplied set of known identifiers — it does
    /// NOT verify authentication or trust (those are stages 4/5, deferred).
    ///
    /// - Parameter knownSenderIds: Identifiers the caller currently
    ///   recognizes (e.g. from an existing session/trust listing). Passing
    ///   an empty set means "no sender is yet known," which will fail
    ///   every packet — callers integrating this in later phases are
    ///   expected to supply the real set.
    private static func validateSenderIdentity(
        _ senderId: String,
        knownSenderIds: Set<String>
    ) -> PacketValidationStageResult {
        guard !senderId.isEmpty else {
            return .failed(.missingRequiredField("header.senderId"))
        }
        return knownSenderIds.contains(senderId) ? .passed : .failed(.unknownSenderIdentity)
    }
}