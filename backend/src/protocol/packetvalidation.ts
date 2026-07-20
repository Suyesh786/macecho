
/**
 * packetValidation.ts — Phase 10
 *
 * Backend structural validation ONLY, per the project brief:
 * "The backend is ONLY a relay. It must NEVER: decrypt payloads, own
 * device private keys, authenticate devices, perform end-to-end
 * cryptography."
 *
 * The full 10-stage pipeline in 07_PROTOCOL_SPECIFICATION.md
 * §Packet Validation Pipeline is authored for a device (Android/macOS)
 * receiver. The backend performs only the structural subset it is
 * permitted to perform — stage 1 (protocol version) and stage 2
 * (packet structure) — and represents every other documented stage as
 * an explicit `deferred` result so the full ten-stage shape is visible
 * without the backend ever pretending to run stages it is architecturally
 * forbidden from running (authentication, signature, integrity, freshness,
 * duplicate detection, decryption, execution — and, uniquely for the
 * backend, these are permanently out of scope, not merely deferred to a
 * later Phase 10 sub-step).
 *
 * Must NOT contain:
 *   - Decryption                    → forbidden for the backend entirely
 *   - Authentication / trust logic  → forbidden for the backend entirely
 *   - Signature verification        → forbidden for the backend entirely
 *   - Replay / freshness / sequence → forbidden for the backend entirely
 *   - Business logic of any kind
 */

import type { Packet, PacketType } from "./packets.js";

// ---------------------------------------------------------------------------
// Supported protocol versions
// ---------------------------------------------------------------------------

/** Only Version 1 is defined by 07_PROTOCOL_SPECIFICATION.md. */
export const SUPPORTED_PROTOCOL_VERSIONS: ReadonlySet<number> = new Set([1]);

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

export type PacketValidationFailureReason =
  | { kind: "unsupportedProtocolVersion"; version: number }
  | { kind: "malformedStructure"; detail: string }
  | { kind: "missingRequiredField"; fieldName: string };

/**
 * `deferred` is NOT a pass. For the backend, every deferred stage is
 * permanently out of scope (not merely deferred to a later phase of this
 * project) — the backend must never implement it. Callers must never
 * treat `deferred` as authorization to route a payload for decryption or
 * execution; that authority belongs entirely to the receiving device.
 */
export type PacketValidationStageResult =
  | { status: "passed" }
  | { status: "failed"; reason: PacketValidationFailureReason }
  | { status: "deferred"; reason: string };

export type PacketValidationStage =
  | "PROTOCOL_VERSION"
  | "PACKET_STRUCTURE"
  | "SENDER_IDENTITY"
  | "AUTHENTICATION_STATE"
  | "SIGNATURE_VERIFICATION"
  | "INTEGRITY_VERIFICATION"
  | "FRESHNESS_VALIDATION"
  | "DUPLICATE_DETECTION"
  | "PAYLOAD_DECRYPTION"
  | "COMMAND_EXECUTION";

export const PACKET_VALIDATION_STAGE_ORDER: readonly PacketValidationStage[] = [
  "PROTOCOL_VERSION",
  "PACKET_STRUCTURE",
  "SENDER_IDENTITY",
  "AUTHENTICATION_STATE",
  "SIGNATURE_VERIFICATION",
  "INTEGRITY_VERIFICATION",
  "FRESHNESS_VALIDATION",
  "DUPLICATE_DETECTION",
  "PAYLOAD_DECRYPTION",
  "COMMAND_EXECUTION",
];

export interface PacketValidationReport {
  results: Record<PacketValidationStage, PacketValidationStageResult>;
  /**
   * `true` only if stages the backend is permitted to run (1–2) passed.
   * The backend never claims to validate sender identity, authentication,
   * signatures, integrity, freshness, or duplicates — those remain
   * exclusively the receiving device's responsibility.
   */
  passedBackendPermittedStages: boolean;
}

// ---------------------------------------------------------------------------
// Validator
// ---------------------------------------------------------------------------

const KNOWN_PACKET_TYPES: ReadonlySet<string> = new Set([
  "AUTH_REQUEST", "AUTH_CHALLENGE", "AUTH_RESPONSE", "AUTH_SUCCESS", "AUTH_FAILURE",
  "PAIR_REQUEST", "PAIR_RESPONSE", "PAIR_IDENTITY_EXCHANGE", "PAIR_KEY_EXCHANGE",
  "PAIR_CONFIRMATION", "PAIR_CANCELLATION",
  "SESSION_START", "SESSION_READY", "SESSION_CLOSING", "SESSION_CLOSED", "SESSION_RECOVERY",
  "NOTIFICATION_CREATED", "NOTIFICATION_UPDATED", "NOTIFICATION_REMOVED", "NOTIFICATION_REPLY",
  "CALL_INCOMING", "CALL_UPDATED", "CALL_ENDED", "CALL_ACCEPTED", "CALL_DECLINED",
  "RING_PHONE",
  "SYNC_INITIAL", "SYNC_REFRESH",
  "ACK", "NACK",
  "HEARTBEAT",
  "ERROR",
]);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Runs the documented 10-stage pipeline, restricted to what the backend is
 * architecturally permitted to perform (stages 1–2). Stages 3–10 are always
 * `deferred` for the backend — permanently, per the project's relay-only
 * architecture, not just for this phase.
 */
