package com.macecho.app.protocol

/**
 * PacketSerialization.kt — Phase 10
 *
 * JSON serialization / deserialization for the protocol packet types defined
 * in Packets.kt (Phase 6), per Architecture Decision 17 ("All protocol
 * packets are serialized using JSON") and 07_PROTOCOL_SPECIFICATION.md
 * §Serialization Philosophy / §Universal Packet Structure.
 *
 * This file ONLY converts between [Packet] and JSON text. It contains NO
 * validation logic (see PacketValidator.kt) and NO cryptographic operations
 * (Phase 8, unchanged).
 *
 * Implementation note: uses `org.json` (bundled with the Android platform)
 * rather than adding a kotlinx.serialization dependency, since no
 * serialization library is mandated by the documentation and Phase 10's
 * scope is limited to what previous phases already provide.
 *
 * Wire format: camelCase JSON keys matching the Kotlin property names in
 * Packets.kt. No field-name casing convention is mandated by the
 * documentation, so the existing property names are used directly to
 * avoid introducing an undocumented convention.
 *
 * Must NOT contain:
 *   - Packet validation             → PacketValidator.kt (this phase)
 *   - Cryptographic operations      → Phase 8 (CryptoManager.kt)
 *   - Transport / WebSocket wiring  → Phase 7 / later phases
 *   - Business logic of any kind
 */

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.Base64

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/**
 * Errors surfaced by JSON serialization / deserialization. Distinct from
 * [PacketValidationException] (PacketValidator.kt): this covers only
 * "is this valid JSON that decodes into a Packet shape," per
 * 07_PROTOCOL_SPECIFICATION.md §Packet Validation Pipeline step 2
 * ("Validate packet structure").
 */
sealed class PacketSerializationException(message: String, cause: Throwable? = null) :
    Exception(message, cause) {
    class EncodingFailed(cause: Throwable) :
        PacketSerializationException("Packet JSON encoding failed: ${cause.message}", cause)

    class DecodingFailed(message: String, cause: Throwable? = null) :
        PacketSerializationException("Packet JSON decoding failed: $message", cause)
}

// ---------------------------------------------------------------------------
// Enum <-> wire string maps
// ---------------------------------------------------------------------------

private fun platformToWire(p: Platform): String = p.name // ANDROID / MACOS already match wire form
private fun platformFromWire(s: String): Platform =
    Platform.values().firstOrNull { it.name == s }
        ?: throw PacketSerializationException.DecodingFailed("Unknown platform '$s'")

private fun packetTypeToWire(t: PacketType): String = t.name
private fun packetTypeFromWire(s: String): PacketType =
    PacketType.values().firstOrNull { it.name == s }
        ?: throw PacketSerializationException.DecodingFailed("Unknown packetType '$s'")

private fun priorityToWire(p: PacketPriority): String = p.name
private fun priorityFromWire(s: String): PacketPriority =
    PacketPriority.values().firstOrNull { it.name == s }
        ?: throw PacketSerializationException.DecodingFailed("Unknown priority '$s'")

// ---------------------------------------------------------------------------
// PacketSerializer
// ---------------------------------------------------------------------------

/**
 * Stateless JSON serialization helpers for [Packet].
 */
object PacketSerializer {

    /** Serializes a [Packet] to a JSON string. */
    fun serialize(packet: Packet): String {
        try {
            val header = JSONObject().apply {
                put("protocolVersion", packet.header.protocolVersion)
                put("packetType", packetTypeToWire(packet.header.packetType))
                put("sessionId", packet.header.sessionId)
                put("senderId", packet.header.senderId)
                put("packetId", packet.header.packetId)
                put("sequenceNumber", packet.header.sequenceNumber)
                put("timestamp", packet.header.timestamp)
            }
            val metadata = JSONObject().apply {
                put("retryCount", packet.metadata.retryCount)
                put("priority", priorityToWire(packet.metadata.priority))
                put("messageCategory", packetTypeToWire(packet.metadata.messageCategory))
            }
            val root = JSONObject().apply {
                put("header", header)
                put("metadata", metadata)
                put("encryptedPayload", Base64.getEncoder().encodeToString(packet.encryptedPayload))
            }
            return root.toString()
        } catch (e: JSONException) {
            throw PacketSerializationException.EncodingFailed(e)
        }
    }

    /**
     * Deserializes a JSON string into a [Packet].
     *
     * Performs *structural* decoding only (JSON correctness + required
     * fields present with the correct shape). Performs no semantic
     * validation — see [PacketValidator.validate] for the full documented
     * pipeline.
     *
     * @throws PacketSerializationException.DecodingFailed if the JSON is
     *   malformed or a required field is missing / mistyped.
     */
    fun deserialize(json: String): Packet {
        val root: JSONObject
        try {
            root = JSONObject(json)
        } catch (e: JSONException) {
            throw PacketSerializationException.DecodingFailed("Malformed JSON", e)
        }

        val headerObj = root.optJSONObject("header")
            ?: throw PacketSerializationException.DecodingFailed("Missing required field 'header'")
        val metadataObj = root.optJSONObject("metadata")
            ?: throw PacketSerializationException.DecodingFailed("Missing required field 'metadata'")
        val payloadB64 = if (root.has("encryptedPayload")) root.getString("encryptedPayload") else null
            ?: throw PacketSerializationException.DecodingFailed("Missing required field 'encryptedPayload'")

        try {
            val header = PacketHeader(
                protocolVersion = requireInt(headerObj, "protocolVersion"),
                packetType = packetTypeFromWire(requireString(headerObj, "packetType")),
                sessionId = requireString(headerObj, "sessionId"),
                senderId = requireString(headerObj, "senderId"),
                packetId = requireString(headerObj, "packetId"),
                sequenceNumber = requireLong(headerObj, "sequenceNumber"),
                timestamp = requireLong(headerObj, "timestamp"),
            )
            val metadata = PacketMetadata(
                retryCount = requireInt(metadataObj, "retryCount"),
                priority = priorityFromWire(requireString(metadataObj, "priority")),
                messageCategory = packetTypeFromWire(requireString(metadataObj, "messageCategory")),
            )
            val payloadBytes = try {
                Base64.getDecoder().decode(payloadB64)
            } catch (e: IllegalArgumentException) {
                throw PacketSerializationException.DecodingFailed("encryptedPayload is not valid base64", e)
            }
            return Packet(header = header, metadata = metadata, encryptedPayload = payloadBytes)
        } catch (e: JSONException) {
            throw PacketSerializationException.DecodingFailed(e.message ?: "malformed field", e)
        }
    }

    // -------------------------------------------------------------------
    // Required-field helpers — surface a clear DecodingFailed rather than
    // org.json's generic JSONException when a field is missing/mistyped.
    // -------------------------------------------------------------------

    private fun requireString(obj: JSONObject, key: String): String {
        if (!obj.has(key)) throw PacketSerializationException.DecodingFailed("Missing required field '$key'")
        return obj.getString(key)
    }

    private fun requireInt(obj: JSONObject, key: String): Int {
        if (!obj.has(key)) throw PacketSerializationException.DecodingFailed("Missing required field '$key'")
        return obj.getInt(key)
    }

    private fun requireLong(obj: JSONObject, key: String): Long {
        if (!obj.has(key)) throw PacketSerializationException.DecodingFailed("Missing required field '$key'")
        return obj.getLong(key)
    }
}