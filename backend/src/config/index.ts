/**
 * Configuration module — Phase 3
 *
 * Single source of truth for all process-level configuration.
 * Reads environment variables, validates them, and exports a frozen
 * typed Config object. No other module should access process.env directly.
 *
 * Phase 3 includes only the configuration needed for the backend foundation:
 * host, port, runtime environment, and log level.
 *
 * Future phases may add fields here (e.g. rate-limit thresholds, relay
 * settings) without touching server.ts or any other module.
 */

export type NodeEnv = "development" | "production" | "test";
export type LogLevel =
  | "trace"
  | "debug"
  | "info"
  | "warn"
  | "error"
  | "fatal";

export interface Config {
  /** Network host the server binds to. */
  readonly host: string;
  /** TCP port the server listens on. */
  readonly port: number;
  /** Runtime environment. */
  readonly nodeEnv: NodeEnv;
  /** Minimum log level emitted by the structured logger. */
  readonly logLevel: LogLevel;
}

// ---------------------------------------------------------------------------
// Validators
// ---------------------------------------------------------------------------

const VALID_NODE_ENVS: NodeEnv[] = ["development", "production", "test"];
const VALID_LOG_LEVELS: LogLevel[] = [
  "trace",
  "debug",
  "info",
  "warn",
  "error",
  "fatal",
];

function parsePort(raw: string | undefined): number {
  const defaultPort = 3000;
  if (raw === undefined || raw.trim() === "") return defaultPort;
  const parsed = parseInt(raw, 10);
  if (isNaN(parsed) || parsed < 1 || parsed > 65535) {
    throw new Error(
      `Invalid PORT value "${raw}". Must be an integer between 1 and 65535.`,
    );
  }
  return parsed;
}

function parseNodeEnv(raw: string | undefined): NodeEnv {
  const defaultEnv: NodeEnv = "development";
  if (raw === undefined || raw.trim() === "") return defaultEnv;
  if ((VALID_NODE_ENVS as string[]).includes(raw)) return raw as NodeEnv;
  throw new Error(
    `Invalid NODE_ENV value "${raw}". Must be one of: ${VALID_NODE_ENVS.join(", ")}.`,
  );
}

function parseLogLevel(raw: string | undefined): LogLevel {
  const defaultLevel: LogLevel = "info";
  if (raw === undefined || raw.trim() === "") return defaultLevel;
  if ((VALID_LOG_LEVELS as string[]).includes(raw)) return raw as LogLevel;
  throw new Error(
    `Invalid LOG_LEVEL value "${raw}". Must be one of: ${VALID_LOG_LEVELS.join(", ")}.`,
  );
}

// ---------------------------------------------------------------------------
// Build and freeze the config object at module load time.
// ---------------------------------------------------------------------------

function buildConfig(): Config {
  return Object.freeze({
    host: process.env["HOST"] ?? "0.0.0.0",
    port: parsePort(process.env["PORT"]),
    nodeEnv: parseNodeEnv(process.env["NODE_ENV"]),
    logLevel: parseLogLevel(process.env["LOG_LEVEL"]),
  });
}

export const config: Config = buildConfig();
