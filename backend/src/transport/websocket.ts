/**
 * websocket.ts — Phase 7
 *
 * WebSocket transport module for the MacEcho backend relay.
 *
 * Responsibilities (Phase 7 only):
 *   - Accept WebSocket connections at the configured path
 *   - Send periodic Ping frames (heartbeat, 30 s)
 *   - Terminate connections inactive for 90 s
 *   - Forward opaque binary messages between clients (Phase 14 relay — not yet)
 *   - Log connect / disconnect / error events
 *
 * Must NOT contain:
 *   - Authentication or trust validation   → Phase 13
 *   - Packet parsing or inspection         → Phase 10
 *   - Relay routing                        → Phase 14
 *   - Serialization or deserialization     → deferred serialization phase
 *   - Session management                   → Phase 13
 *   - Cryptography                         → Phase 8
 *   - Business logic of any kind
 *
 * Transport Boundary:
 *   Every message is treated as opaque bytes.
 *   The transport never inspects, validates, modifies, or routes packet
 *   contents. No packet meaning is ever understood at this layer.
 *
 * Dependency Injection:
 *   Configuration is supplied through TransportConfig — no hardcoded values
 *   inside this module. Defaults match documented timing exactly.
 */

import type { FastifyInstance } from "fastify";
import fastifyWebsocket from "@fastify/websocket";
import type { WebSocket } from "@fastify/websocket";

// ---------------------------------------------------------------------------
// Transport State
// Internal to the transport layer only. Never exposed to authentication or
// application layers.
//
// Valid server-side transitions per connection:
//   IDLE → CONNECTING   (connection request received)
//   CONNECTING → CONNECTED   (handshake complete)
//   CONNECTED → DISCONNECTED (client disconnected or timeout)
//
// RECONNECTING is reserved for client-side transport parity with Android/macOS.
// ---------------------------------------------------------------------------

type TransportState =
  | "IDLE"
  | "CONNECTING"
  | "CONNECTED"
  | "DISCONNECTED"
  | "RECONNECTING";

// ---------------------------------------------------------------------------
// Transport Configuration (Dependency Injection)
// ---------------------------------------------------------------------------

/**
 * Configuration for the WebSocket transport module.
 *
 * All values are injected at registration time — no hardcoded constants
 * inside this module. Callers may override any field; unspecified fields
 * fall back to documented defaults.
 *
 * Timing values sourced from:
 *   heartbeatIntervalMs  — 04_SECURITY_MODEL.md §Session Management (30 s)
 *   connectionTimeoutMs  — 04_SECURITY_MODEL.md §Session Management (90 s)
 */
export interface TransportConfig {
  /** WebSocket endpoint path. Default: "/ws" */
  readonly path: string;
  /** Interval between Ping frames in ms. Default: 30 000 (30 s). */
  readonly heartbeatIntervalMs: number;
  /** Inactivity close threshold in ms. Default: 90 000 (90 s). */
  readonly connectionTimeoutMs: number;
}

const DEFAULT_CONFIG: TransportConfig = Object.freeze({
  path: "/ws",
  heartbeatIntervalMs: 30_000,
  connectionTimeoutMs: 90_000,
});

// ---------------------------------------------------------------------------
// Transport Registration
// ---------------------------------------------------------------------------

/**
 * Registers the WebSocket transport with the provided Fastify instance.
 *
 * Called once from server.ts after all other routes are registered.
 * server.ts must remain thin — no transport logic belongs there.
 *
 * @param app    Fastify instance from server.ts.
 * @param config Optional partial config; unspecified fields use defaults.
 */
export async function registerTransport(
  app: FastifyInstance,
  config: Partial<TransportConfig> = {},
): Promise<void> {
  const cfg: TransportConfig = { ...DEFAULT_CONFIG, ...config };

  await app.register(fastifyWebsocket);

  app.get(cfg.path, { websocket: true }, (socket: WebSocket) => {
    // -----------------------------------------------------------------------
    // Per-connection state and resource handles
    // -----------------------------------------------------------------------
    let state: TransportState = "CONNECTING";
    let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
    let timeoutTimer: ReturnType<typeof setTimeout> | null = null;

    // -----------------------------------------------------------------------
    // Deterministic cleanup
    // Cancels all timers and removes all references for this connection.
    // Called on every exit path (close or error) to prevent resource leaks.
    // -----------------------------------------------------------------------
    function cleanup(): void {
      if (heartbeatTimer !== null) {
        clearInterval(heartbeatTimer);
        heartbeatTimer = null;
      }
      if (timeoutTimer !== null) {
        clearTimeout(timeoutTimer);
        timeoutTimer = null;
      }
    }

    // -----------------------------------------------------------------------
    // Inactivity timeout
    // Resets on every received message or pong frame.
    // -----------------------------------------------------------------------
    function resetTimeout(): void {
      if (timeoutTimer !== null) clearTimeout(timeoutTimer);
      timeoutTimer = setTimeout(() => {
        app.log.warn("WebSocket connection timed out (90 s) — terminating");
        state = "DISCONNECTED";
        cleanup();
        socket.terminate();
      }, cfg.connectionTimeoutMs);
    }

    // -----------------------------------------------------------------------
    // Connection established
    // -----------------------------------------------------------------------
    state = "CONNECTED";
    app.log.info("WebSocket client connected");
    resetTimeout();

    // Heartbeat: send Ping frame every 30 s per 04_SECURITY_MODEL.md
    heartbeatTimer = setInterval(() => {
      if (state !== "CONNECTED") return;
      socket.ping();
      app.log.debug("WebSocket heartbeat ping sent");
    }, cfg.heartbeatIntervalMs);

    // -----------------------------------------------------------------------
    // Incoming message — opaque binary, no parsing, no routing
    // -----------------------------------------------------------------------
    socket.on("message", (_data: Buffer) => {
      resetTimeout();
      app.log.debug("WebSocket message received (opaque)");
    });

    // Pong frames also reset the inactivity timeout
    socket.on("pong", () => {
      resetTimeout();
    });

    // -----------------------------------------------------------------------
    // Disconnect — deterministic cleanup guaranteed
    // -----------------------------------------------------------------------
    socket.on("close", (code: number) => {
      state = "DISCONNECTED";
      cleanup();
      app.log.info({ code }, "WebSocket client disconnected");
    });

    // -----------------------------------------------------------------------
    // Error — deterministic cleanup, no crash
    // -----------------------------------------------------------------------
    socket.on("error", (err: Error) => {
      state = "DISCONNECTED";
      cleanup();
      app.log.error({ err }, "WebSocket transport error");
    });
  });

  app.log.info(`WebSocket transport registered at ${cfg.path}`);
}
