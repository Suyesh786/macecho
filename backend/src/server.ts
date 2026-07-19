/**
 * server.ts — Phase 3
 *
 * Thin orchestrator. Responsibilities in this file:
 *   1. Import config from config/
 *   2. Import logger options from logging/
 *   3. Create the Fastify instance
 *   4. Register routes (health-check only in Phase 3)
 *   5. Start the server
 *   6. Handle startup errors and graceful shutdown signals
 *
 * What does NOT belong here:
 *   • Configuration logic  → config/index.ts
 *   • Logging setup        → logging/index.ts
 *   • WebSocket transport  → Phase 7 (transport/)
 *   • Authentication       → Phase 13
 *   • Relay logic          → Phase 14
 *   • Cryptography         → Phase 8
 *   • Protocol handling    → Phase 10
 */

import Fastify from "fastify";
import { config } from "./config/index.js";
import { buildLoggerOptions } from "./logging/index.js";

// ---------------------------------------------------------------------------
// Create Fastify instance
// All logger configuration is delegated to the logging module.
// ---------------------------------------------------------------------------

const app = Fastify({
  logger: buildLoggerOptions(config.logLevel),
});

// ---------------------------------------------------------------------------
// Routes — Phase 3: health-check only
// No business logic. Confirms the process is running and accepting requests.
// ---------------------------------------------------------------------------

app.get("/health", async (_request, _reply) => {
  return { status: "ok", service: "macecho-backend" };
});

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

async function start(): Promise<void> {
  try {
    await app.listen({ host: config.host, port: config.port });
  } catch (err) {
    app.log.error({ err }, "Server failed to start");
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// Graceful shutdown
// Ensures Fastify closes connections cleanly on SIGTERM / SIGINT.
// ---------------------------------------------------------------------------

async function shutdown(signal: string): Promise<void> {
  app.log.info({ signal }, "Shutdown signal received — closing server");
  try {
    await app.close();
    app.log.info("Server closed successfully");
    process.exit(0);
  } catch (err) {
    app.log.error({ err }, "Error during shutdown");
    process.exit(1);
  }
}

process.once("SIGTERM", () => void shutdown("SIGTERM"));
process.once("SIGINT", () => void shutdown("SIGINT"));

await start();
