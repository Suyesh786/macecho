package com.macecho.app.transport

import com.macecho.app.protocol.Packet
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.min
import kotlin.random.Random

/**
 * WebSocketClient.kt — Phase 7
 *
 * Transport client responsible only for:
 *   - Opening a WebSocket connection
 *   - Closing a WebSocket connection
 *   - Reconnecting automatically per documented timing
 *   - Sending opaque Packet bytes to the remote endpoint
 *   - Receiving opaque bytes from the remote endpoint
 *
 * Must NOT contain:
 *   - Authentication or trust validation   → Phase 13
 *   - Packet parsing or interpretation     → Phase 10
 *   - Serialization or deserialization     → deferred serialization phase
 *   - Cryptographic operations             → Phase 8
 *   - Pairing logic                        → Phase 12
 *   - Session management                   → Phase 13
 *   - Fragment, Activity, View, or Android system imports
 *   - Business logic of any kind
 *
 * Transport Boundary:
 *   send(packet) forwards only packet.encryptedPayload bytes.
 *   PacketReceived delivers raw bytes without any parsing.
 *   Higher layers (Phase 10+) interpret what was received.
 *
 * Dependency Injection:
 *   An existing OkHttpClient may be supplied. If none is provided, a default
 *   client is created internally with documented heartbeat (30 s) and
 *   connection timeout (90 s) settings. The caller owns any supplied client;
 *   only internally created clients are shut down on disconnect().
 *
 * @param providedClient Optional OkHttpClient. If null, a default is created.
 */
