// MacPairingState.swift — Phase 12.2
//
// macOS-side pairing state machine states.
//
// Transitions (in order):
//   unpaired → waitingForAndroid → androidConnected →
//   exchangingKeys → verifying → secureChannelReady
//
// Any state can transition to failed(Error).
// failed always transitions back to unpaired on retry.
//
// Must NOT contain business logic — pure state definition.

import Foundation

/// The macOS side of the pairing handshake state machine.
enum MacPairingState: Sendable, Equatable {
    /// Initial state. No pairing attempt in progress.
    case unpaired

    /// WebSocket connected to backend. QR displayed. Waiting for Android to scan.
    case waitingForAndroid

    /// Android has joined the backend session. Both sockets present.
    case androidConnected

    /// Both devices connected. Ephemeral public keys being exchanged.
    case exchangingKeys

    /// Keys exchanged. Verifying fingerprints to confirm matching shared secret.
    case verifying

    /// Fingerprints matched. Temporary encrypted channel established.
    /// Phase 12.3 will use this state to begin trust establishment.
    /// No permanent pairing has occurred yet.
    case secureChannelReady

    /// A recoverable error occurred. User can tap to retry.
    case failed(MacPairingError)

    // Convenience for display
    var displayText: String {
        switch self {
        case .unpaired:             return "Waiting for Android device…"
        case .waitingForAndroid:    return "Waiting for Android device…"
        case .androidConnected:     return "Android Connected ✓"
        case .exchangingKeys:       return "Exchanging Keys…"
        case .verifying:            return "Verifying…"
        case .secureChannelReady:   return "✅ Secure Channel Established"
        case .failed(let e):        return "Pairing failed — \(e.localizedDescription)"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .secureChannelReady, .failed: return true
        default: return false
        }
    }
}

/// Pairing-specific error types for the macOS handshake.
enum MacPairingError: LocalizedError, Equatable {
    case connectionFailed(String)
    case sessionExpired
    case sessionCancelled(String)
    case keyExchangeFailed
    case fingerprintMismatch
    case unexpectedDisconnect

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .sessionExpired:            return "The pairing session expired. Please generate a new QR code."
        case .sessionCancelled(let r):   return humanReadableReason(r)
        case .keyExchangeFailed:         return "Key exchange failed. Please try again."
        case .fingerprintMismatch:       return "Fingerprint mismatch — possible interference. Please try again."
        case .unexpectedDisconnect:      return "Connection lost unexpectedly."
        }
    }

    private func humanReadableReason(_ reason: String) -> String {
        switch reason {
        case "android_disconnected": return "Android disconnected. Please try again."
        case "expired":              return "Session expired. Please generate a new QR code."
        default:                     return "Pairing was cancelled."
        }
    }
}
