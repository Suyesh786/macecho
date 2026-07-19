// Packets.swift — Phase 6
//
// Protocol data contracts for the MacEcho communication protocol.
// Defines the universal packet structure documented in
// 07_PROTOCOL_SPECIFICATION.md.
//
// These are pure data definitions. No methods, no logic, no serialization.
//
// Must NOT contain:
//   - JSON encoding / decoding (Codable)      → deferred serialization phase
//   - Packet validation                        → Phase 10
//   - Cryptographic operations                 → Phase 8
//   - WebSocket transport                      → Phase 7
//   - Session management                       → Phase 13
//   - Foundation / AppKit / macOS OS imports
//   - Business logic of any kind
//
// Every field included here is explicitly documented in
// 07_PROTOCOL_SPECIFICATION.md. No fields beyond what the spec defines
// are introduced in this phase.
//
// All types are Swift value types (struct / enum) — immutable by default
// when stored with let. No reference types are used.

// ---------------------------------------------------------------------------
// Platform
// ---------------------------------------------------------------------------

/// Platform identifier for the two participant types in the MacEcho protocol.
/// Referenced during identity exchange per §Identity Exchange.
enum Platform {
    case android
    case macos
}

// ---------------------------------------------------------------------------
// Communication State
// ---------------------------------------------------------------------------

/// Every active session exists in exactly one CommunicationState.
///
/// Defined in 07_PROTOCOL_SPECIFICATION.md §Communication States.
/// Transitions must follow the valid rules defined in §State Transition Rules.
/// Skipping states is prohibited.
enum CommunicationState {
    case disconnected
    case connecting
    case authenticating
    case authenticated
    case synchronizing
    case idle
    case recovering
    case closing
    case closed
}

// ---------------------------------------------------------------------------
// Connection Type
// ---------------------------------------------------------------------------

/// Logical connection categories defined in
/// 07_PROTOCOL_SPECIFICATION.md §Connection Types.
enum ConnectionType {
    case pairingSession
    case authenticationSession
    case communicationSession
    case recoverySession
}

// ---------------------------------------------------------------------------
// Packet Type
// ---------------------------------------------------------------------------

/// Packet type identifiers covering all categories and commands defined in
/// 07_PROTOCOL_SPECIFICATION.md §Packet Categories and §Command Categories.
///
/// Category groupings:
///   auth*              — Authentication Packets  (§Authentication Commands)
///   pair*              — Pairing Packets          (§Pairing Commands)
///   session*           — Session Packets          (§Session Commands)
///   notification*      — Notification Commands    (§Notification Commands)
///   call*              — Call Commands            (§Call Commands)
///   ringPhone          — Device Commands          (§Device Commands)
///   sync*              — Synchronization Commands (§Synchronization Commands)
///   ack / nack         — Acknowledgement Packets  (§Positive/Negative Acknowledgement)
///   heartbeat          — Heartbeat Packets        (§Heartbeat Commands)
///   error              — Error Packets            (§Error Commands)
enum PacketType {
    // -- Authentication --
    case authRequest
    case authChallenge
    case authResponse
    case authSuccess
    case authFailure
    // -- Pairing --
    case pairRequest
    case pairResponse
    case pairIdentityExchange
    case pairKeyExchange
    case pairConfirmation
    case pairCancellation
    // -- Session --
    case sessionStart
    case sessionReady
    case sessionClosing
    case sessionClosed
    case sessionRecovery
    // -- Notification Commands --
    case notificationCreated
    case notificationUpdated
    case notificationRemoved
    case notificationReply
    // -- Call Commands --
    case callIncoming
    case callUpdated
    case callEnded
    case callAccepted
    case callDeclined
    // -- Device Commands --
    case ringPhone
    // -- Synchronization Commands --
    case syncInitial
    case syncRefresh
    // -- Acknowledgement --
    case ack
    case nack
    // -- Heartbeat --
    case heartbeat
    // -- Error --
    case error
}

// ---------------------------------------------------------------------------
// Packet Priority
// ---------------------------------------------------------------------------

/// Priority classification for packet metadata.
/// Referenced in §Packet Metadata as "Priority information".
enum PacketPriority {
    case normal
    case high
}

// ---------------------------------------------------------------------------
// Packet Header
// ---------------------------------------------------------------------------

/// Packet header — contains protocol information required before decryption.
///
/// All seven fields are mandated by 11_IMPLEMENTATION_PLAN.MD Phase 6, Task 3
/// and are documented in 07_PROTOCOL_SPECIFICATION.md §Packet Header.
///
/// The receiver processes the header first, before the metadata or payload.
/// The header must never contain sensitive application data (§Packet Header).
///
/// - protocolVersion: Integer version of the MacEcho protocol
/// - packetType:      Category and intent of this packet (§Packet Categories)
/// - sessionId:       UUID string identifying the current communication session
/// - senderId:        Stable identifier string of the originating device
/// - packetId:        Globally unique UUID string for this packet; never reused
///                    (§Packet Identity — used for duplicate detection)
/// - sequenceNumber:  Session-scoped counter; starts at 1, increments per packet
///                    (§Sequence Numbers)
/// - timestamp:       Creation time as Unix epoch milliseconds
///                    (§Packet Timestamp — used for replay protection)
struct PacketHeader {
    let protocolVersion: Int
    let packetType: PacketType
    let sessionId: String
    let senderId: String
    let packetId: String
    let sequenceNumber: UInt64
    let timestamp: UInt64
}

// ---------------------------------------------------------------------------
// Packet Metadata
// ---------------------------------------------------------------------------

/// Packet metadata — communication control information.
///
/// Documented in 07_PROTOCOL_SPECIFICATION.md §Packet Metadata.
/// Independent of application commands.
///
/// - retryCount:      Number of retransmission attempts for this packet
///                    (§Packet Retransmission)
/// - priority:        Delivery priority classification
/// - messageCategory: Logical grouping used for routing and processing
struct PacketMetadata {
    let retryCount: Int
    let priority: PacketPriority
    let messageCategory: PacketType
}

// ---------------------------------------------------------------------------
// Universal Packet
// ---------------------------------------------------------------------------

/// The universal protocol packet — the smallest complete unit of communication.
///
/// Every piece of information exchanged within MacEcho is transmitted as a
/// protocol packet of this shape, per 07_PROTOCOL_SPECIFICATION.md
/// §Packet Architecture and §Universal Packet Structure.
///
/// The three sections are processed in strict order:
///   1. header           — Enables routing and version check before decryption
///   2. metadata         — Communication control, independent of application data
///   3. encryptedPayload — Opaque encrypted bytes; must never be processed before
///                         successful validation of header and metadata
///
/// The payload is encrypted using the algorithms defined in §Encrypted Payload
/// and Architecture Decision 16. Encryption is implemented in Phase 8.
/// The payload is serialised using JSON per Architecture Decision 17.
/// Serialisation is implemented in the deferred serialisation phase.
///
/// `[UInt8]` is used for the encrypted payload to remain Foundation-free
/// in Phase 6. A later phase may migrate to `Data` when Foundation is
/// already imported for other reasons.
struct Packet {
    let header: PacketHeader
    let metadata: PacketMetadata
    let encryptedPayload: [UInt8]
}
