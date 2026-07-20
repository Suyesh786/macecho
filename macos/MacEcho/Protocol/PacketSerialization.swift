
// PacketSerialization.swift — Phase 10
//
// JSON serialization / deserialization for the protocol packet types defined
// in Packets.swift (Phase 6), per Architecture Decision 17 ("All protocol
// packets are serialized using JSON") and 07_PROTOCOL_SPECIFICATION.md
// §Serialization Philosophy / §Universal Packet Structure.
//
// This file ONLY adds Codable conformance and JSON encode/decode helpers.
// It contains NO validation logic (see PacketValidator.swift) and NO
// cryptographic operations (Phase 8, unchanged).
//
// Wire format: camelCase JSON keys matching the Swift property names in
// Packets.swift. No field-name casing convention is mandated by the
// documentation, so the existing Swift property names are used directly
// to avoid introducing an undocumented convention.
//
// Must NOT contain:
//   - Packet validation             → PacketValidator.swift (this phase)
//   - Cryptographic operations      → Phase 8 (CryptoManager.swift)
//   - Transport / WebSocket wiring  → Phase 7 / later phases
//   - Business logic of any kind

import Foundation

// ---------------------------------------------------------------------------
// Platform
// ---------------------------------------------------------------------------

extension Platform: Codable {
    private enum Wire: String, Codable { case android = "ANDROID", macos = "MACOS" }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Wire.self)
        switch raw {
        case .android: self = .android
        case .macos: self = .macos
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .android: try container.encode(Wire.android)
        case .macos: try container.encode(Wire.macos)
        }
    }
}

// ---------------------------------------------------------------------------
// CommunicationState
// ---------------------------------------------------------------------------

extension CommunicationState: Codable {
    private enum Wire: String, Codable {
        case disconnected = "DISCONNECTED"
        case connecting = "CONNECTING"
        case authenticating = "AUTHENTICATING"
        case authenticated = "AUTHENTICATED"
        case synchronizing = "SYNCHRONIZING"
        case idle = "IDLE"
        case recovering = "RECOVERING"
        case closing = "CLOSING"
        case closed = "CLOSED"
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Wire.self)
        let map: [Wire: CommunicationState] = [
            .disconnected: .disconnected, .connecting: .connecting,
            .authenticating: .authenticating, .authenticated: .authenticated,
            .synchronizing: .synchronizing, .idle: .idle,
            .recovering: .recovering, .closing: .closing, .closed: .closed,
        ]
        self = map[raw]!
    }

    public func encode(to encoder: Encoder) throws {
        let map: [CommunicationState: Wire] = [
            .disconnected: .disconnected, .connecting: .connecting,
            .authenticating: .authenticating, .authenticated: .authenticated,
            .synchronizing: .synchronizing, .idle: .idle,
            .recovering: .recovering, .closing: .closing, .closed: .closed,
        ]
        var container = encoder.singleValueContainer()
        try container.encode(map[self]!)
    }
}

// ---------------------------------------------------------------------------
// ConnectionType
// ---------------------------------------------------------------------------

extension ConnectionType: Codable {
    private enum Wire: String, Codable {
        case pairingSession = "PAIRING_SESSION"
        case authenticationSession = "AUTHENTICATION_SESSION"
        case communicationSession = "COMMUNICATION_SESSION"
        case recoverySession = "RECOVERY_SESSION"
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Wire.self)
        switch raw {
        case .pairingSession: self = .pairingSession
        case .authenticationSession: self = .authenticationSession
        case .communicationSession: self = .communicationSession
        case .recoverySession: self = .recoverySession
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .pairingSession: try container.encode(Wire.pairingSession)
        case .authenticationSession: try container.encode(Wire.authenticationSession)
        case .communicationSession: try container.encode(Wire.communicationSession)
        case .recoverySession: try container.encode(Wire.recoverySession)
        }
    }
}

// ---------------------------------------------------------------------------
// PacketType
// ---------------------------------------------------------------------------

extension PacketType: Codable, CaseIterable {
    // CaseIterable + rawValue map lets PacketValidator recognize "known type"
    // (§Packet Categories) without hand-writing a duplicate list.
    private enum Wire: String, Codable, CaseIterable {
        case authRequest = "AUTH_REQUEST"
        case authChallenge = "AUTH_CHALLENGE"
        case authResponse = "AUTH_RESPONSE"
        case authSuccess = "AUTH_SUCCESS"
        case authFailure = "AUTH_FAILURE"
        case pairRequest = "PAIR_REQUEST"
        case pairResponse = "PAIR_RESPONSE"
        case pairIdentityExchange = "PAIR_IDENTITY_EXCHANGE"
        case pairKeyExchange = "PAIR_KEY_EXCHANGE"
        case pairConfirmation = "PAIR_CONFIRMATION"
        case pairCancellation = "PAIR_CANCELLATION"
        case sessionStart = "SESSION_START"
        case sessionReady = "SESSION_READY"
        case sessionClosing = "SESSION_CLOSING"
        case sessionClosed = "SESSION_CLOSED"
        case sessionRecovery = "SESSION_RECOVERY"
        case notificationCreated = "NOTIFICATION_CREATED"
        case notificationUpdated = "NOTIFICATION_UPDATED"
        case notificationRemoved = "NOTIFICATION_REMOVED"
        case notificationReply = "NOTIFICATION_REPLY"
        case callIncoming = "CALL_INCOMING"
        case callUpdated = "CALL_UPDATED"
        case callEnded = "CALL_ENDED"
        case callAccepted = "CALL_ACCEPTED"
        case callDeclined = "CALL_DECLINED"
        case ringPhone = "RING_PHONE"
        case syncInitial = "SYNC_INITIAL"
        case syncRefresh = "SYNC_REFRESH"
        case ack = "ACK"
        case nack = "NACK"
        case heartbeat = "HEARTBEAT"
        case error = "ERROR"
    }

