// AppSessionManager.swift — Connection Lifecycle Fix
//
// Long-lived owner of the ONE active MacEcho session after pairing succeeds.
//
// Problem this file solves:
//   Previously, PairDeviceViewController's viewWillDisappear() unconditionally
//   called `pairingController?.cancel(...)`, which disconnected the WebSocket
//   whenever the pairing screen closed — including on the success path. The
//   pairing UI was, in effect, the owner of the connection.
//
// Fix:
//   AppSessionManager becomes the single long-lived owner of the paired
//   connection. PairingHandshakeController still performs the entire pairing
//   handshake exactly as before (no duplicated logic); the only change is
//   that on success it hands its already-open WebSocketClient to
//   AppSessionManager instead of that connection being tied to the screen's
//   lifecycle. PairDeviceViewController no longer cancels on disappearance
//   once a session has been adopted.
//
// This file does NOT:
//   - Implement authentication (already complete, per project context).
//   - Implement reconnection.
//   - Implement Unpair.
//   - Modify protocol packets, cryptography, or the pairing handshake itself.
//
// There is always at most one active session. Calling `adopt` again replaces
// the previous session (matching the existing "only one paired device"
// design of MacEcho Version 1).

import Foundation

/// Everything the rest of the app needs to know about the current session,
/// independent of any particular screen's lifecycle.
struct ActiveSession {
    /// The already-connected transport handed over by PairingHandshakeController
    /// after a successful handshake. AppSessionManager becomes its owner —
    /// it will not be closed just because the pairing screen was dismissed.
    let client: WebSocketClient
    let pairedDeviceId: String
    let pairedDeviceName: String
    let pairedDeviceType: String
    let establishedAt: Date
}

/// Reasons the application-level session may end. Only fatal / explicit
/// reasons are represented — a UI screen disappearing is never one of them.
enum SessionTerminationReason {
    case applicationQuit
    case unpaired
    case fatalProtocolFailure
    case fatalNetworkFailure
}

/// Singleton, long-lived owner of the application's one active session.
///
/// Pairing classes (`PairingHandshakeController`) still perform pairing.
/// This class only owns what happens to the connection *after* pairing
/// succeeds, and reports paired-device status for the Home screen.
@MainActor
final class AppSessionManager {

    static let shared = AppSessionManager()
    static let trustRevokedNotification = Notification.Name("AppSessionManager.TrustRevokedNotification")
    static let sessionAdoptedNotification = Notification.Name("AppSessionManager.SessionAdoptedNotification")

    private var listenerTask: Task<Void, Never>?

    private init() {}

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    private(set) var activeSession: ActiveSession?

    /// `true` once a session has been adopted. Home screens and the
    /// "Generate QR" action consult this instead of re-deriving pairing
    /// state from a UI screen.
    var isPaired: Bool { activeSession != nil }

    /// Display name of the currently paired device, or `nil` if unpaired.
    /// Reads from TrustStore as the authoritative source so it is always
    /// consistent with what TrustedDevicesViewController shows.
    var pairedDeviceName: String? {
        guard activeSession != nil else { return nil }
        return TrustStore().getAll().first?.deviceName ?? activeSession?.pairedDeviceName
    }

    // -------------------------------------------------------------------------
    // Adoption (called once, by the pairing screen, on success)
    // -------------------------------------------------------------------------

    /// Adopts an already-established connection as the application's one
    /// long-lived session. Call this exactly once, at the moment
    /// `PairingHandshakeController` reports `.secureChannelReady`.
    ///
    /// This does NOT open a new connection and does NOT repeat any part of
    /// the handshake — `client` is the same `WebSocketClient` instance the
    /// handshake controller already connected and used.
    ///
    /// If a previous session exists, it is replaced (there is always exactly
    /// one active session per the Version 1 one-Android/one-Mac design).
    func adopt(
        client: WebSocketClient,
        pairedDeviceId: String,
        pairedDeviceName: String,
        pairedDeviceType: String
    ) {
        activeSession = ActiveSession(
            client: client,
            pairedDeviceId: pairedDeviceId,
            pairedDeviceName: pairedDeviceName,
            pairedDeviceType: pairedDeviceType,
            establishedAt: Date()
        )
        
        // Install the event handler synchronously inside a detached Task on the
        // WebSocketClient actor. We use Task.detached to avoid the @MainActor
        // scheduling delay — the handler must be registered before any message
        // can arrive, not after the main actor loop processes the next task.
        let weakSelf = self
        Task.detached {
            await client.setEventHandler { @Sendable event in
                if case .textReceived(let text) = event,
                   let data = text.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = obj["type"] as? String,
                   type == "TRUST_REVOKED" {
                    Task { @MainActor in weakSelf.handleTrustRevokedRemotely() }
                }
            }
        }
        
        // Notify UI that a session was adopted so screens can refresh.
        NotificationCenter.default.post(name: Self.sessionAdoptedNotification, object: nil)
    }

    private func handleTrustRevokedRemotely() {
        guard let session = activeSession else { return }
        // Remove TrustStore entry and clear the in-memory key cache so that
        // a fresh pairing will use a clean encryption key.
        try? TrustStore().remove(deviceId: session.pairedDeviceId)
        TrustStore.invalidateKeyCache()
        terminate(reason: .unpaired)
        NotificationCenter.default.post(name: Self.trustRevokedNotification, object: nil)
    }

    // -------------------------------------------------------------------------
    // Termination (NOT triggered by UI screens disappearing)
    // -------------------------------------------------------------------------

    /// Ends the current session. Intended call sites: application quit,
    /// a future Unpair feature, or a fatal protocol/network failure —
    /// never a screen's `viewWillDisappear` / `onDestroyView`.
    func terminate(reason: SessionTerminationReason) {
        guard let session = activeSession else { return }
        listenerTask?.cancel()
        listenerTask = nil
        Task { await session.client.disconnect() }
        activeSession = nil
    }
}
