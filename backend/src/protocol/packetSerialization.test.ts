
/**
 * packetValidation.test.ts — Phase 10 unit tests
 *
 * Backend structural-validation-only tests. Covers valid packets, malformed
 * JSON, missing required fields, invalid packet types, and confirms every
 * stage beyond structural validation is reported "deferred" — and, for the
 * backend, permanently out of scope — never "passed".
 */

import { randomUUID } from "crypto";
import { serializePacket, deserializePacket, PacketSerializationError } from "./packetSerialization.js";
import {
  validatePacketStructure,
  PACKET_VALIDATION_STAGE_ORDER,
} from "./packetvalidation.js";
import type { Packet } from "./packets.js";

function samplePacket(overrides: Partial<{
  protocolVersion: number;
  sessionId: string;
  senderId: string;
  packetId: string;
}> = {}): Packet {
  return {
    header: {
      protocolVersion: overrides.protocolVersion ?? 1,
      packetType: "HEARTBEAT",
      sessionId: overrides.sessionId ?? randomUUID(),
      senderId: overrides.senderId ?? "device-abc",
      packetId: overrides.packetId ?? randomUUID(),
      sequenceNumber: 1,
      timestamp: 1_700_000_000_000,
    },
    metadata: {
      retryCount: 0,
      priority: "NORMAL",
      messageCategory: "HEARTBEAT",
    },
    encryptedPayload: new Uint8Array([1, 2, 3]),
  };
}

describe("packetSerialization", () => {
  test("valid packet round-trips", () => {
    const packet = samplePacket();
    const json = serializePacket(packet);
    const decoded = deserializePacket(json);
    expect(decoded.header.packetId).toBe(packet.header.packetId);
    expect(decoded.header.senderId).toBe(packet.header.senderId);
    expect(Array.from(decoded.encryptedPayload)).toEqual(Array.from(packet.encryptedPayload));
  });

  test("malformed JSON throws", () => {
    expect(() => deserializePacket("{ this is not valid json")).toThrow(PacketSerializationError);
  });

  test("missing header field throws", () => {
    const json = JSON.stringify({
      metadata: { retryCount: 0, priority: "NORMAL", messageCategory: "HEARTBEAT" },
      encryptedPayload: "AQID",
    });
    expect(() => deserializePacket(json)).toThrow(PacketSerializationError);
  });

  test("missing encryptedPayload field throws", () => {
    const json = JSON.stringify({
      header: {
        protocolVersion: 1, packetType: "HEARTBEAT", sessionId: randomUUID(),
        senderId: "d1", packetId: randomUUID(), sequenceNumber: 1, timestamp: 1,
      },
      metadata: { retryCount: 0, priority: "NORMAL", messageCategory: "HEARTBEAT" },
    });
    expect(() => deserializePacket(json)).toThrow(PacketSerializationError);
  });

  test("invalid packet type throws", () => {
    const json = JSON.stringify({
      header: {
        protocolVersion: 1, packetType: "NOT_A_REAL_TYPE", sessionId: randomUUID(),
        senderId: "d1", packetId: randomUUID(), sequenceNumber: 1, timestamp: 1,
      },
      metadata: { retryCount: 0, priority: "NORMAL", messageCategory: "HEARTBEAT" },
      encryptedPayload: "AQID",
    });
    expect(() => deserializePacket(json)).toThrow(PacketSerializationError);
  });
});

describe("packetValidation (backend, structural only)", () => {
  test("stage order matches documentation exactly", () => {
    expect(PACKET_VALIDATION_STAGE_ORDER).toEqual([
      "PROTOCOL_VERSION",
      "PACKET_STRUCTURE",
      "SENDER_IDENTITY",
      "AUTHENTICATION_STATE",
      "SIGNATURE_VERIFICATION",
      "INTEGRITY_VERIFICATION",
      "FRESHNESS_VALIDATION",
      "DUPLICATE_DETECTION",
      "PAYLOAD_DECRYPTION",
      "COMMAND_EXECUTION",
    ]);
  });

  test("unsupported protocol version fails stage 1", () => {
    const packet = samplePacket({ protocolVersion: 999 });
    const report = validatePacketStructure(packet);
    expect(report.results.PROTOCOL_VERSION.status).toBe("failed");
    expect(report.passedBackendPermittedStages).toBe(false);
  });

  test("malformed packetId fails stage 2", () => {
    const packet = samplePacket({ packetId: "not-a-uuid" });
    const report = validatePacketStructure(packet);
    expect(report.results.PACKET_STRUCTURE.status).toBe("failed");
  });

  test("empty sessionId fails stage 2 as missing required field", () => {
    const packet = samplePacket({ sessionId: "" });
    const report = validatePacketStructure(packet);
    const result = report.results.PACKET_STRUCTURE;
    expect(result.status).toBe("failed");
    if (result.status === "failed" && result.reason.kind === "missingRequiredField") {
      expect(result.reason.fieldName).toBe("header.sessionId");
    } else {
      throw new Error("Expected missingRequiredField failure");
    }
  });

  test("valid packet passes backend-permitted stages", () => {
    const packet = samplePacket();
    const report = validatePacketStructure(packet);
    expect(report.passedBackendPermittedStages).toBe(true);
  });

  test("stages 3-10 are always deferred, never passed, for the backend", () => {
    const packet = samplePacket();
    const report = validatePacketStructure(packet);
    const outOfScopeStages = [
      "SENDER_IDENTITY", "AUTHENTICATION_STATE", "SIGNATURE_VERIFICATION",
      "INTEGRITY_VERIFICATION", "FRESHNESS_VALIDATION", "DUPLICATE_DETECTION",
      "PAYLOAD_DECRYPTION", "COMMAND_EXECUTION",
    ] as const;
    for (const stage of outOfScopeStages) {
      expect(report.results[stage].status).toBe("deferred");
    }
  });
});