/**
 * websocket.ts — Phase 7 + Phase 12.2 (pairing routing added)
 *
 * WebSocket transport module for the MacEcho backend relay.
 *
 * Phase 7 responsibilities (unchanged):
 *   - Accept WebSocket connections at the configured path
 *   - Send periodic Ping frames (heartbeat, 30 s)
 *   - Terminate connections inactive for 90 s
 *   - Log connect / disconnect / error events
 *
 * Phase 12.2 additions (pairing routing only):
 *   - On message arrival: attempt to parse as a PairingMessage (fast pre-check)
 *   - If recognised: route through PairingSessionManager
 *   - If not recognised: remain opaque (Phase 7 behaviour preserved)
 *
 * Transport Boundary (unchanged):
 *   Non-pairing messages are still treated as opaque bytes.
 *   The transport never inspects, modifies, or decrypts packet contents.
 *
 * Must NOT contain:
 *   - Authentication or trust validation   → Phase 13
 *   - Relay routing for non-pairing msgs   → Phase 14
 *   - Cryptography                         → Phase 8
 *   - Business logic beyond session routing
 */

import type { FastifyInstance } from "fastify";
import fastifyWebsocket from "@fastify/websocket";
import type { WebSocket } from "@fastify/websocket";
import { PairingSessionManager } from "../pairing/PairingSessionManager.js";
import {
  deserializePairingMessage,
  looksLikePairingMessage,
  serializePairingMessage,
  type PairingCancelled,
} from "../protocol/pairingPackets.js";

// ---------------------------------------------------------------------------
// Transport State
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

export interface TransportConfig {
  /** WebSocket endpoint path. Default: "/ws" */
  readonly path: string;
  /** Interval between Ping frames in ms. Default: 30 000 (30 s). */
  readonly heartbeatIntervalMs: number;
  /** Inactivity close threshold in ms. Default: 90 000 (90 s). */
  readonly connectionTimeoutMs: number;
  /** Pairing Session Manager instance */
  readonly pairingManager: PairingSessionManager;
}

const DEFAULT_CONFIG: Omit<TransportConfig, "pairingManager"> = Object.freeze({
  path: "/ws",
  heartbeatIntervalMs: 30_000,
  connectionTimeoutMs: 90_000,
});

// ---------------------------------------------------------------------------
// Transport Registration
// ---------------------------------------------------------------------------

export async function registerTransport(
  app: FastifyInstance,
  config: Partial<TransportConfig> & { pairingManager: PairingSessionManager },
): Promise<void> {
  const cfg: TransportConfig = { ...DEFAULT_CONFIG, ...config };

  await app.register(fastifyWebsocket, {
    options: { maxPayload: 1024 * 1024 }, // 1 MB limit
  });

  // Session tracking to ensure cleanup on disconnect
  const socketSessions = new WeakMap<WebSocket, { sessionId: string; role: "mac" | "android" }>();
  const publicKeysSent = new Map<string, number>();
  const fingerprintsSent = new Map<string, number>();

  app.get(cfg.path, { websocket: true }, (socket: WebSocket, req) => {
    app.log.info(
      {
        url: req.url,
        hostname: req.hostname,
        remoteAddress: req.ip,
      },
      "incoming request"
    );

    // -----------------------------------------------------------------------
    // Per-connection state and resource handles
    // -----------------------------------------------------------------------
    let state: TransportState = "CONNECTING";
    let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
    let timeoutTimer: ReturnType<typeof setTimeout> | null = null;

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

    function resetTimeout(): void {
      if (timeoutTimer !== null) clearTimeout(timeoutTimer);
      timeoutTimer = setTimeout(() => {
        app.log.warn("WebSocket connection timed out (90 s) — terminating");
        state = "DISCONNECTED";
        cleanup();
        socket.terminate();
      }, cfg.connectionTimeoutMs);
    }

    state = "CONNECTED";
    app.log.info("WebSocket client connected");
    resetTimeout();

    heartbeatTimer = setInterval(() => {
      if (state !== "CONNECTED") return;
      socket.ping();
      app.log.debug("WebSocket heartbeat ping sent");
    }, cfg.heartbeatIntervalMs);

    // -----------------------------------------------------------------------
    // Incoming message — Phase 12.2: route pairing messages
    // -----------------------------------------------------------------------
    socket.on("message", (data: Buffer) => {
      resetTimeout();

      const raw = data.toString("utf8");

      app.log.info({
        role: socketSessions.get(socket)?.role || "unknown",
        rawMessage: raw
      }, "PairingTrace: BACKEND RECEIVED RAW FRAME");

      if (!looksLikePairingMessage(raw)) {
        app.log.debug("WebSocket message received (opaque)");
        return;
      }

      const msg = deserializePairingMessage(raw);
      if (!msg) {
        app.log.debug("WebSocket message: looked like pairing but failed parse — treating opaque");
        return;
      }

      app.log.info({ type: msg.type, sessionId: msg.sessionId }, "Pairing message received");

      switch (msg.type) {
        case "PAIRING_MAC_JOIN": {
          cfg.pairingManager.createSession(msg.sessionId, socket);
          socketSessions.set(socket, { sessionId: msg.sessionId, role: "mac" });
          break;
        }

        case "PAIRING_JOIN": {
          const session = cfg.pairingManager.joinSession(msg.sessionId, socket);
          if (session) {
            socketSessions.set(socket, {
              sessionId: msg.sessionId,
              role: "android",
            });
          }
          break;
        }

        case "PAIRING_PUBLIC_KEY": {
          cfg.pairingManager.relay(msg.sessionId, socket, raw);
          const count = (publicKeysSent.get(msg.sessionId) ?? 0) + 1;
          publicKeysSent.set(msg.sessionId, count);
          break;
        }

        case "PAIRING_FINGERPRINT": {
          cfg.pairingManager.relay(msg.sessionId, socket, raw);
          const count = (fingerprintsSent.get(msg.sessionId) ?? 0) + 1;
          fingerprintsSent.set(msg.sessionId, count);
          if (count >= 2) {
            cfg.pairingManager.completeHandshake(msg.sessionId);
            fingerprintsSent.delete(msg.sessionId);
          }
          break;
        }

        case "PAIRING_CANCELLED": {
          cfg.pairingManager.destroySession(
            msg.sessionId,
            (msg as PairingCancelled).reason ?? "cancelled",
          );
          socketSessions.delete(socket);
          break;
        }

        default:
          app.log.debug({ type: msg.type }, "Unhandled pairing message type");
      }
    });

    socket.on("pong", () => {
      resetTimeout();
    });

    socket.on("close", (code: number) => {
      state = "DISCONNECTED";
      cleanup();
      app.log.info({ code }, "WebSocket client disconnected");
      cfg.pairingManager.handleDisconnect(socket);
      socketSessions.delete(socket);
    });

    socket.on("error", (err: Error) => {
      state = "DISCONNECTED";
      cleanup();
      app.log.error({ err }, "WebSocket transport error");
      cfg.pairingManager.handleDisconnect(socket);
      socketSessions.delete(socket);
    });
  });

  app.log.info(`WebSocket transport registered at ${cfg.path}`);
}
