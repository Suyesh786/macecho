
// PacketValidator.swift — Phase 10
//
// Implements the packet validation pipeline defined in
// 07_PROTOCOL_SPECIFICATION.md §Packet Validation Pipeline:
//
//   1. Validate protocol version.
//   2. Validate packet structure.
//   3. Validate sender identity.
//   4. Validate authentication state.        [DEFERRED — later phase]
//   5. Verify packet signature.               [DEFERRED — later phase]
//   6. Verify packet integrity.               [DEFERRED — later phase]
//   7. Validate packet freshness.             [DEFERRED — later phase]
//   8. Detect duplicate packet.               [DEFERRED — later phase]
//   9. Decrypt payload.                       [DEFERRED — later phase]
//   10. Execute command.                      [DEFERRED — later phase]
//
// "No implementation may change this processing order" (§Packet Validation
// Pipeline). All ten stages are represented, in this exact order, in
// `PacketValidator.validate(_:)`. Stages 1–3 are fully implemented per this
// phase's scope (serialization / deserialization / structural validation).
// Stages 4–10 are explicit placeholder hooks: each returns `.deferred` and
// performs no security-relevant check. A `.deferred` result must NEVER be
// treated as a passed check by calling code — see the doc comment on
// `PacketValidationStageResult` below.
//
// Must NOT contain:
//   - Authentication logic       → later phase (stage 4 is a stub here)
//   - Signature verification     → later phase (stage 5 is a stub here)
//   - Replay / freshness logic   → later phase (stage 7 is a stub here)
//   - Duplicate / sequence logic → later phase (stage 8 is a stub here)
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
/// a convenience `isFullyValidatedByThisPhase` flag.
struct PacketValidationReport {
    let results: [PacketValidationStage: PacketValidationStageResult]

    /// `true` only if every implemented stage (1–3) passed. This does NOT
    /// mean the packet is safe to decrypt or execute — stages 4–10 are
    /// deferred to later phases and must be run by them before any
    /// application logic touches this packet (§Payload Processing).
    var passedImplementedStages: Bool {
        [PacketValidationStage.protocolVersion, .packetStructure, .senderIdentity]
            .allSatisfy { results[$0] == .passed }
    }

    /// The first failure encountered among the implemented (non-deferred)
    /// stages, if any.
    var firstFailure: PacketValidationFailureReason? {
        for stage in [PacketValidationStage.protocolVersion, .packetStructure, .senderIdentity] {
            if case .failed(let reason) = results[stage] {
                return reason
            }
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
    /// report. Stages 4–10 always return `.deferred` in this phase.
    static func validate(_ packet: Packet, knownSenderIds: Set<String>) -> PacketValidationReport {
        var results: [PacketValidationStage: PacketValidationStageResult] = [:]

        // Stage 1 — Validate protocol version.
        results[.protocolVersion] = validateProtocolVersion(packet.header.protocolVersion)

        // Stage 2 — Validate packet structure.
        // By the time a `Packet` value exists, JSON structural decoding
        // (required fields, JSON correctness) has already succeeded via
        // PacketSerializer.deserialize(_:) / Codable. This stage re-affirms
        // that outcome and checks the remaining structural invariants that
        // Codable's type system cannot express (e.g. non-empty identifiers).
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

        // Stage 6 — Verify packet integrity.                [DEFERRED]
        results[.integrityVerification] = .deferred(
            reason: "Integrity verification is part of the cryptographic pipeline and is not implemented here."
        )

        // Stage 7 — Validate packet freshness.              [DEFERRED]
        results[.freshnessValidation] = .deferred(
            reason: "Freshness / clock-skew / replay validation is not implemented here."
        )

        // Stage 8 — Detect duplicate packet.                [DEFERRED]
        results[.duplicateDetection] = .deferred(
            reason: "Duplicate detection requires a processed-packet-ID cache maintained by a later phase and is not implemented here."
        )

        // Stage 9 — Decrypt payload.                        [DEFERRED]
        results[.payloadDecryption] = .deferred(
            reason: "Payload decryption is out of scope for Phase 10; the backend must never decrypt payloads and native clients decrypt only after all preceding stages are genuinely enforced."
        )

        // Stage 10 — Execute command.                       [DEFERRED]
        results[.commandExecution] = .deferred(
            reason: "Command execution is business logic and is not implemented here."
        )

        return PacketValidationReport(results: results)
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