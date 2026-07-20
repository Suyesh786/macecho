// NEW FILE
// Path: backend/src/protocol/packetSerialization.ts
// File: backend/src/protocol/packetSerialization.ts
/**
 * packetSerialization.ts — Phase 10
 *
 * JSON serialization / deserialization for the protocol packet shape
 * defined in packets.ts (Phase 6), per Architecture Decision 17 ("All
 * protocol packets are serialized using JSON").
 *
 * The backend is a relay ONLY (project brief): it must never decrypt
 * payloads, own private keys, authenticate devices, or perform end-to-end
 * cryptography. This file therefore treats `encryptedPayload` as an opaque
 * base64 blob — it is decoded to bytes for shape/type checking only, never
 * interpreted or decrypted.
 *
 * Must NOT contain:
 *   - Decryption of any kind        → forbidden for the backend entirely
 *   - Authentication / trust logic  → forbidden for the backend entirely
 *   - Transport / WebSocket wiring  → Phase 7 / later phases
 *   - Business logic of any kind
 */

import type {
  Packet,
  PacketHeader,
  PacketMetadata,
  PacketType,
  PacketPriority,
} from "./packets.js";

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/**
 * Error surfaced by JSON serialization / deserialization. Distinct from
 * `PacketValidationError` (packetValidation.ts): this covers only "is this
 * valid JSON that decodes into a Packet shape," per
 * 07_PROTOCOL_SPECIFICATION.md §Packet Validation Pipeline step 2
 * ("Validate packet structure").
 */
export class PacketSerializationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PacketSerializationError";
  }
}

// ---------------------------------------------------------------------------
// Wire-value allowlists (structural checks only — no semantic meaning
// beyond "is this one of the values §Packet Categories/Priority defines")
// ---------------------------------------------------------------------------

const PACKET_TYPES: ReadonlySet<PacketType> = new Set([
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

const PACKET_PRIORITIES: ReadonlySet<PacketPriority> = new Set(["NORMAL", "HIGH"]);

// ---------------------------------------------------------------------------
// PacketSerializer
// ---------------------------------------------------------------------------

/** Serializes a Packet to a JSON string. `encryptedPayload` is base64-encoded. */
export function serializePacket(packet: Packet): string {
  const wire = {
    header: {
      protocolVersion: packet.header.protocolVersion,
      packetType: packet.header.packetType,
      sessionId: packet.header.sessionId,
      senderId: packet.header.senderId,
      packetId: packet.header.packetId,
      sequenceNumber: packet.header.sequenceNumber,
      timestamp: packet.header.timestamp,
    },
    metadata: {
      retryCount: packet.metadata.retryCount,
      priority: packet.metadata.priority,
      messageCategory: packet.metadata.messageCategory,
    },
    encryptedPayload: Buffer.from(packet.encryptedPayload).toString("base64"),
  };
  try {
    return JSON.stringify(wire);
  } catch (e) {
    throw new PacketSerializationError(
      `Packet JSON encoding failed: ${(e as Error).message}`
    );
  }
}

/**
 * Deserializes a JSON string into a `Packet`.
 *
 * Performs *structural* decoding only: JSON correctness, required fields
 * present, and correct primitive types / allowlisted enum values. Performs
 * NO semantic validation (see `validatePacketStructure` in
 * packetValidation.ts for the full documented pipeline) and NEVER
 * decrypts or inspects `encryptedPayload` contents.
 *
 * @throws PacketSerializationError on malformed JSON or missing/mistyped fields.
 */
export function deserializePacket(json: string): Packet {
  let root: unknown;
  try {
    root = JSON.parse(json);
  } catch (e) {
    throw new PacketSerializationError("Malformed JSON");
  }

  if (typeof root !== "object" || root === null) {
    throw new PacketSerializationError("Root value must be a JSON object");
  }
  const obj = root as Record<string, unknown>;

  const headerRaw = obj.header;
  const metadataRaw = obj.metadata;
  const payloadRaw = obj.encryptedPayload;

  if (typeof headerRaw !== "object" || headerRaw === null) {
    throw new PacketSerializationError("Missing required field 'header'");
  }
  if (typeof metadataRaw !== "object" || metadataRaw === null) {
    throw new PacketSerializationError("Missing required field 'metadata'");
  }
  if (typeof payloadRaw !== "string") {
    throw new PacketSerializationError("Missing required field 'encryptedPayload'");
  }

  const header = parseHeader(headerRaw as Record<string, unknown>);
  const metadata = parseMetadata(metadataRaw as Record<string, unknown>);

  let payloadBytes: Uint8Array;
  try {
    payloadBytes = new Uint8Array(Buffer.from(payloadRaw, "base64"));
  } catch (e) {
    throw new PacketSerializationError("encryptedPayload is not valid base64");
  }

  return { header, metadata, encryptedPayload: payloadBytes };
}

// ---------------------------------------------------------------------------
// Field-level helpers
// ---------------------------------------------------------------------------

function parseHeader(obj: Record<string, unknown>): PacketHeader {
  return {
    protocolVersion: requireNumber(obj, "header.protocolVersion"),
    packetType: requirePacketType(obj, "header.packetType"),
    sessionId: requireString(obj, "header.sessionId"),
    senderId: requireString(obj, "header.senderId"),
    packetId: requireString(obj, "header.packetId"),
    sequenceNumber: requireNumber(obj, "header.sequenceNumber"),
    timestamp: requireNumber(obj, "header.timestamp"),
  };
}

function parseMetadata(obj: Record<string, unknown>): PacketMetadata {
  return {
    retryCount: requireNumber(obj, "metadata.retryCount"),
    priority: requirePriority(obj, "metadata.priority"),
    messageCategory: requirePacketType(obj, "metadata.messageCategory"),
  };
}

function requireString(obj: Record<string, unknown>, path: string): string {
  const key = path.split(".").pop()!;
  const value = obj[key];
  if (typeof value !== "string") {
    throw new PacketSerializationError(`Missing or invalid required field '${path}'`);
  }
  return value;
}

function requireNumber(obj: Record<string, unknown>, path: string): number {
  const key = path.split(".").pop()!;
  const value = obj[key];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new PacketSerializationError(`Missing or invalid required field '${path}'`);
  }
  return value;
}

function requirePacketType(obj: Record<string, unknown>, path: string): PacketType {
  const value = requireString(obj, path);
  if (!PACKET_TYPES.has(value as PacketType)) {
    throw new PacketSerializationError(`Invalid packet type at '${path}': '${value}'`);
  }
  return value as PacketType;
}

function requirePriority(obj: Record<string, unknown>, path: string): PacketPriority {
  const value = requireString(obj, path);
  if (!PACKET_PRIORITIES.has(value as PacketPriority)) {
    throw new PacketSerializationError(`Invalid priority at '${path}': '${value}'`);
  }
  return value as PacketPriority;
}