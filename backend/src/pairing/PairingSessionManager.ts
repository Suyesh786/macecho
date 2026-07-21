/**
 * PairingSessionManager.ts — Phase 12.2
 *
 * In-memory store for temporary pairing sessions.
 *
 * Responsibilities:
 *   - Create a session when Mac opens the Pair Device screen
 *   - Register the Android socket when Android joins
 *   - Route PAIRING_READY / PAIRING_JOIN_ACK notifications
 *   - Auto-expire sessions after 300 s (must match QR TTL)
 *   - Transition to HANDSHAKE_COMPLETE for 30 s after both devices derive
 *     their shared secret, then destroy — gives Phase 12.3 a clean window
 *   - Symmetric cancellation: destroying a session always notifies the other side
 *
 * Must NOT contain:
 *   - Decryption / key inspection     → forbidden for backend
 *   - Trust establishment             → Phase 12.3
 *   - Persistent storage of any kind  → sessions are in-memory only
 *   - Business logic beyond session lifecycle
 */

import type { WebSocket } from "@fastify/websocket";
import {
  serializePairingMessage,
  type PairingTimeout,
  type PairingCancelled,
  type PairingReady,
  type PairingJoinAck,
} from "../protocol/pairingPackets.js";

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

export type PairingSessionState =
  | "WAITING"             // Mac registered, waiting for Android
  | "MAC_CONNECTED"       // Mac connected (alias of WAITING — explicit for clarity)
  | "ANDROID_CONNECTED"   // Both sockets present
  | "READY"               // Both sides have exchanged keys (fingerprint phase)
  | "HANDSHAKE_COMPLETE"  // Both fingerprints matched; 30-s grace window for Phase 12.3
  | "DESTROYED";          // Session cleaned up

// ---------------------------------------------------------------------------
// Session record
// ---------------------------------------------------------------------------

export interface PairingSession {
  readonly sessionId: string;
  macSocket: WebSocket | null;
  androidSocket: WebSocket | null;
  readonly createdAt: number;   // Unix epoch ms
  readonly expiresAt: number;   // createdAt + SESSION_TTL_MS
  state: PairingSessionState;
  /** Only set after handshake completes — for the 30-s cleanup window. */
  handshakeCompleteAt?: number;
}

// ---------------------------------------------------------------------------
// Constants (must match QR lifetime exactly)
// ---------------------------------------------------------------------------

/** 300 000 ms = 300 s = 5 minutes — matches QR code TTL exactly. */
const SESSION_TTL_MS = 300_000;

/** 30 s grace window in HANDSHAKE_COMPLETE before cleanup. */
const HANDSHAKE_GRACE_MS = 30_000;

/** Expiry sweep runs every 15 s to catch expired sessions promptly. */
const SWEEP_INTERVAL_MS = 15_000;

// ---------------------------------------------------------------------------
// PairingSessionManager
// ---------------------------------------------------------------------------

export class PairingSessionManager {
  private readonly sessions = new Map<string, PairingSession>();
  private readonly sweepTimer: ReturnType<typeof setInterval>;

