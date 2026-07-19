/**
 * Logging module — Phase 3
 *
 * Creates and exports a configured Pino logger instance (Pino is bundled
 * with Fastify; no additional dependency is required).
 *
 * Security Logging rules (04_SECURITY_MODEL.md §Security Logging):
 *
 *   Logs must NEVER contain:
 *     • Notification contents
 *     • Reply contents
 *     • Private keys
 *     • Session secrets
 *     • Encrypted payloads
 *
 * This module enforces those rules by construction:
 *
 *   1. Request serializer — logs only safe metadata (method, url, hostname,
 *      remoteAddress). The body and headers are never serialized.
 *
 *   2. Response serializer — logs only statusCode. The response payload is
 *      never serialized.
 *
 *   3. REDACTED_PATHS — a named, visible constant listing every field path
 *      that Pino's `redact` option will replace with "[Redacted]". This list
 *      makes the security intent explicit and serves as a checklist for future
 *      contributors when adding new log statements.
 *
 * Design note: accidental sensitive logging is made structurally difficult
 * because the logger itself never serializes request/response bodies by
 * default. A developer would have to explicitly bypass the serializers to
 * log sensitive data, which is a conscious action rather than an accident.
 */

import type { FastifyBaseLogger } from "fastify";
import type { LogLevel } from "../config/index.js";

// ---------------------------------------------------------------------------
// Redacted paths
// Pino replaces the value at each path with "[Redacted]" in log output.
// This list is intentionally visible so future contributors know what is
// protected and can extend it when new sensitive fields are introduced.
// ---------------------------------------------------------------------------

const REDACTED_PATHS: string[] = [
  // HTTP request fields that must never appear in logs
  "req.body",
  "req.headers.authorization",
  "req.headers.cookie",
  // HTTP response fields that must never appear in logs
  "res.payload",
  // Generic field names that could carry sensitive payload data
  "*.payload",
  "*.secret",
  "*.privateKey",
  "*.sessionSecret",
  "*.encryptedPayload",
  "*.notificationContent",
  "*.replyContent",
];

// ---------------------------------------------------------------------------
// Serializers
// Only safe, structural metadata is emitted. Bodies are never included.
// ---------------------------------------------------------------------------

interface RequestSnapshot {
  // Index signature required by Pino's serializer type contract
  [key: string]: unknown;
  method: string;
  url: string;
  hostname: string;
  remoteAddress: string | undefined;
}

interface ResponseSnapshot {
  // Index signature required by Pino's serializer type contract
  [key: string]: unknown;
  statusCode: number;
}

const serializers = {
  req(req: {
    method: string;
    url: string;
    hostname: string;
    socket?: { remoteAddress?: string };
  }): RequestSnapshot {
    return {
      method: req.method,
      url: req.url,
      hostname: req.hostname,
      remoteAddress: req.socket?.remoteAddress,
    };
  },

  res(res: { statusCode: number }): ResponseSnapshot {
    return {
      statusCode: res.statusCode,
    };
  },
};

// ---------------------------------------------------------------------------
// Logger options factory
// Returns the Pino options object to be passed to the Fastify constructor.
// Keeping this as a function (rather than a plain object) makes it easy to
// inject test-specific overrides in future phases without modifying this file.
// ---------------------------------------------------------------------------

export interface LoggerOptions {
  level: LogLevel;
  redact: string[];
  serializers: typeof serializers;
}

export function buildLoggerOptions(level: LogLevel): LoggerOptions {
  return {
    level,
    redact: REDACTED_PATHS,
    serializers,
  };
}

// Re-export the type alias so server.ts does not need to import from Fastify
// directly just to annotate the logger.
export type { FastifyBaseLogger as AppLogger };
