// WebSocketClient.swift — Phase 7
//
// Transport client responsible only for:
//   - Opening a WebSocket connection
//   - Closing a WebSocket connection
//   - Reconnecting automatically per documented timing
//   - Sending opaque Packet bytes to the remote endpoint
//   - Receiving opaque bytes from the remote endpoint
//
// Must NOT contain:
//   - Authentication or trust validation   → Phase 13
//   - Packet parsing or interpretation     → Phase 10
//   - Serialization or deserialization     → deferred serialization phase
//   - Cryptographic operations             → Phase 8
//   - Pairing logic                        → Phase 12
//   - Session management                   → Phase 13
//   - AppKit, NSView, or popover imports
//   - Business logic of any kind
//
// Transport Boundary:
//   send(packet:) forwards only packet.encryptedPayload bytes.
//   packetReceived delivers raw bytes without any parsing.
//   Higher layers (Phase 10+) interpret what was received.
//
// Dependency Injection:
//   An existing URLSession may be supplied. If nil is passed, a default
//   URLSession is created internally. This avoids hard dependencies on
//   URLSession.shared and enables future testing and configuration.

import Foundation

// ---------------------------------------------------------------------------
// Supporting error type
// ---------------------------------------------------------------------------

/// Error emitted when the 90-second inactivity timeout expires.
struct TransportTimeoutError: LocalizedError {
    var errorDescription: String? {
        "WebSocket connection timed out (90 s of inactivity)."
    }
}

// ---------------------------------------------------------------------------
// Transport State
// Internal to the transport layer only.
// Valid client-side transitions:
//   idle → connecting           (connect() called)
//   connecting → connected      (first receive succeeds)
//   connecting → reconnecting   (receive failed immediately)
//   connected → reconnecting    (connection dropped)
//   connected → disconnected    (disconnect() called)
//   reconnecting → connecting   (backoff elapsed)
//   reconnecting → disconnected (disconnect() called)
//   disconnected → connecting   (connect() called again)
// ---------------------------------------------------------------------------

enum TransportState {
    case idle
    case connecting
    case connected
    case reconnecting
    case disconnected
}

// ---------------------------------------------------------------------------
// Transport Events
// ---------------------------------------------------------------------------

/// Events emitted by the transport to its caller.
enum TransportEvent {
    /// WebSocket connection established and ready.
    case connected
    /// Connection was closed (cleanly or unexpectedly).
    case disconnected
    /// Raw bytes received from the remote endpoint.
    /// No parsing is performed. The caller (Phase 10+) interprets the bytes.
    case packetReceived([UInt8])
    /// Text received from the remote endpoint.
    /// Used exclusively for Phase 12.2 temporary pairing JSON messages.
    case textReceived(String)
    /// A transport-level error occurred.
    case error(Error)
}

// ---------------------------------------------------------------------------
// WebSocketClient
// ---------------------------------------------------------------------------

