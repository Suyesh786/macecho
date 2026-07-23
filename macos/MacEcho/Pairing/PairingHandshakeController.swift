// PairingHandshakeController.swift — Phase 12.2
//
// Drives the macOS side of the pairing handshake after the QR code is generated.
//
// Responsibilities:
//   - Opens WebSocket to the backend
//   - Sends PAIRING_MAC_JOIN
//   - Handles Android joining (PAIRING_READY)
//   - Generates ephemeral X25519 key pair, sends public key
//   - Receives Android's public key, derives shared secret
//   - Computes SHA-256 fingerprint, exchanges with Android
//   - Emits state updates via an AsyncStream
//
// Must NOT contain:
//   - Permanent trust establishment (Phase 12.3)
//   - Keychain storage (Phase 12.3)
//   - UI / AppKit logic

import Foundation
import CryptoKit

actor PairingHandshakeController {

    private let token: PairingSessionToken
    private let deviceId: String
    private let client: WebSocketClient

    /// Exposes the underlying transport so the caller (PairDeviceViewController)
    /// can hand ownership to AppSessionManager once `.secureChannelReady` is
    /// reported. This does not open a second connection — it is the same
    /// `WebSocketClient` this controller has been using throughout the
    /// handshake. Added for the connection-ownership fix; the handshake
    /// logic below is otherwise unchanged.
    nonisolated var transportClient: WebSocketClient { client }

    /// Exposes the paired device's identity once received, so the caller can
    /// hand it to AppSessionManager alongside the transport on success.
    /// Read-only outside the actor; populated during the existing handshake
    /// flow (unchanged) via `handlePairingMessage`.
    var pairedIdentity: PairingIdentity? { androidIdentityReceived }

    private var ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var derivedKey: SymmetricKey?
    
    private var androidPublicKeyReceived = false
    private var macKeyHasBeenSent = false
    
    private var ourFingerprint: String?
    private var androidFingerprintReceived: String?
    private var androidIdentityReceived: PairingIdentity?

    // Event stream for state updates
    nonisolated let stateStream: AsyncStream<MacPairingState>
    private nonisolated let stateContinuation: AsyncStream<MacPairingState>.Continuation

    private var transportTask: Task<Void, Never>?
    
    /// Current state. Set privately, emitted via stream.
    private var state: MacPairingState = .unpaired {
        didSet {
            stateContinuation.yield(state)
        }
    }

    init(token: PairingSessionToken, deviceId: String = UUID().uuidString) {
        self.token = token
        self.deviceId = deviceId
        self.client = WebSocketClient()
        
        var cont: AsyncStream<MacPairingState>.Continuation!
        self.stateStream = AsyncStream { cont = $0 }
        self.stateContinuation = cont
    }

    /// Starts the handshake by connecting to the backend.
    func start() async {
        guard let url = URL(string: token.backendUrl) else {
            state = .failed(.connectionFailed("Invalid backend URL"))
            return
        }
        
        state = .waitingForAndroid
        
        // Generate ephemeral key pair
        ephemeralPrivateKey = CryptoManager.generateX25519PrivateKey()
        
        startTransportTask()
        await client.connect(url: url)
    }

    /// Cancels the session explicitly.
    func cancel(reason: String = "user_cancelled") {
        if state.isTerminal || state == .unpaired { return }
        
        Task {
            if let cancelData = PairingMessageSerializer.encodeCancelled(sessionId: token.sessionId, reason: reason),
               let cancelText = String(data: cancelData, encoding: .utf8) {
                await client.sendText(cancelText)
            }
            await cleanup(newState: .failed(.sessionCancelled(reason)))
        }
    }
    
    /// Cleans up resources, closes WebSocket (if failed), destroys keys.
    private func cleanup(newState: MacPairingState) {
        state = newState
        
        // Do not disconnect if pairing succeeded — the socket is handed to
        // AppSessionManager by the caller (PairDeviceViewController) via
        // `transportClient`, which becomes its long-lived owner. This
        // controller must not close a connection it no longer owns.
        if newState != .secureChannelReady {
            Task { await client.disconnect() }
        }
        
        transportTask?.cancel()
        
        // CryptoKit manages PrivateKey/SymmetricKey memory securely and zeroes them on deallocation.
        ephemeralPrivateKey = nil
        derivedKey = nil
        
        macKeyHasBeenSent = false
        androidPublicKeyReceived = false
        ourFingerprint = nil
        androidFingerprintReceived = nil
    }

    private func startTransportTask() {
        transportTask?.cancel()
        transportTask = Task { [weak self] in
            guard let self else { return }
            for await event in await self.client.events {
                if Task.isCancelled { break }
                await self.handleTransportEvent(event)
            }
        }
    }

    private func handleTransportEvent(_ event: TransportEvent) async {
        switch event {
        case .connected:
            // Connection established, register as Mac
            if let data = PairingMessageSerializer.encodeMacJoin(sessionId: token.sessionId, senderId: deviceId),
               let text = String(data: data, encoding: .utf8) {
                await client.sendText(text)
            }
        case .disconnected:
            if !state.isTerminal && state != .unpaired {
                cleanup(newState: .failed(.unexpectedDisconnect))
            }
        case .error(let error):
            if !state.isTerminal && state != .unpaired {
                cleanup(newState: .failed(.connectionFailed(error.localizedDescription)))
            }
        case .textReceived(let text):
            handlePairingMessage(text)
        case .packetReceived:
            break // Ignore opaque binary packets during pairing
        }
    }

    private func handlePairingMessage(_ text: String) {
        guard let message = PairingMessageSerializer.decode(text) else { return }

        switch message {
        case .ready(let m):
            guard m.sessionId == token.sessionId else { return }
            state = .androidConnected
            Task { await sendIdentity() }

        case .identity(let m):
            print("PairingTrace: RECEIVE PAIRING_IDENTITY")
            guard m.sessionId == token.sessionId else { return }
            androidIdentityReceived = m

        case .publicKey(let m):
            print("PairingTrace: RECEIVE PAIRING_PUBLIC_KEY")
            guard m.sessionId == token.sessionId else { return }
            guard !androidPublicKeyReceived else { return }
            androidPublicKeyReceived = true
            handleAndroidPublicKey(m.publicKey)

        case .fingerprint(let m):
            print("PairingTrace: RECEIVE PAIRING_FINGERPRINT")
            guard m.sessionId == token.sessionId else { return }
            androidFingerprintReceived = m.fingerprint
            tryVerifyFingerprints()

        case .cancelled(let m):
            guard m.sessionId == token.sessionId else { return }
            cleanup(newState: .failed(.sessionCancelled(m.reason)))

        case .timeout(let m):
            guard m.sessionId == token.sessionId else { return }
            cleanup(newState: .failed(.sessionExpired))
        }
    }

    private func sendIdentity() async {
        // Read or generate our long-term identity keys
        let deviceName = Host.current().localizedName ?? "Mac"
        guard let identity = try? KeychainManager().generateIdentity(deviceName: deviceName, deviceType: "Mac") else {
            cleanup(newState: .failed(.keyExchangeFailed))
            return
        }
        let ed25519PubB64 = identity.ed25519PublicKey.rawRepresentation.base64EncodedString()
        let x25519PubB64 = identity.x25519PublicKey.rawRepresentation.base64EncodedString()
        
        if let data = PairingMessageSerializer.encodeIdentity(
            sessionId: token.sessionId,
            senderId: deviceId,
            deviceName: identity.deviceName,
            deviceType: identity.deviceType,
            ed25519PublicKey: ed25519PubB64,
            x25519PublicKey: x25519PubB64
        ), let text = String(data: data, encoding: .utf8) {
            print("PairingTrace: SEND PAIRING_IDENTITY")
            await client.sendText(text)
        }
        
        // Immediately follow up with the ephemeral public key per the protocol sequence
        await sendEphemeralPublicKey()
    }

    private func sendEphemeralPublicKey() async {
        guard !macKeyHasBeenSent else { return }
        macKeyHasBeenSent = true
        
        if state == .androidConnected {
            state = .exchangingKeys
        }
        
        guard let privKey = ephemeralPrivateKey else {
            cleanup(newState: .failed(.keyExchangeFailed))
            return
        }
        
        let pubKey = privKey.publicKey
        let pubKeyB64 = pubKey.rawRepresentation.base64EncodedString()
        
        if let data = PairingMessageSerializer.encodePublicKey(sessionId: token.sessionId, senderId: deviceId, publicKeyB64: pubKeyB64),
           let text = String(data: data, encoding: .utf8) {
            print("PairingTrace: SEND PAIRING_PUBLIC_KEY")
            await client.sendText(text)
        }
    }

    private func handleAndroidPublicKey(_ pubKeyB64: String) {
        guard let privKey = ephemeralPrivateKey else {
            cleanup(newState: .failed(.keyExchangeFailed))
            return
        }
        
        guard let pubKeyData = Data(base64Encoded: pubKeyB64) else {
            cleanup(newState: .failed(.keyExchangeFailed))
            return
        }
        
        do {
            let peerPubKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: pubKeyData)
            
            // Derive raw shared secret
            let sharedSecret = try CryptoManager.deriveX25519SharedSecret(privateKey: privKey, peerPublicKey: peerPubKey)
            
            // Derive session key via HKDF-SHA256
            let salt = Data() // Empty salt per RFC 5869 §2.2 if none provided
            derivedKey = CryptoManager.hkdfSha256(
                inputKeyMaterial: sharedSecret,
                salt: salt,
                info: "macecho-pairing-v1".data(using: .utf8)!,
                outputByteCount: 32
            )
            
            // Do NOT set ephemeralPrivateKey to nil here! It might still be needed by sendEphemeralPublicKey if it hasn't run yet.
            
            guard let derived = derivedKey else {
                cleanup(newState: .failed(.keyExchangeFailed))
                return
            }
            
            // Compute fingerprint
            let hash = CryptoManager.sha256(derived.withUnsafeBytes { Data($0) })
            let fingerprintBytes = hash.prefix(8)
            let fingerprintHex = fingerprintBytes.map { String(format: "%02x", $0) }.joined()
            ourFingerprint = fingerprintHex
            
            state = .verifying
            
            if let data = PairingMessageSerializer.encodeFingerprint(sessionId: token.sessionId, senderId: deviceId, fingerprint: fingerprintHex),
               let text = String(data: data, encoding: .utf8) {
                print("PairingTrace: SEND PAIRING_FINGERPRINT (\(fingerprintHex))")
                Task { await client.sendText(text) }
            }
            
            // If Android fingerprint arrived early/simultaneously, verify now
            tryVerifyFingerprints()
            
        } catch {
            cleanup(newState: .failed(.keyExchangeFailed))
        }
    }

    private func tryVerifyFingerprints() {
        print("PairingTrace: tryVerifyFingerprints (ours=\(ourFingerprint ?? "nil"), theirs=\(androidFingerprintReceived ?? "nil"))")
        guard let ours = ourFingerprint, let theirs = androidFingerprintReceived else {
            return // Still waiting
        }
        
        // Let CryptoKit zero out the derived key after we verify
        derivedKey = nil
        
        print("PairingTrace: VALIDATE FINGERPRINT (ours=\(ours), theirs=\(theirs))")
        if ours == theirs {
            if let identity = androidIdentityReceived,
               let ed25519PubKeyData = Data(base64Encoded: identity.ed25519PublicKey),
               let x25519PubKeyData = Data(base64Encoded: identity.x25519PublicKey) {
                print("PairingTrace: FINGERPRINT_MATCH. Saving TrustEntry.")
                let entry = TrustEntry(
                    trustedDeviceId: identity.senderId,
                    trustedX25519PublicKeyData: x25519PubKeyData,
                    trustedEd25519PublicKeyData: ed25519PubKeyData,
                    pairingTimestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                    trustStatus: .trusted,
                    deviceName: identity.deviceName,
                    deviceType: identity.deviceType
                )
                do {
                    try TrustStore().addOrUpdate(entry)
                    print("PairingTrace: TrustStore updated successfully.")
                } catch {
                    print("PairingTrace: Failed to save TrustEntry: \(error)")
                }
            } else {
                print("PairingTrace: FINGERPRINT_MATCH but Identity missing or invalid.")
            }
            print("PairingTrace: SECURE_CHANNEL_READY")
            cleanup(newState: .secureChannelReady)
        } else {
            print("PairingTrace: FINGERPRINT_MISMATCH")
            cleanup(newState: .failed(.fingerprintMismatch))
        }
    }
}
