/**
 * pairingPackets.ts — Phase 12.2
 *
 * Pairing-only message type definitions and JSON serialization.
 *
 * These are PLAIN JSON text-frame messages, NOT the encrypted binary Packet
 * format defined in packets.ts. The pairing protocol is a bootstrap mechanism
 * that pre-dates authentication and therefore cannot use the encrypted packet
 * format — there is no shared secret yet.
 *
 * Message flow (Backend is relay only — never reads keys or secrets):
 *
 *   Mac                Backend               Android
 *   ──────────────────────────────────────────────────
 *   connect()    →   (registered as Mac for session)
 *                        ←  PAIRING_JOIN       ←   scan QR, connect()
 *                    PAIRING_JOIN_ACK  →
 *   PAIRING_READY ←
 *   PAIRING_PUBLIC_KEY → (relay)       →   (Android receives Mac key)
 *                        ←  PAIRING_PUBLIC_KEY ←   (Mac receives Android key)
 *   [derive secret, compute fingerprint]
 *   PAIRING_FINGERPRINT → (relay)      →
 *                        ←  PAIRING_FINGERPRINT ←
 *   [fingerprints match → SECURE_CHANNEL_READY]
 *
 * Must NOT contain:
 *   - Decryption or key inspection  → forbidden for backend
 *   - Session persistence           → PairingSessionManager
 *   - Transport wiring              → websocket.ts
 *   - Business logic of any kind
 */

// ---------------------------------------------------------------------------
// Message Types
// ---------------------------------------------------------------------------

export type PairingMessageType =
  | "PAIRING_JOIN"          // Android → Backend: join an existing Mac session
  | "PAIRING_JOIN_ACK"      // Backend → Android: join acknowledged
  | "PAIRING_READY"         // Backend → Mac: Android has joined
  | "PAIRING_PUBLIC_KEY"    // Mac ↔ Android (relay): ephemeral X25519 public key
  | "PAIRING_FINGERPRINT"   // Mac ↔ Android (relay): SHA-256 verification fingerprint
  | "PAIRING_CANCELLED"     // Either → Backend: cancel session
  | "PAIRING_TIMEOUT"       // Backend → Both: session expired
  | "PAIRING_MAC_JOIN";     // Mac → Backend: register as the Mac side of a session

const PAIRING_TYPES = new Set<string>([
  "PAIRING_JOIN",
  "PAIRING_JOIN_ACK",
  "PAIRING_READY",
  "PAIRING_PUBLIC_KEY",
  "PAIRING_FINGERPRINT",
  "PAIRING_CANCELLED",
  "PAIRING_TIMEOUT",
  "PAIRING_MAC_JOIN",
]);

// ---------------------------------------------------------------------------
// Base message
// ---------------------------------------------------------------------------

export interface PairingMessageBase {
  readonly type: PairingMessageType;
  readonly sessionId: string;
  readonly timestamp: number; // Unix epoch ms
}

// ---------------------------------------------------------------------------
// Concrete message shapes
// ---------------------------------------------------------------------------

/** Android → Backend: register as Android side of a pairing session. */
export interface PairingJoin extends PairingMessageBase {
  readonly type: "PAIRING_JOIN";
  readonly senderId: string; // Android device UUID
}

/** Mac → Backend: register as Mac side of a pairing session. */
export interface PairingMacJoin extends PairingMessageBase {
  readonly type: "PAIRING_MAC_JOIN";
  readonly senderId: string; // Mac device UUID
}

/** Backend → Android: join acknowledged. Indicates whether Mac is already present. */
export interface PairingJoinAck extends PairingMessageBase {
  readonly type: "PAIRING_JOIN_ACK";
  readonly macConnected: boolean;
}

/** Backend → Mac: Android has joined the session. */
export interface PairingReady extends PairingMessageBase {
  readonly type: "PAIRING_READY";
}

/** Mac ↔ Android (relayed through backend): ephemeral X25519 public key, base64-encoded. */
export interface PairingPublicKey extends PairingMessageBase {
  readonly type: "PAIRING_PUBLIC_KEY";
  readonly senderId: string;
  /** Base64-encoded X.509 SubjectPublicKeyInfo bytes of the ephemeral X25519 public key. */
  readonly publicKey: string;
}

/**
 * Mac ↔ Android (relayed through backend): verification fingerprint.
 * Contains the first 8 bytes of SHA-256(sharedSecret) encoded as hex.
 * The shared secret itself is NEVER sent — only this short fingerprint.
 */
export interface PairingFingerprint extends PairingMessageBase {
  readonly type: "PAIRING_FINGERPRINT";
  readonly senderId: string;
  /** Hex-encoded first 8 bytes of SHA-256(derivedSharedSecret). */
  readonly fingerprint: string;
}

/** Either side → Backend: cancel this pairing session. */
export interface PairingCancelled extends PairingMessageBase {
  readonly type: "PAIRING_CANCELLED";
  readonly reason: string;
}

/** Backend → Both: session has expired (TTL exceeded). */
export interface PairingTimeout extends PairingMessageBase {
  readonly type: "PAIRING_TIMEOUT";
}

export type PairingMessage =
  | PairingJoin
  | PairingMacJoin
  | PairingJoinAck
  | PairingReady
  | PairingPublicKey
  | PairingFingerprint
  | PairingCancelled
  | PairingTimeout;

// ---------------------------------------------------------------------------
// Serialization
// ---------------------------------------------------------------------------

/**
 * Serializes a PairingMessage to a JSON string for transmission as a
 * WebSocket text frame.
 */
export function serializePairingMessage(msg: PairingMessage): string {
  return JSON.stringify(msg);
}

/**
 * Attempts to deserialize a WebSocket text frame into a PairingMessage.
 * Returns null for any malformed, unknown-type, or structurally invalid input.
 * Never throws.
 */
export function deserializePairingMessage(
  raw: string,
): PairingMessage | null {
  try {
    const obj = JSON.parse(raw) as Record<string, unknown>;
    if (typeof obj !== "object" || obj === null) return null;
    if (typeof obj["type"] !== "string") return null;
    if (!PAIRING_TYPES.has(obj["type"] as string)) return null;
    if (typeof obj["sessionId"] !== "string") return null;
    if (typeof obj["timestamp"] !== "number") return null;
    return obj as unknown as PairingMessage;
  } catch {
    return null;
  }
}

/**
 * Returns true if the given raw string begins with a PAIRING_ message type.
 * Used as a fast pre-check before full deserialization.
 */
export function looksLikePairingMessage(raw: string): boolean {
  return raw.includes('"PAIRING_');
}