export function validatePacketStructure(packet: Packet): PacketValidationReport {
  const results = {} as Record<PacketValidationStage, PacketValidationStageResult>;

  // Stage 1 — Validate protocol version.
  results.PROTOCOL_VERSION = SUPPORTED_PROTOCOL_VERSIONS.has(packet.header.protocolVersion)
    ? { status: "passed" }
    : {
        status: "failed",
        reason: { kind: "unsupportedProtocolVersion", version: packet.header.protocolVersion },
      };

  // Stage 2 — Validate packet structure.
  results.PACKET_STRUCTURE = checkStructure(packet);

  // Stage 3 — Validate sender identity.               [OUT OF SCOPE for backend]
  results.SENDER_IDENTITY = {
    status: "deferred",
    reason:
      "Sender identity / trust validation requires cryptographic trust material the backend must never hold; this stage belongs exclusively to the receiving device.",
  };

  // Stage 4 — Validate authentication state.          [OUT OF SCOPE for backend]
  results.AUTHENTICATION_STATE = {
    status: "deferred",
    reason: "The backend must never authenticate devices; this stage belongs exclusively to the receiving device.",
  };

  // Stage 5 — Verify packet signature.                 [OUT OF SCOPE for backend]
  results.SIGNATURE_VERIFICATION = {
    status: "deferred",
    reason: "The backend must never verify signatures or hold key material; this stage belongs exclusively to the receiving device.",
  };

  // Stage 6 — Verify packet integrity.                 [OUT OF SCOPE for backend]
  results.INTEGRITY_VERIFICATION = {
    status: "deferred",
    reason: "Integrity verification is part of the end-to-end cryptographic pipeline the backend must never perform.",
  };

  // Stage 7 — Validate packet freshness.               [OUT OF SCOPE for backend]
  results.FRESHNESS_VALIDATION = {
    status: "deferred",
    reason: "Freshness / clock-skew / replay validation belongs exclusively to the receiving device.",
  };

  // Stage 8 — Detect duplicate packet.                 [OUT OF SCOPE for backend]
  results.DUPLICATE_DETECTION = {
    status: "deferred",
    reason: "Duplicate detection belongs exclusively to the receiving device.",
  };

  // Stage 9 — Decrypt payload.                          [FORBIDDEN for backend]
  results.PAYLOAD_DECRYPTION = {
    status: "deferred",
    reason: "The backend must NEVER decrypt payloads (relay-only architecture).",
  };

  // Stage 10 — Execute command.                         [FORBIDDEN for backend]
  results.COMMAND_EXECUTION = {
    status: "deferred",
    reason: "Command execution is business logic on the receiving device; the backend never executes commands.",
  };

  const passedBackendPermittedStages =
    results.PROTOCOL_VERSION.status === "passed" && results.PACKET_STRUCTURE.status === "passed";

  return { results, passedBackendPermittedStages };
}

function checkStructure(packet: Packet): PacketValidationStageResult {
  const h = packet.header;

  if (!h.sessionId) {
    return { status: "failed", reason: { kind: "missingRequiredField", fieldName: "header.sessionId" } };
  }
  if (!h.senderId) {
    return { status: "failed", reason: { kind: "missingRequiredField", fieldName: "header.senderId" } };
  }
  if (!h.packetId) {
    return { status: "failed", reason: { kind: "missingRequiredField", fieldName: "header.packetId" } };
  }
  if (!UUID_RE.test(h.packetId)) {
    return {
      status: "failed",
      reason: { kind: "malformedStructure", detail: "header.packetId is not a valid UUID" },
    };
  }
  if (!UUID_RE.test(h.sessionId)) {
    return {
      status: "failed",
      reason: { kind: "malformedStructure", detail: "header.sessionId is not a valid UUID" },
    };
  }
  if (!KNOWN_PACKET_TYPES.has(h.packetType as unknown as string)) {
    return {
      status: "failed",
      reason: { kind: "malformedStructure", detail: `Unknown packetType '${h.packetType}'` },
    };
  }
  if (!KNOWN_PACKET_TYPES.has(packet.metadata.messageCategory as unknown as string)) {
    return {
      status: "failed",
      reason: { kind: "malformedStructure", detail: `Unknown messageCategory '${packet.metadata.messageCategory}'` },
    };
  }

  return { status: "passed" };
}

// Re-exported for callers that only need the type list, not the checker.
export type { PacketType };