class WebSocketClient(
    providedClient: OkHttpClient? = null,
) {

    // -----------------------------------------------------------------------
    // Transport State
    // Internal to this layer only. Never exposed to authentication or
    // application layers. Callers observe state via TransportEvent only.
    // -----------------------------------------------------------------------

    sealed class TransportState {
        /** No connection attempt has been made yet. */
        object Idle : TransportState()
        /** WebSocket handshake is in progress. */
        object Connecting : TransportState()
        /** Handshake succeeded; ready to send and receive. */
        object Connected : TransportState()
        /** Connection was lost; backoff delay before next attempt. */
        object Reconnecting : TransportState()
        /** disconnect() was called; no further reconnects will occur. */
        object Disconnected : TransportState()
    }

    // -----------------------------------------------------------------------
    // Transport Events
    // -----------------------------------------------------------------------

    sealed class TransportEvent {
        /** WebSocket connection established. */
        object Connected : TransportEvent()
        /** Connection was closed (cleanly or unexpectedly). */
        object Disconnected : TransportEvent()
        /**
         * Raw bytes received from the remote endpoint.
         * No parsing is performed at the transport layer.
         * The caller (Phase 10+) is responsible for interpretation.
         */
        data class PacketReceived(val rawBytes: ByteArray) : TransportEvent()
        /** A transport-level error occurred. */
        data class TransportError(val cause: Throwable) : TransportEvent()
    }

    // -----------------------------------------------------------------------
    // Constants (sourced from documentation — do not change without updating docs)
    // -----------------------------------------------------------------------

    private companion object {
        /** 04_SECURITY_MODEL.md §Session Management */
        const val HEARTBEAT_INTERVAL_S = 30L
        /** 04_SECURITY_MODEL.md §Session Management */
        const val CONNECTION_TIMEOUT_S = 90L
        /** 07_PROTOCOL_SPECIFICATION.md §Reconnection Protocol */
        const val RECONNECT_INITIAL_DELAY_MS = 1_000L
        /** 07_PROTOCOL_SPECIFICATION.md §Reconnection Protocol */
        const val RECONNECT_MAX_DELAY_MS = 30_000L
        const val NORMAL_CLOSURE_CODE = 1000
    }

    // -----------------------------------------------------------------------
    // State and resource handles
    // -----------------------------------------------------------------------

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _events = MutableSharedFlow<TransportEvent>(extraBufferCapacity = 64)

    /** Observable stream of transport events. Collect from a coroutine. */
    val events: SharedFlow<TransportEvent> = _events

    @Volatile
    private var _state: TransportState = TransportState.Idle
    val state: TransportState get() = _state

    @Volatile private var _webSocket: WebSocket? = null
    @Volatile private var lastUrl: String? = null
    @Volatile private var currentReconnectDelayMs = RECONNECT_INITIAL_DELAY_MS

    private val isShutdown = AtomicBoolean(false)
    private var reconnectJob: Job? = null

    // -----------------------------------------------------------------------
    // OkHttpClient — dependency injection
    // If providedClient is null, an internal client is created with the
    // documented heartbeat and timeout settings. Only internally created
    // clients are shut down on disconnect().
    // -----------------------------------------------------------------------

    private val internalClient: OkHttpClient? =
        if (providedClient == null) {
            OkHttpClient.Builder()
                .pingInterval(HEARTBEAT_INTERVAL_S, TimeUnit.SECONDS)
                .readTimeout(CONNECTION_TIMEOUT_S, TimeUnit.SECONDS)
                .build()
        } else {
            null
        }

    private val okHttpClient: OkHttpClient = providedClient ?: checkNotNull(internalClient)

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /**
     * Opens a WebSocket connection to [url].
     *
     * If the connection fails or drops, reconnection is attempted automatically
     * per documented timing: 1 s initial, exponential backoff, 30 s maximum,
     * random jitter applied to each attempt.
     */
    fun connect(url: String) {
        check(!isShutdown.get()) { "Transport has been shut down. Create a new instance." }
        lastUrl = url
        currentReconnectDelayMs = RECONNECT_INITIAL_DELAY_MS
        _state = TransportState.Connecting
        connectInternal(url)
    }

    /**
     * Closes the WebSocket connection and cancels all background work.
     *
     * Cleanup guaranteed:
     *   1. Reconnect coroutine cancelled (no further attempts)
     *   2. WebSocket closed with normal close code
     *   3. Coroutine scope cancelled (no background work after this call)
     *   4. Internally created OkHttpClient shut down
     *
     * After this call, no events are emitted and no reconnects occur.
     * Idempotent — safe to call multiple times.
     */
    fun disconnect() {
        if (!isShutdown.compareAndSet(false, true)) return
        _state = TransportState.Disconnected

        // 1. Cancel reconnect — prevents any queued attempts from running
        reconnectJob?.cancel()
        reconnectJob = null

        // 2. Close socket
        _webSocket?.close(NORMAL_CLOSURE_CODE, "Client disconnected")
        _webSocket = null

        // 3. Emit final event, then cancel scope — prevents background work
        scope.launch {
            _events.emit(TransportEvent.Disconnected)
        }.invokeOnCompletion {
            scope.cancel()
        }

        // 4. Release internal client (caller owns any provided client)
        internalClient?.dispatcher?.executorService?.shutdown()
    }

    /**
     * Sends the opaque payload bytes of [packet] to the remote endpoint.
     *
     * Transport Boundary: only [Packet.encryptedPayload] bytes are sent.
     * Full packet serialisation (header + metadata + payload) is implemented
     * in the deferred serialisation phase.
     *
     * Returns silently if not currently connected.
     */
    fun send(packet: Packet) {
        if (isShutdown.get()) return
        _webSocket?.send(ByteString.of(*packet.encryptedPayload))
    }

    // -----------------------------------------------------------------------
    // Internal connection management
    // -----------------------------------------------------------------------

    private fun connectInternal(url: String) {
        if (isShutdown.get()) return
        val request = Request.Builder().url(url).build()
        okHttpClient.newWebSocket(request, createListener(url))
    }

    /**
     * Schedules a reconnect attempt after the current backoff delay.
     * The delay doubles on each call, capped at [RECONNECT_MAX_DELAY_MS].
     * Random jitter (±20 %) is applied per the spec.
     */
    private fun scheduleReconnect(url: String) {
        if (isShutdown.get()) return
        reconnectJob?.cancel()

        val delayMs = currentReconnectDelayMs
        currentReconnectDelayMs = min(delayMs * 2, RECONNECT_MAX_DELAY_MS)

        reconnectJob = scope.launch {
            _state = TransportState.Reconnecting
            val jitter = 0.8 + Random.nextDouble() * 0.4 // ±20 % per spec
            delay((delayMs * jitter).toLong())
            if (isActive && !isShutdown.get()) {
                _state = TransportState.Connecting
                connectInternal(url)
            }
        }
    }

    private fun createListener(url: String) = object : WebSocketListener() {

        override fun onOpen(webSocket: WebSocket, response: Response) {
            if (isShutdown.get()) {
                webSocket.close(NORMAL_CLOSURE_CODE, "Shutdown during connect")
                return
            }
            _webSocket = webSocket
            _state = TransportState.Connected
            currentReconnectDelayMs = RECONNECT_INITIAL_DELAY_MS // reset backoff
            scope.launch { _events.emit(TransportEvent.Connected) }
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            if (isShutdown.get()) return
            // Opaque bytes — transport never inspects or parses them
            scope.launch {
                _events.emit(TransportEvent.PacketReceived(bytes.toByteArray()))
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            // Binary-only transport. Text frames are silently ignored.
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(NORMAL_CLOSURE_CODE, null)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (isShutdown.get()) return
            _webSocket = null
            scope.launch { _events.emit(TransportEvent.Disconnected) }
            scheduleReconnect(url)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (isShutdown.get()) return
            _webSocket = null
            scope.launch { _events.emit(TransportEvent.TransportError(t)) }
            scheduleReconnect(url)
        }
    }
}
