// PairingMessageSerialization.swift — Phase 12.2
//
// Codable structs for all pairing message types exchanged over WebSocket
// text frames during the temporary pairing handshake.
//
// These are PLAIN JSON messages — NOT the encrypted binary Packet format.
// Pairing is a bootstrap protocol that pre-dates authentication.
//
// Wire format: camelCase JSON keys, matching the TypeScript definitions
// in backend/src/protocol/pairingPackets.ts exactly.
//
// Must NOT contain:
//   - Cryptographic operations   → CryptoManager.swift / PairingHandshakeController
//   - Transport logic            → WebSocketClient.swift
//   - Business logic of any kind

import Foundation

// ---------------------------------------------------------------------------
// Message type enum
// ---------------------------------------------------------------------------

enum PairingMessageType: String, Codable, Sendable {
    case pairingJoin            = "PAIRING_JOIN"
    case pairingMacJoin         = "PAIRING_MAC_JOIN"
    case pairingJoinAck         = "PAIRING_JOIN_ACK"
    case pairingReady           = "PAIRING_READY"
    case pairingPublicKey       = "PAIRING_PUBLIC_KEY"
    case pairingFingerprint     = "PAIRING_FINGERPRINT"
    case pairingCancelled       = "PAIRING_CANCELLED"
    case pairingTimeout         = "PAIRING_TIMEOUT"
}

// ---------------------------------------------------------------------------
// Base fields (present on every message)
// ---------------------------------------------------------------------------

struct PairingMessageBase: Codable, Sendable {
    let type: PairingMessageType
    let sessionId: String
    let timestamp: Int64
}

// ---------------------------------------------------------------------------
// Concrete message structs
// ---------------------------------------------------------------------------

/// Mac → Backend: register as the Mac side of a pairing session.
struct PairingMacJoin: Codable, Sendable {
    let type: PairingMessageType
    let sessionId: String
    let timestamp: Int64
    let senderId: String
}

/// Backend → Mac: Android has joined the session.
struct PairingReady: Codable, Sendable {
    let type: PairingMessageType
    let sessionId: String
    let timestamp: Int64
}

/// Mac → Backend (relay to Android): ephemeral X25519 public key.
struct PairingPublicKey: Codable, Sendable {
    let type: PairingMessageType
    let sessionId: String
    let timestamp: Int64
    let senderId: String
    /// Base64-encoded X.509 SubjectPublicKeyInfo bytes of the ephemeral key.
    let publicKey: String
}

/// Mac → Backend (relay to Android): SHA-256 verification fingerprint.
/// Contains the first 8 bytes of SHA-256(derivedKey) as a lowercase hex string.
/// The derived key itself is NEVER sent.
struct PairingFingerprint: Codable, Sendable {
    let type: PairingMessageType
    let sessionId: String
    let timestamp: Int64
    let senderId: String
    /// Hex-encoded first 8 bytes of SHA-256(derivedSharedSecret).
    let fingerprint: String
}

/// Either side → Backend: cancel the pairing session.
struct PairingCancelled: Codable, Sendable {
    let type: PairingMessageType
    let sessionId: String
    let timestamp: Int64
    let reason: String
}

/// Backend → Mac: session has timed out.
struct PairingTimeout: Codable, Sendable {
    let type: PairingMessageType
    let sessionId: String
    let timestamp: Int64
}

// ---------------------------------------------------------------------------
// Inbound message union — decoded from raw text frames
// ---------------------------------------------------------------------------

/// All message shapes the Mac side may receive from the backend.
enum InboundPairingMessage: Sendable {
    case ready(PairingReady)
    case publicKey(PairingPublicKey)
    case fingerprint(PairingFingerprint)
    case cancelled(PairingCancelled)
    case timeout(PairingTimeout)
}

// ---------------------------------------------------------------------------
// PairingMessageSerializer
// ---------------------------------------------------------------------------

enum PairingMessageSerializer {

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    private static let decoder = JSONDecoder()

    // MARK: Encode outbound messages

    static func encodeMacJoin(sessionId: String, senderId: String) -> Data? {
        let msg = PairingMacJoin(
            type: .pairingMacJoin,
            sessionId: sessionId,
            timestamp: Int64(Date().timeIntervalSince1970 * 1_000),
            senderId: senderId
        )
        return try? encoder.encode(msg)
    }

    static func encodePublicKey(sessionId: String, senderId: String, publicKeyB64: String) -> Data? {
        let msg = PairingPublicKey(
            type: .pairingPublicKey,
            sessionId: sessionId,
            timestamp: Int64(Date().timeIntervalSince1970 * 1_000),
            senderId: senderId,
            publicKey: publicKeyB64
        )
        return try? encoder.encode(msg)
    }

    static func encodeFingerprint(sessionId: String, senderId: String, fingerprint: String) -> Data? {
        let msg = PairingFingerprint(
            type: .pairingFingerprint,
            sessionId: sessionId,
            timestamp: Int64(Date().timeIntervalSince1970 * 1_000),
            senderId: senderId,
            fingerprint: fingerprint
        )
        return try? encoder.encode(msg)
    }

    static func encodeCancelled(sessionId: String, reason: String) -> Data? {
        let msg = PairingCancelled(
            type: .pairingCancelled,
            sessionId: sessionId,
            timestamp: Int64(Date().timeIntervalSince1970 * 1_000),
            reason: reason
        )
        return try? encoder.encode(msg)
    }

    // MARK: Decode inbound messages

    /// Attempts to decode a raw text frame into an InboundPairingMessage.
    /// Returns nil for any unrecognised or malformed message.
    static func decode(_ text: String) -> InboundPairingMessage? {
        guard let data = text.data(using: .utf8) else { return nil }

        // Peek at the type field first
        guard let base = try? decoder.decode(PairingMessageBase.self, from: data) else { return nil }

        switch base.type {
        case .pairingReady:
            guard let m = try? decoder.decode(PairingReady.self, from: data) else { return nil }
            return .ready(m)
        case .pairingPublicKey:
            guard let m = try? decoder.decode(PairingPublicKey.self, from: data) else { return nil }
            return .publicKey(m)
        case .pairingFingerprint:
            guard let m = try? decoder.decode(PairingFingerprint.self, from: data) else { return nil }
            return .fingerprint(m)
        case .pairingCancelled:
            guard let m = try? decoder.decode(PairingCancelled.self, from: data) else { return nil }
            return .cancelled(m)
        case .pairingTimeout:
            guard let m = try? decoder.decode(PairingTimeout.self, from: data) else { return nil }
            return .timeout(m)
        default:
            return nil
        }
    }
}
