/**
 * packets.ts — Phase 6
 *
 * Protocol data contracts for the MacEcho communication protocol.
 * Defines the universal packet structure documented in
 * 07_PROTOCOL_SPECIFICATION.md.
 *
 * These are pure data definitions. No methods, no logic, no serialization.
 *
 * Must NOT contain:
 *   - JSON encoding / decoding        → deferred serialization phase
 *   - Packet validation               → Phase 10
 *   - Cryptographic operations        → Phase 8
 *   - WebSocket transport             → Phase 7
 *   - Session management              → Phase 13
 *   - Business logic of any kind
 *
 * Every field included here is explicitly documented in
 * 07_PROTOCOL_SPECIFICATION.md. No fields beyond what the spec defines
 * are introduced in this phase.
 */

// ---------------------------------------------------------------------------
// Platform
// ---------------------------------------------------------------------------

/**
 * Platform identifier for the two participant types in the MacEcho protocol.
 * Referenced during identity exchange per §Identity Exchange.
 */
export type Platform = "ANDROID" | "MACOS";

// ---------------------------------------------------------------------------
// Communication State
// ---------------------------------------------------------------------------

/**
 * Every active session exists in exactly one CommunicationState.
 *
 * Defined in 07_PROTOCOL_SPECIFICATION.md §Communication States.
 * Transitions must follow the valid rules defined in §State Transition Rules.
 * Skipping states is prohibited.
 */
export type CommunicationState =
  | "DISCONNECTED"
  | "CONNECTING"
  | "AUTHENTICATING"
  | "AUTHENTICATED"
  | "SYNCHRONIZING"
  | "IDLE"
  | "RECOVERING"
  | "CLOSING"
  | "CLOSED";

// ---------------------------------------------------------------------------
// Connection Type
// ---------------------------------------------------------------------------

/**
 * Logical connection categories defined in
 * 07_PROTOCOL_SPECIFICATION.md §Connection Types.
 */
export type ConnectionType =
  | "PAIRING_SESSION"
  | "AUTHENTICATION_SESSION"
  | "COMMUNICATION_SESSION"
  | "RECOVERY_SESSION";

// ---------------------------------------------------------------------------
// Packet Type
// ---------------------------------------------------------------------------

/**
 * Packet type identifiers covering all categories and commands defined in
 * 07_PROTOCOL_SPECIFICATION.md §Packet Categories and §Command Categories.
 *
 * Category groupings:
 *   AUTH_*              — Authentication Packets  (§Authentication Commands)
 *   PAIR_*              — Pairing Packets          (§Pairing Commands)
 *   SESSION_*           — Session Packets          (§Session Commands)
 *   NOTIFICATION_*      — Notification Commands    (§Notification Commands)
 *   CALL_*              — Call Commands            (§Call Commands)
 *   RING_PHONE          — Device Commands          (§Device Commands)
 *   SYNC_*              — Synchronization Commands (§Synchronization Commands)
 *   ACK / NACK          — Acknowledgement Packets  (§Positive/Negative Acknowledgement)
 *   HEARTBEAT           — Heartbeat Packets        (§Heartbeat Commands)
 *   ERROR               — Error Packets            (§Error Commands)
 */
export type PacketType =
  // -- Authentication --
  | "AUTH_REQUEST"
  | "AUTH_CHALLENGE"
  | "AUTH_RESPONSE"
  | "AUTH_SUCCESS"
  | "AUTH_FAILURE"
  // -- Pairing --
  | "PAIR_REQUEST"
  | "PAIR_RESPONSE"
  | "PAIR_IDENTITY_EXCHANGE"
  | "PAIR_KEY_EXCHANGE"
  | "PAIR_CONFIRMATION"
  | "PAIR_CANCELLATION"
  // -- Session --
  | "SESSION_START"
  | "SESSION_READY"
  | "SESSION_CLOSING"
  | "SESSION_CLOSED"
  | "SESSION_RECOVERY"
  // -- Notification Commands --
  | "NOTIFICATION_CREATED"
  | "NOTIFICATION_UPDATED"
  | "NOTIFICATION_REMOVED"
  | "NOTIFICATION_REPLY"
  // -- Call Commands --
  | "CALL_INCOMING"
  | "CALL_UPDATED"
  | "CALL_ENDED"
  | "CALL_ACCEPTED"
  | "CALL_DECLINED"
  // -- Device Commands --
  | "RING_PHONE"
  // -- Synchronization Commands --
  | "SYNC_INITIAL"
  | "SYNC_REFRESH"
  // -- Acknowledgement --
  | "ACK"
  | "NACK"
  // -- Heartbeat --
  | "HEARTBEAT"
  // -- Error --
  | "ERROR";