  constructor(private readonly log: { info: (msg: string) => void; warn: (msg: string) => void }) {
    // Periodic sweep: expire sessions whose TTL or grace window has passed.
    this.sweepTimer = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /**
   * Registers a new pairing session when the Mac opens Pair Device.
   * The macSocket is the WebSocket connection for this Mac.
   * Replaces any previous session with the same sessionId.
   */
  createSession(sessionId: string, macSocket: WebSocket): PairingSession {
    // Destroy any prior session with the same ID cleanly.
    this.destroySession(sessionId, "replaced");

    const now = Date.now();
    const session: PairingSession = {
      sessionId,
      macSocket,
      androidSocket: null,
      createdAt: now,
      expiresAt: now + SESSION_TTL_MS,
      state: "MAC_CONNECTED",
    };
    this.sessions.set(sessionId, session);
    this.log.info(`PairingSession created: ${sessionId}`);
    return session;
  }

  /**
   * Registers the Android socket for an existing session.
   * Returns the session if found and not expired; null otherwise.
   * Sends PAIRING_JOIN_ACK to Android and PAIRING_READY to Mac.
   */
  joinSession(
    sessionId: string,
    androidSocket: WebSocket,
  ): PairingSession | null {
    const session = this.sessions.get(sessionId);
    if (!session) {
      this.log.warn(`PAIRING_JOIN for unknown session: ${sessionId}`);
      return null;
    }
    if (session.state === "DESTROYED") {
      this.log.warn(`PAIRING_JOIN for destroyed session: ${sessionId}`);
      return null;
    }
    if (Date.now() > session.expiresAt) {
      this.log.warn(`PAIRING_JOIN for expired session: ${sessionId}`);
      this.destroySession(sessionId, "expired");
      return null;
    }

    session.androidSocket = androidSocket;
    session.state = "ANDROID_CONNECTED";

    // Notify Android
    const ack: PairingJoinAck = {
      type: "PAIRING_JOIN_ACK",
      sessionId,
      timestamp: Date.now(),
      macConnected: session.macSocket !== null,
    };
    this.sendTo(androidSocket, ack);

    // Notify Mac
    if (session.macSocket) {
      const ready: PairingReady = {
        type: "PAIRING_READY",
        sessionId,
        timestamp: Date.now(),
      };
      this.sendTo(session.macSocket, ready);
    }

    this.log.info(`PairingSession ANDROID_CONNECTED: ${sessionId}`);
    return session;
  }

  /** Returns the session if it exists and is not destroyed. */
  getSession(sessionId: string): PairingSession | null {
    const session = this.sessions.get(sessionId);
    if (!session || session.state === "DESTROYED") return null;
    return session;
  }

  /**
   * Relays a raw message string from one socket to the other side.
   * Used for PAIRING_PUBLIC_KEY and PAIRING_FINGERPRINT.
   * The backend never inspects the content of these messages.
   */
  relay(sessionId: string, fromSocket: WebSocket, rawMessage: string): void {
    const session = this.sessions.get(sessionId);
    if (!session || session.state === "DESTROYED") return;

    const target =
      fromSocket === session.macSocket
        ? session.androidSocket
        : session.macSocket;

    if (target) {
      target.send(rawMessage);
    }
  }

  /**
   * Advances session to READY state (both sides have sent their public keys).
   * Called when the backend observes both PAIRING_PUBLIC_KEY messages have been relayed.
   * The backend does NOT inspect the key bytes.
   */
  advanceToReady(sessionId: string): void {
    const session = this.sessions.get(sessionId);
    if (!session || session.state === "DESTROYED") return;
    if (session.state === "ANDROID_CONNECTED") {
      session.state = "READY";
      this.log.info(`PairingSession READY: ${sessionId}`);
    }
  }

  /**
   * Transitions session to HANDSHAKE_COMPLETE after both fingerprints are relayed.
   * Schedules automatic cleanup after HANDSHAKE_GRACE_MS.
   */
  completeHandshake(sessionId: string): void {
    const session = this.sessions.get(sessionId);
    if (!session || session.state === "DESTROYED") return;
    session.state = "HANDSHAKE_COMPLETE";
    session.handshakeCompleteAt = Date.now();
    this.log.info(
      `PairingSession HANDSHAKE_COMPLETE: ${sessionId} — cleanup in 30 s`,
    );
  }

  /**
   * Destroys a session and symmetrically notifies both sides.
   * Always safe to call — idempotent if already destroyed.
   *
   * @param reason Human-readable reason string for logging and notification.
   */
  destroySession(sessionId: string, reason: string): void {
    const session = this.sessions.get(sessionId);
    if (!session || session.state === "DESTROYED") return;
    session.state = "DESTROYED";

    // Determine which message to send based on reason
    const isCancelled = reason !== "expired" && reason !== "timeout";
    const timestamp = Date.now();

    if (reason === "expired" || reason === "timeout") {
      const msg: PairingTimeout = {
        type: "PAIRING_TIMEOUT",
        sessionId,
        timestamp,
      };
      this.sendTo(session.macSocket, msg);
      this.sendTo(session.androidSocket, msg);
    } else {
      const msg: PairingCancelled = {
        type: "PAIRING_CANCELLED",
        sessionId,
        timestamp,
        reason,
      };
      this.sendTo(session.macSocket, msg);
      this.sendTo(session.androidSocket, msg);
    }

    // Clear socket references
    session.macSocket = null;
    session.androidSocket = null;

    this.sessions.delete(sessionId);
    this.log.info(`PairingSession destroyed (${reason}): ${sessionId}`);
  }

  /**
   * Called when a WebSocket disconnects. Finds all sessions that include
   * this socket and destroys them symmetrically.
   */
  handleDisconnect(socket: WebSocket): void {
    for (const [sessionId, session] of this.sessions) {
      if (
        session.macSocket === socket ||
        session.androidSocket === socket
      ) {
        const side = session.macSocket === socket ? "mac" : "android";
        this.destroySession(sessionId, `${side}_disconnected`);
      }
    }
  }

  /** Stops the background sweep timer. Call during server shutdown. */
  shutdown(): void {
    clearInterval(this.sweepTimer);
    this.log.info("PairingSessionManager shut down");
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  /**
   * Periodic sweep: expire sessions past their TTL or past the handshake
   * grace window.
   */
  private sweep(): void {
    const now = Date.now();
    for (const [sessionId, session] of this.sessions) {
      if (session.state === "DESTROYED") {
        this.sessions.delete(sessionId);
        continue;
      }

      if (
        session.state === "HANDSHAKE_COMPLETE" &&
        session.handshakeCompleteAt !== undefined &&
        now > session.handshakeCompleteAt + HANDSHAKE_GRACE_MS
      ) {
        // Grace window elapsed — clean up silently (handshake already succeeded)
        session.state = "DESTROYED";
        this.sessions.delete(sessionId);
        this.log.info(
          `PairingSession grace window elapsed, cleaned up: ${sessionId}`,
        );
        continue;
      }

      if (session.state !== "HANDSHAKE_COMPLETE" && now > session.expiresAt) {
        this.destroySession(sessionId, "expired");
      }
    }
  }

  /** Sends a serialized pairing message to a socket. No-op if socket is null. */
  private sendTo(
    socket: WebSocket | null,
    msg: Parameters<typeof serializePairingMessage>[0],
  ): void {
    if (!socket) return;
    try {
      socket.send(serializePairingMessage(msg));
    } catch {
      // Socket may already be closed — suppress
    }
  }
}