    private static let toWire: [PacketType: Wire] = [
        .authRequest: .authRequest, .authChallenge: .authChallenge,
        .authResponse: .authResponse, .authSuccess: .authSuccess,
        .authFailure: .authFailure, .pairRequest: .pairRequest,
        .pairResponse: .pairResponse, .pairIdentityExchange: .pairIdentityExchange,
        .pairKeyExchange: .pairKeyExchange, .pairConfirmation: .pairConfirmation,
        .pairCancellation: .pairCancellation, .sessionStart: .sessionStart,
        .sessionReady: .sessionReady, .sessionClosing: .sessionClosing,
        .sessionClosed: .sessionClosed, .sessionRecovery: .sessionRecovery,
        .notificationCreated: .notificationCreated, .notificationUpdated: .notificationUpdated,
        .notificationRemoved: .notificationRemoved, .notificationReply: .notificationReply,
        .callIncoming: .callIncoming, .callUpdated: .callUpdated,
        .callEnded: .callEnded, .callAccepted: .callAccepted,
        .callDeclined: .callDeclined, .ringPhone: .ringPhone,
        .syncInitial: .syncInitial, .syncRefresh: .syncRefresh,
        .ack: .ack, .nack: .nack, .heartbeat: .heartbeat, .error: .error,
    ]
    private static let fromWire: [Wire: PacketType] = Dictionary(
        uniqueKeysWithValues: toWire.map { ($1, $0) }
    )

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Wire.self)
        self = PacketType.fromWire[raw]!
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(PacketType.toWire[self]!)
    }
}

// ---------------------------------------------------------------------------
// PacketPriority
// ---------------------------------------------------------------------------

extension PacketPriority: Codable {
    private enum Wire: String, Codable { case normal = "NORMAL", high = "HIGH" }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Wire.self)
        self = raw == .normal ? .normal : .high
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self == .normal ? Wire.normal : Wire.high)
    }
}

// ---------------------------------------------------------------------------
// PacketHeader / PacketMetadata / Packet
// ---------------------------------------------------------------------------

extension PacketHeader: Codable {}
extension PacketMetadata: Codable {}

extension Packet: Codable {
    private enum CodingKeys: String, CodingKey {
        case header, metadata, encryptedPayload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        header = try container.decode(PacketHeader.self, forKey: .header)
        metadata = try container.decode(PacketMetadata.self, forKey: .metadata)
        // Encrypted payload travels as base64 text in JSON (Data's default
        // Codable behavior); decoded back into [UInt8] here since Packets.swift
        // (Phase 6) deliberately keeps the payload as [UInt8], not Data.
        let payloadData = try container.decode(Data.self, forKey: .encryptedPayload)
        encryptedPayload = [UInt8](payloadData)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(header, forKey: .header)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(Data(encryptedPayload), forKey: .encryptedPayload)
    }
}

// ---------------------------------------------------------------------------
// PacketSerializer — JSON encode / decode entry points
// ---------------------------------------------------------------------------

/// Errors surfaced by JSON serialization / deserialization.
/// Distinct from `PacketValidationError` (PacketValidator.swift): this type
/// covers only "is this valid JSON that decodes into a Packet shape",
/// per 07_PROTOCOL_SPECIFICATION.md §Packet Validation Pipeline step 2
/// ("Validate packet structure").
enum PacketSerializationError: Error, LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let e): return "Packet JSON encoding failed: \(e.localizedDescription)"
        case .decodingFailed(let e): return "Packet JSON decoding failed: \(e.localizedDescription)"
        }
    }
}

/// Stateless JSON serialization helpers for `Packet`.
///
/// Uses Foundation's `JSONEncoder` / `JSONDecoder` per the task instructions
/// ("unless documentation specifies otherwise" — the documentation does not).
enum PacketSerializer {

    /// Serializes a `Packet` to JSON `Data`.
    static func serialize(_ packet: Packet) throws -> Data {
        do {
            return try JSONEncoder().encode(packet)
        } catch {
            throw PacketSerializationError.encodingFailed(error)
        }
    }

    /// Deserializes JSON `Data` into a `Packet`.
    ///
    /// This performs *structural* decoding only (JSON correctness + required
    /// fields, via Codable's normal missing-key behavior). It performs no
    /// semantic validation — see `PacketValidator.validate(_:)` for the full
    /// documented pipeline.
    static func deserialize(_ data: Data) throws -> Packet {
        do {
            return try JSONDecoder().decode(Packet.self, from: data)
        } catch {
            throw PacketSerializationError.decodingFailed(error)
        }
    }
}