// ---------------------------------------------------------------------------
// Packet Priority
// ---------------------------------------------------------------------------

/**
 * Priority classification for packet metadata.
 * Referenced in §Packet Metadata as "Priority information".
 */
export type PacketPriority = "NORMAL" | "HIGH";

// ---------------------------------------------------------------------------
// Packet Header
// ---------------------------------------------------------------------------

/**
 * Packet header — contains protocol information required before decryption.
 *
 * All seven fields are mandated by 11_IMPLEMENTATION_PLAN.MD Phase 6, Task 3
 * and are documented in 07_PROTOCOL_SPECIFICATION.md §Packet Header.
 *
 * The receiver processes the header first, before the metadata or payload.
 * The header must never contain sensitive application data (§Packet Header).
 *
 * Field semantics:
 *   protocolVersion — Integer version of the MacEcho protocol
 *   packetType      — Category and intent of this packet (§Packet Categories)
 *   sessionId       — UUID identifying the current communication session
 *   senderId        — Stable identifier of the originating device
 *   packetId        — Globally unique UUID for this packet; never reused
 *                     (§Packet Identity — used for duplicate detection)
 *   sequenceNumber  — Session-scoped counter; starts at 1, increments per packet
 *                     (§Sequence Numbers)
 *   timestamp       — Creation time as Unix epoch milliseconds
 *                     (§Packet Timestamp — used for replay protection)
 */
export interface PacketHeader {
  readonly protocolVersion: number;
  readonly packetType: PacketType;
  readonly sessionId: string;
  readonly senderId: string;
  readonly packetId: string;
  readonly sequenceNumber: number;
  readonly timestamp: number;
}

// ---------------------------------------------------------------------------
// Packet Metadata
// ---------------------------------------------------------------------------

/**
 * Packet metadata — communication control information.
 *
 * Documented in 07_PROTOCOL_SPECIFICATION.md §Packet Metadata.
 * Independent of application commands.
 *
 * Field semantics:
 *   retryCount      — Number of retransmission attempts for this packet
 *                     (§Packet Retransmission)
 *   priority        — Delivery priority classification
 *   messageCategory — Logical grouping used for routing and processing
 */
export interface PacketMetadata {
  readonly retryCount: number;
  readonly priority: PacketPriority;
  readonly messageCategory: PacketType;
}

// ---------------------------------------------------------------------------
// Universal Packet
// ---------------------------------------------------------------------------

/**
 * The universal protocol packet — the smallest complete unit of communication.
 *
 * Every piece of information exchanged within MacEcho is transmitted as a
 * protocol packet of this shape, per 07_PROTOCOL_SPECIFICATION.md
 * §Packet Architecture and §Universal Packet Structure.
 *
 * The three sections are processed in strict order:
 *   1. header           — Enables routing and version check before decryption
 *   2. metadata         — Communication control, independent of application data
 *   3. encryptedPayload — Opaque encrypted bytes; must never be processed before
 *                         successful validation of header and metadata
 *
 * The payload is encrypted using the algorithms defined in §Encrypted Payload
 * and Architecture Decision 16. Encryption is implemented in Phase 8.
 * The payload is serialised using JSON per Architecture Decision 17.
 * Serialisation is implemented in the deferred serialisation phase.
 */
export interface Packet {
  readonly header: PacketHeader;
  readonly metadata: PacketMetadata;
  readonly encryptedPayload: Uint8Array;
}