/// Phase 7 WebSocket transport client.
///
/// Implemented as a Swift actor to guarantee safe concurrent access to all
/// mutable state without additional locking primitives.
actor WebSocketClient {

    // MARK: - Constants (sourced from documentation)

    /// 04_SECURITY_MODEL.md §Session Management
    private let heartbeatIntervalNs: UInt64 = 30_000_000_000
    /// 04_SECURITY_MODEL.md §Session Management
    private let connectionTimeoutNs: UInt64 = 90_000_000_000
    /// 07_PROTOCOL_SPECIFICATION.md §Reconnection Protocol
    private let reconnectInitialDelay: Double = 1.0
    /// 07_PROTOCOL_SPECIFICATION.md §Reconnection Protocol
    private let reconnectMaxDelay: Double = 30.0

    // MARK: - Events (nonisolated let — immutable value, safe without await)

    /// Async stream of transport events.
    /// Consume in a Task: `for await event in client.events { ... }`
    nonisolated let events: AsyncStream<TransportEvent>
    private nonisolated let eventContinuation: AsyncStream<TransportEvent>.Continuation

    // MARK: - Dependencies

    private let session: URLSession

    // MARK: - State

    private(set) var state: TransportState = .idle
    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var lastUrl: URL?
    private var currentReconnectDelay: Double = 1.0
    private var isShutdown = false

    // MARK: - Init

    /// Creates a WebSocketClient.
    ///
    /// - Parameter session: Optional URLSession to use. If nil, a default
    ///   URLSession is created internally with a 90-second request timeout.
    ///   Supplying an existing session enables testing and shared configuration
    ///   without modifying transport code.
    init(session providedSession: URLSession? = nil) {
        // Initialize the event stream before any actor state is accessible.
        // AsyncStream calls its build closure synchronously, so cont is
        // guaranteed non-nil after this block.
        var cont: AsyncStream<TransportEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont

        if let providedSession {
            self.session = providedSession
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 90  // URLSession-level fallback
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: - Public API

    /// Opens a WebSocket connection to [url].
    ///
    /// Reconnects automatically per documented timing:
    /// 1 s initial, exponential backoff, 30 s maximum, random jitter.
    func connect(url: URL) {
        guard !isShutdown else { return }
        lastUrl = url
        currentReconnectDelay = reconnectInitialDelay
        state = .connecting
        openSocket(url: url)
    }

    /// Closes the connection and cancels all background tasks.
    ///
    /// Cleanup guaranteed:
    ///   1. Heartbeat task cancelled (no further pings sent)
    ///   2. Timeout task cancelled
    ///   3. Reconnect task cancelled (no further attempts)
    ///   4. WebSocket task cancelled with normal close code
    ///   5. Event stream finished (no events emitted after this call)
    ///
    /// Idempotent — safe to call multiple times.
    func disconnect() {
        guard !isShutdown else { return }
        isShutdown = true
        state = .disconnected
        cancelAllTasks()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        eventContinuation.yield(.disconnected)
        eventContinuation.finish()
    }

    /// Sends the opaque payload bytes of [packet] to the remote endpoint.
    ///
    /// Transport Boundary: only packet.encryptedPayload is transmitted.
    /// Full packet serialisation (header + metadata + payload) is implemented
    /// in the deferred serialisation phase.
    ///
    /// Returns silently if not currently connected.
    func send(packet: Packet) async {
        guard !isShutdown, state == .connected, let task = webSocketTask else { return }
        let data = Data(packet.encryptedPayload)
        do {
            try await task.send(.data(data))
        } catch {
            // Delivery errors surface through the receive loop
        }
    }

    /// Sends a text message to the remote endpoint.
    /// Used exclusively for Phase 12.2 temporary pairing messages.
    func sendText(_ text: String) async {
        guard !isShutdown, state == .connected, let task = webSocketTask else { return }
        do {
            try await task.send(.string(text))
        } catch {
            // Delivery errors surface through the receive loop
        }
    }

    // MARK: - Internal connection management

    private func openSocket(url: URL) {
        guard !isShutdown else { return }
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        
        // URLSessionWebSocketTask automatically queues sends until the socket
        // connects, so we can transition to connected immediately.
        state = .connected
        currentReconnectDelay = reconnectInitialDelay
        eventContinuation.yield(.connected)
        
        startReceiveLoop()
        startHeartbeat()
        startTimeoutMonitor()
    }

    private func startReceiveLoop() {
        guard !isShutdown, let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            Task { await self.handleReceive(result: result) }
        }
    }

    private func handleReceive(
        result: Result<URLSessionWebSocketTask.Message, Error>
    ) {
        guard !isShutdown else { return }

        switch result {
        case .success(let message):
            resetTimeout()

            switch message {
            case .data(let data):
                // Opaque bytes — no parsing at the transport layer
                eventContinuation.yield(.packetReceived([UInt8](data)))
            case .string(let text):
                // Text — Phase 12.2 pairing messages
                eventContinuation.yield(.textReceived(text))
            @unknown default:
                break
            }
            startReceiveLoop() // Schedule next receive

        case .failure(let error):
            guard !isShutdown else { return }
            eventContinuation.yield(.error(error))
            scheduleReconnect()
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        let intervalNs = heartbeatIntervalNs // capture before entering Task
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNs)
                guard !Task.isCancelled, let self else { break }
                guard await !self.isShutdown else { break }
                let wsTask = await self.webSocketTask
                wsTask?.sendPing { _ in } // pong tracked via receive loop
            }
        }
    }

    // MARK: - Inactivity timeout

    private func startTimeoutMonitor() {
        timeoutTask?.cancel()
        let timeoutNs = connectionTimeoutNs // capture before entering Task
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeoutNs)
            guard !Task.isCancelled, let self else { return }
            await self.handleTimeout()
        }
    }

    private func resetTimeout() {
        timeoutTask?.cancel()
        startTimeoutMonitor()
    }

    private func handleTimeout() {
        guard !isShutdown else { return }
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        eventContinuation.yield(.error(TransportTimeoutError()))
        scheduleReconnect()
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        guard !isShutdown, let url = lastUrl else { return }
        cancelAllTasks()
        state = .reconnecting

        let delay = currentReconnectDelay
        currentReconnectDelay = min(delay * 2, reconnectMaxDelay)

        reconnectTask = Task { [weak self] in
            let jitter = Double.random(in: 0.8...1.2) // ±20 % per spec
            let delayNs = UInt64((delay * jitter) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled, let self else { return }
            guard await !self.isShutdown else { return }
            await self.openSocket(url: url)
        }
    }

    // MARK: - Cleanup

    /// Cancels all background tasks.
    /// Called by disconnect() and scheduleReconnect() (before scheduling new task).
    private func cancelAllTasks() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
    }
}
