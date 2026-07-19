---
Document: Protocol Specification
Version: 1.0
Status: Draft
Last Updated: YYYY-MM-DD
Owner: MacEcho Team
Review Required: Yes
---

# Protocol Specification

# Purpose

The Protocol Specification defines the communication language used throughout the MacEcho platform.

It establishes how Android, macOS, and the backend exchange information in a secure, reliable, predictable, and extensible manner.

Rather than describing implementation code, this document specifies the logical communication rules that every component must follow.

Every packet, command, acknowledgement, authentication request, and synchronization event exchanged within MacEcho must comply with this specification.

This document acts as the single source of truth for all communication behavior across the platform.

---

# Scope

This document defines:

• Communication architecture

• Protocol philosophy

• Layered communication model

• Connection lifecycle

• Session lifecycle

• Packet lifecycle

• Message categories

• Version management

• Transport responsibilities

• Reliability rules

• Extensibility principles

Implementation-specific networking libraries, serialization formats, cryptographic algorithms, backend deployment, and operating system APIs are intentionally excluded.

Those topics are documented in their respective specifications.

---

# Protocol Philosophy

The MacEcho protocol is designed around five principles.

Reliability.

Security.

Predictability.

Extensibility.

Simplicity.

Every communication rule exists to satisfy at least one of these principles.

The protocol intentionally avoids unnecessary complexity while remaining sufficiently flexible for future versions.

---

# Design Goals

The protocol has several primary goals.

• Minimize communication overhead.

• Remain secure on untrusted networks.

• Be platform independent.

• Support future expansion without breaking compatibility.

• Provide deterministic communication.

• Recover safely after failures.

• Prevent duplicate execution.

• Preserve user privacy.

---

# High-Level Communication Architecture

MacEcho uses a relay-based communication architecture.

Android

↓

Encrypted Protocol Packet

↓

Backend Relay

↓

Encrypted Protocol Packet

↓

macOS

The backend acts only as a transport mechanism.

The backend never interprets application commands.

The backend never modifies packets.

The backend never generates protocol commands.

---

# Communication Responsibilities

Android is responsible for:

• Creating protocol packets.

• Encrypting payloads.

• Authenticating sessions.

• Processing received commands.

• Sending acknowledgements.

---

macOS is responsible for:

• Receiving protocol packets.

• Verifying packet authenticity.

• Executing protocol commands.

• Returning acknowledgements.

• Maintaining communication sessions.

---

Backend responsibilities include:

• Forwarding packets.

• Maintaining active realtime connections.

• Supporting temporary pairing sessions.

• Delivering encrypted data.

No protocol logic should permanently reside within the backend.

---

# Layered Protocol Model

The protocol is divided into logical layers.

Application Layer

↓

Command Layer

↓

Session Layer

↓

Authentication Layer

↓

Transport Layer

Each layer has a single responsibility.

No layer should bypass another.

---

# Transport Layer

The Transport Layer is responsible only for delivering packets between endpoints.

It does not understand packet meaning.

It does not understand encryption.

It does not understand notifications.

It treats every packet as opaque data.

The Transport Layer is implemented using a persistent WebSocket connection between each client and the backend relay.

The WebSocket connection provides:

• Bidirectional communication.

• A Ping/Pong heartbeat mechanism.

• Automatic reconnection.

• Session recovery.

Encrypted packets are transmitted as messages over this WebSocket connection.

---

# Authentication Layer

The Authentication Layer verifies identity.

Responsibilities include:

• Session authentication.

• Identity verification.

• Trust validation.

• Authentication state.

No application commands may execute until authentication succeeds.

---

# Session Layer

The Session Layer manages communication sessions.

Responsibilities include:

• Session creation.

• Session termination.

• Session timeout.

• Session recovery.

• Re-authentication.

The Session Layer never interprets application data.

---

# Command Layer

The Command Layer interprets protocol commands.

Examples include:

Notification delivery.

Notification reply.

Ring phone.

Incoming call.

Status synchronization.

Future commands.

Only authenticated sessions may execute commands.

---

# Application Layer

The Application Layer interacts with operating system functionality.

Examples include:

Displaying notifications.

Showing call interfaces.

Sending notification replies.

Updating connection status.

The Application Layer never communicates directly with the transport layer.

---

# Protocol Versioning

Every protocol packet belongs to a protocol version.

Version numbers allow future protocol improvements without breaking compatibility.

Every packet must identify the protocol version used to generate it.

Devices using incompatible protocol versions must reject communication safely.

---

# Version Compatibility

Version compatibility follows these rules.

Compatible versions communicate normally.

Older versions gracefully reject unsupported functionality.

Unknown future versions never execute commands they do not understand.

Protocol evolution must remain backward compatible whenever practical.

Breaking protocol changes require a new major protocol version.

---

# Communication Lifecycle

Every communication session follows the same lifecycle.

Connection Requested

↓

Connection Established

↓

Authentication

↓

Trust Validation

↓

Session Created

↓

Command Exchange

↓

Acknowledgements

↓

Session Closed

Each stage must complete successfully before progressing to the next stage.

---

# Session Philosophy

A communication session represents a temporary authenticated conversation between paired devices.

Sessions are intentionally temporary.

Trust remains permanent until unpaired.

Sessions do not.

Every new session begins from an unauthenticated state.

Authentication must occur every time.

Pairing itself is persistent and remains valid until manually revoked.

A QR code is required only for:

• Initial pairing.

• Manual unpair followed by re-pairing.

• Security reset.

Reconnection and re-authentication after normal disconnection never require a new QR code.

---

# Connection Types

Version 1 defines several logical connection categories.

Pairing Session

Authentication Session

Communication Session

Recovery Session

Future protocol versions may introduce additional connection categories while preserving existing behavior.

---

# Communication States

Every active session exists in exactly one communication state.

Disconnected

Connecting

Authenticating

Authenticated

Synchronizing

Idle

Recovering

Closing

Closed

Transitions between states must always follow valid protocol rules.

Skipping states is prohibited.

---

# State Transition Rules

Every communication state has clearly defined transitions.

For example:

Disconnected

↓

Connecting

↓

Authenticating

↓

Authenticated

↓

Idle

↓

Closing

↓

Closed

Unexpected transitions must terminate the session safely.

---

# Communication Guarantees

The protocol guarantees:

• Commands originate from authenticated devices.

• Duplicate execution is prevented.

• Packet integrity is verified.

• Trust is continuously validated.

• Communication remains deterministic.

The protocol intentionally does not guarantee immediate delivery under unreliable network conditions.

Instead, it guarantees safe behavior regardless of delivery timing.

---

# Reliability Philosophy

Reliable communication does not require every packet to arrive immediately.

Reliable communication means:

Packets are either:

Successfully processed

or

Safely rejected.

There should never exist uncertainty regarding command execution.

---

# Protocol Boundaries

The protocol intentionally separates responsibilities.

The protocol defines communication.

The security model defines trust.

The system architecture defines components.

The UI defines presentation.

The protocol should never duplicate responsibilities already defined elsewhere.

---

# Future Extensibility

The protocol is intentionally designed to evolve.

Future protocol versions may introduce:

• Clipboard synchronization.

• File transfer.

• Multi-device support.

• Battery synchronization.

• Device groups.

• Camera integration.

• AI-assisted commands.

These additions must integrate into the existing protocol without redesigning its foundation.

---

# Pairing Protocol

The pairing protocol defines the process through which two previously unknown devices establish a trusted relationship.

Pairing is the only protocol capable of creating trust.

All subsequent communication assumes that pairing has already completed successfully.

Pairing must never occur automatically.

Pairing always requires explicit user participation.

---

# Pairing Protocol Objectives

The pairing protocol is responsible for:

• Discovering the peer device.

• Verifying user intent.

• Exchanging cryptographic identities.

• Establishing mutual trust.

• Creating the first authenticated session.

• Persisting trust locally.

The pairing protocol is intentionally isolated from all normal communication sessions.

---

# Pairing Preconditions

Before pairing begins, the following conditions must be satisfied.

Android:

• Application installed.

• Initial setup completed.

• Required permissions granted.

• Internet connectivity available.

macOS:

• Application running.

• QR generation available.

• Internet connectivity available.

Backend:

• Pairing relay available.

If any prerequisite fails, pairing must not begin.

---

# Pairing Session

A pairing session is a temporary communication channel existing only during the pairing process.

Its responsibilities are limited to:

• Device discovery.

• Public key exchange.

• Identity verification.

• Pairing confirmation.

It must never transport application commands.

Once pairing completes or fails, the session is destroyed.

---

# Pairing Session Lifecycle

Every pairing session follows the same lifecycle.

Generate Pairing Session

↓

Generate QR Code

↓

Android Scans QR

↓

Backend Relay Connection

↓

Identity Exchange

↓

Public Key Exchange

↓

Mutual Verification

↓

Trust Creation

↓

Pairing Confirmation

↓

Session Destruction

Each stage must complete successfully before the next stage begins.

---

# QR Bootstrap

The QR code functions only as a bootstrap mechanism.

It allows Android to discover the pairing session initiated by macOS.

The QR code does not contain trust.

The QR code does not authenticate devices.

The QR code does not permanently identify either device.

Its only purpose is to initiate the pairing protocol.

---

# QR Contents

The QR code should contain only the minimum information required to bootstrap pairing.

Typical contents include:

• Temporary pairing session identifier.

• Protocol version.

• Backend routing information.

• Session expiration information.

The QR code must never contain:

• Private keys.

• Long-term authentication secrets.

• Permanent trust information.

• User notification data.

---

# QR Expiration

Each QR code has a limited lifetime.

After expiration:

• The QR code becomes invalid.

• Pairing requests are rejected.

• A new QR code must be generated.

Only one valid pairing QR may exist at any time.

Generating a new QR invalidates every previous unused QR.

---

# Pairing Discovery

After scanning the QR code, Android establishes communication with the backend using the temporary pairing session information.

The backend simply introduces the two devices.

The backend never establishes trust.

---

# Identity Exchange

Once communication begins, both devices exchange identity information.

Identity exchange includes:

• Device identifier.

• Device type.

• Device name.

• Public key.

Identity exchange alone does not establish trust.

---

# Identity Verification

Each device validates the received identity.

Verification confirms:

• Identity format is valid.

• Protocol version is supported.

• Public key is usable.

• Device information is internally consistent.

Invalid identities immediately terminate pairing.

---

# Public Key Exchange

Public keys are exchanged during pairing.

Each device permanently stores the verified public key of its peer.

Future authentication depends entirely upon these stored public keys.

Private keys remain inside secure storage and are never transmitted.

---

# Mutual Verification

Pairing requires mutual verification.

Android verifies macOS.

macOS verifies Android.

Both verifications must succeed.

Trust cannot exist if verification succeeds in only one direction.

---

# Trust Creation

After successful verification:

Each device creates a local trust record.

The trust record contains:

• Trusted Device Identifier.

• Trusted Public Key.

• Pairing Timestamp.

• Device Metadata.

No backend participation exists in this step.

Trust is created independently by each device.

---

# Pairing Confirmation

After trust has been created locally, both devices exchange pairing confirmation messages.

Only after both confirmations are received is pairing considered complete.

This prevents one-sided pairing states.

---

# Pairing Failure

Pairing immediately fails if:

• QR expires.

• Authentication fails.

• Identity verification fails.

• Public key verification fails.

• Backend relay unavailable.

• Network disconnects.

• User cancels pairing.

Failure destroys the temporary pairing session.

No trust information remains.

---

# Authentication Handshake

Every communication session begins with an authentication handshake.

Authentication is mandatory.

Skipping authentication is prohibited.

Authentication proves that the communicating peer still possesses the trusted cryptographic identity established during pairing.

---

# Handshake Objectives

The authentication handshake verifies:

• Peer identity.

• Ownership of the private key.

• Protocol compatibility.

• Trust continuity.

Only after successful authentication does application communication begin.

---

# Handshake Lifecycle

Every authentication follows the same sequence.

Session Created

↓

Authentication Request

↓

Authentication Response

↓

Identity Verification

↓

Signature Verification

↓

Trust Validation

↓

Authentication Success

↓

Application Communication Enabled

Any failure terminates the session immediately.

---

# Trust Validation

Authentication alone is insufficient.

Each device must also validate:

• Stored public key.

• Trusted device identifier.

• Trust record integrity.

• Pairing state.

If trust validation fails, the session is terminated regardless of successful authentication.

---

# Session Establishment

Only authenticated trusted devices may establish a communication session.

Session establishment includes:

• Creating temporary session state.

• Preparing command processing.

• Initial synchronization.

• Enabling command exchange.

No application commands may execute before session establishment completes.

---

# Session Recovery

If communication is interrupted unexpectedly:

• Session state is discarded.

• Partial commands are abandoned.

• Trust remains unchanged.

When connectivity returns, a completely new authentication handshake begins.

Sessions are never resumed without verification.

---

# Reconnection Protocol

Temporary disconnections are expected.

Examples include:

• Wi-Fi changes.

• Mobile network switching.

• Device sleep.

• Device restart.

• Backend restart.

Reconnection never assumes previous authentication remains valid.

Every reconnection behaves as a new session.

Reconnection is automatic and follows this timing:

• Initial reconnect delay: 1 second.

• Backoff strategy: exponential.

• Maximum reconnect delay: 30 seconds.

• Random jitter is applied to each reconnect attempt.

Reconnection does not require a new QR code, since it re-uses the existing persistent pairing.

---

# Reconnection Flow

Connection Restored

↓

Session Created

↓

Authentication

↓

Trust Validation

↓

Synchronization

↓

Command Processing

↓

Idle

This guarantees that stale session state is never reused.

---

# Session Termination

A session ends when:

• User unpairs.

• Application closes.

• Authentication fails.

• Trust validation fails.

• Connection lost.

• Session timeout.

Session termination destroys all temporary communication state.

Permanent trust information remains unchanged unless explicitly revoked.

---

# Session Guarantees

Every communication session guarantees:

• Authenticated identity.

• Verified trust.

• Fresh session state.

• Secure command exchange.

• Deterministic termination.

No session may inherit temporary state from a previous session.

---

# Pairing Protocol Review Checklist

Before modifying the pairing protocol, verify:

✓ Does it preserve mutual authentication?

✓ Does it prevent unauthorized pairing?

✓ Does it avoid backend trust?

✓ Does it maintain one-way trust creation?

✓ Does it preserve cryptographic identity?

✓ Does it destroy temporary pairing state?

✓ Does it prevent stale QR reuse?

✓ Does it remain compatible with future protocol versions?

Every modification to the pairing protocol must undergo both architectural and security review before implementation.

---

# Packet Architecture

Every piece of information exchanged within MacEcho is transmitted as a protocol packet.

A packet is the smallest complete unit of communication.

Regardless of its purpose, every packet follows the same high-level structure.

This guarantees consistency throughout the protocol and simplifies validation, debugging, extensibility, and future compatibility.

---

# Packet Design Principles

Every packet must satisfy the following principles:

• Self-identifying.

• Authenticated.

• Integrity protected.

• Version aware.

• Deterministically processable.

• Extensible.

Every received packet must contain enough information for the receiver to determine how it should be processed.

---

# Universal Packet Structure

Every protocol packet consists of three logical sections.

Packet Header

↓

Packet Metadata

↓

Encrypted Payload

The receiver processes packets in this order.

The payload must never be processed before successful validation of the preceding sections.

---

# Packet Header

The header contains protocol information required before decryption.

Typical header information includes:

• Protocol version.

• Packet type.

• Session identifier.

• Sender identifier.

• Packet identifier.

• Timestamp.

The header must never contain sensitive application data.

---

# Header Responsibilities

The packet header allows the receiver to determine:

• Whether the protocol version is supported.

• Whether the sender is known.

• Which session the packet belongs to.

• Which processing pipeline should handle the packet.

The header exists to enable safe packet routing before payload decryption.

---

# Packet Metadata

Packet metadata contains communication control information.

Examples include:

• Sequence number.

• Retry counter.

• Delivery flags.

• Priority information.

• Message category.

Metadata improves communication reliability while remaining independent of application commands.

---

# Encrypted Payload

The payload contains the actual application command.

Examples include:

• Notification information.

• Reply requests.

• Call events.

• Ring requests.

• Status updates.

The payload must always remain encrypted during transport.

Only the intended recipient may decrypt it.

The payload is protected using the cryptographic algorithms mandated by the Security Model:

• Key Exchange: X25519.

• Digital Signatures: Ed25519.

• Symmetric Encryption: AES-256-GCM.

• Key Derivation: HKDF-SHA256.

• Hash Algorithm: SHA-256.

---

# Packet Identity

Every packet possesses a globally unique packet identifier, represented as a Packet UUID.

The packet identifier exists for the lifetime of that packet.

Packet identifiers allow:

• Duplicate detection.

• Delivery tracking.

• Acknowledgements.

• Retry management.

Packet identifiers must never be reused.

The receiver rejects any packet whose UUID has already been processed.

The receiver maintains a temporary cache of processed Packet UUIDs for this purpose.

---

# Session Identifier

Every communication session receives a unique session identifier.

Every packet generated during that session references the same session identifier.

When the session ends:

The session identifier expires permanently.

Future sessions receive new identifiers.

---

# Sender Identity

Every packet identifies its sender.

Sender identity allows the receiver to:

• Locate the correct trust record.

• Verify authentication.

• Validate signatures.

Unknown sender identities are rejected immediately.

---

# Packet Timestamp

Each packet contains its creation timestamp.

Timestamps help:

• Freshness validation.

• Replay protection.

• Timeout evaluation.

Timestamp validation must tolerate reasonable clock differences between devices.

Packets received outside the allowed clock skew are rejected.

Every packet requiring replay protection carries all three of the following fields together:

• Packet UUID.

• Session Sequence Number.

• Timestamp.

The receiver rejects a packet if:

• Its Packet UUID has already been processed.

• Its Session Sequence Number is stale.

• Its Timestamp falls outside the allowed clock skew.

---

# Packet Categories

Version 1 defines several logical packet categories.

Authentication Packets

Pairing Packets

Application Command Packets

Acknowledgement Packets

Heartbeat Packets

Synchronization Packets

Error Packets

Future protocol versions may introduce additional packet categories.

---

# Packet Lifecycle

Every packet follows the same lifecycle.

Packet Created

↓

Packet Signed

↓

Packet Encrypted

↓

Packet Transmitted

↓

Packet Received

↓

Packet Validated

↓

Packet Decrypted

↓

Packet Executed

↓

Acknowledgement Generated

Every stage must complete successfully.

---

# Packet Validation Pipeline

Incoming packets are processed using a strict validation sequence.

1. Validate protocol version.

2. Validate packet structure.

3. Validate sender identity.

4. Validate authentication state.

5. Verify packet signature.

6. Verify packet integrity.

7. Validate packet freshness.

8. Detect duplicate packet.

9. Decrypt payload.

10. Execute command.

No implementation may change this processing order.

---

# Invalid Packet Handling

A packet is considered invalid if:

• Structure is malformed.

• Required fields are missing.

• Version unsupported.

• Authentication fails.

• Signature verification fails.

• Integrity verification fails.

• Decryption fails.

• Trust validation fails.

Invalid packets must never reach application logic.

---

# Packet Integrity

Integrity verification confirms that the packet has not been modified during transmission.

If integrity verification fails:

• Packet rejected.

• Command discarded.

• Optional security event logged.

No recovery attempts should process a corrupted packet.

---

# Packet Authenticity

Authenticity proves that the packet originated from the authenticated trusted device.

Authenticity verification occurs before payload processing.

Packets without valid authenticity must be discarded immediately.

---

# Payload Processing

Payload processing begins only after:

• Authentication succeeds.

• Trust validation succeeds.

• Packet validation succeeds.

• Integrity verification succeeds.

• Decryption succeeds.

Application logic must never process unverified data.

---

# Sequence Numbers

Every command packet includes a sequence number.

Sequence numbers help maintain communication order.

They also support:

• Duplicate detection.

• Ordering validation.

• Reliable synchronization.

Sequence numbers are scoped to an individual communication session.

The sequence number starts at 1 per session.

Every outgoing packet increments the sequence number.

---

# Packet Ordering

Packets should be processed in their intended logical order whenever ordering affects application behavior.

Examples include:

Notification created.

↓

Notification updated.

↓

Notification dismissed.

Executing these commands out of order may create inconsistent application state.

Ordering validation prevents this.

---

# Out-of-Order Packets

If packets arrive out of order:

The protocol determines whether:

• Processing may continue safely.

• Temporary buffering is required.

• The packet should be discarded.

Safety always takes priority over speed.

Out-of-order packets are buffered temporarily until the missing sequence numbers arrive or recovery rules apply.

Missing packets are handled according to the protocol's recovery rules, defined under Recovery Philosophy.

---

# Duplicate Detection

Network retries may deliver identical packets multiple times.

Every packet identifier is compared against previously processed packets.

Duplicate packets, identified by Packet UUID or stale Session Sequence Number, are ignored.

If a duplicate packet is detected:

• Packet ignored.

• Previous acknowledgement may be reused.

• Command not executed again.

Application commands must remain idempotent whenever practical.

---

# Acknowledgements

Successful packet processing generates an acknowledgement.

Acknowledgements confirm that:

• Packet received.

• Packet validated.

• Command processed successfully.

Acknowledgements never imply that future commands have succeeded.

Each acknowledgement applies only to the referenced packet.

---

# Positive Acknowledgement (ACK)

ACK indicates successful processing.

Conditions include:

• Packet received.

• Validation completed.

• Command executed.

The sender may safely remove the packet from its pending delivery queue.

---

# Negative Acknowledgement (NACK)

NACK indicates that processing failed.

Examples include:

• Validation failure.

• Unsupported command.

• Authentication failure.

• Temporary processing issue.

Receipt of a NACK does not automatically imply retry.

Retry decisions depend on failure type.

---

# Packet Retransmission

Packets awaiting acknowledgement may be retransmitted according to protocol retry rules.

Retransmitted packets retain:

• Packet identifier.

• Sequence number.

• Session identifier.

Creating a new packet identifier during retry is prohibited.

---

# Heartbeat Packets

Heartbeat packets maintain awareness that an authenticated session remains active.

Heartbeat packets contain no application commands.

Their responsibilities include:

• Connection health.

• Session liveness.

• Connectivity monitoring.

Failure to receive expected heartbeats eventually triggers session recovery procedures.

---

# Serialization Philosophy

The protocol intentionally separates logical packet structure from serialization format.

The specification defines:

"What information exists."

Implementation defines:

"How that information is encoded."

This allows future serialization improvements without changing protocol behavior.

For Version 1, all protocol packets are serialized using JSON.

---

# Packet Processing Rules

Every implementation must guarantee:

• One packet produces one deterministic outcome.

• Failed packets never partially execute.

• Successful packets execute exactly once.

• Duplicate packets never produce duplicate actions.

• Packet processing remains independent of transport implementation.

---

# Packet Review Checklist

Before introducing a new packet type, verify:

✓ Does it fit an existing packet category?

✓ Is a new packet type actually necessary?

✓ Can older protocol versions safely ignore it?

✓ Does it preserve packet validation order?

✓ Is acknowledgement behavior defined?

✓ Does it support duplicate detection?

✓ Does it remain compatible with authentication rules?

✓ Does it preserve end-to-end encryption?

Every new packet type must maintain compatibility with the core packet architecture defined in this specification.

---

# Protocol Commands

Protocol commands define the actions exchanged between authenticated devices.

Each command represents a single logical operation.

Commands must remain:

• Deterministic.

• Independent.

• Authenticated.

• Version compatible.

Every command belongs to a predefined command category.

Unknown commands must never be executed.

---

# Command Design Principles

Every protocol command must:

• Have one clearly defined purpose.

• Produce one predictable result.

• Be authenticated.

• Be encrypted.

• Support acknowledgement.

• Be safe to reject.

Commands must never depend upon undocumented behavior.

---

# Command Categories

Version 1 defines the following command categories.

• Pairing Commands

• Authentication Commands

• Session Commands

• Notification Commands

• Call Commands

• Device Commands

• Synchronization Commands

• Heartbeat Commands

• Error Commands

Future protocol versions may introduce additional categories without modifying existing behavior.

---

# Pairing Commands

Pairing commands exist only during the pairing protocol.

They are never used during normal communication.

Examples include:

• Pairing Request

• Pairing Response

• Identity Exchange

• Public Key Exchange

• Pairing Confirmation

• Pairing Cancellation

Once pairing completes successfully, these commands become invalid.

---

# Authentication Commands

Authentication commands establish a trusted communication session.

Examples include:

• Authentication Request

• Authentication Challenge

• Authentication Response

• Authentication Success

• Authentication Failure

Authentication commands execute before application commands.

---

# Session Commands

Session commands manage communication lifecycle.

Examples include:

• Session Start

• Session Ready

• Session Closing

• Session Closed

• Session Recovery

These commands coordinate communication without interacting with operating system functionality.

---

# Notification Commands

Notification commands synchronize notifications from Android to macOS.

Version 1 supports:

Notification Created

Notification Updated

Notification Removed

These commands represent notification state changes.

The protocol does not assume notifications are permanent.

---

# Notification Created

Purpose:

Deliver a newly received Android notification.

Typical information includes:

• Notification identifier.

• Application information.

• Notification title.

• Notification content.

• Available actions.

After successful processing:

The notification becomes visible on macOS.

---

# Notification Updated

Purpose:

Synchronize changes to an existing notification.

Examples include:

• Message edited.

• Progress updated.

• Additional content received.

Only changed information should be transmitted whenever practical.

---

# Notification Removed

Purpose:

Remove an existing notification.

Examples include:

• User dismissed notification.

• Application cancelled notification.

• Notification expired.

After processing:

The notification should disappear from macOS.

---

# Notification Reply Command

Purpose:

Send a reply entered on macOS back to Android.

Typical workflow:

User types reply

↓

macOS creates command

↓

Android receives command

↓

Android delivers reply using operating system APIs

↓

Android confirms completion

The protocol transports the reply.

Android performs the actual reply.

---

# Notification Payload Transmission

The protocol transfers the complete notification payload available from Android's NotificationListenerService.

If Android exposes the complete notification text, the entire payload is encrypted and transferred to the paired Mac.

No artificial truncation occurs during transmission.

The backend relays the encrypted payload without inspecting or modifying its contents.

Any visual truncation occurs only in the native macOS notification banner, never during transmission.

---

# Call Commands

Call commands synchronize incoming call state.

Supported Version 1 commands include:

Incoming Call

Call Updated

Call Ended

Call Accepted

Call Declined

---

# Incoming Call

Purpose:

Notify macOS that a call is arriving.

Typical information includes:

• Caller name.

• Caller number (if available).

• Call identifier.

• Current call state.

After processing:

The incoming call interface becomes visible.

---

# Call Updated

Purpose:

Reflect changes to an active call.

Examples include:

• Ringing.

• Answered.

• On hold.

• Ending.

The interface updates without recreating the call.

---

# Call Ended

Purpose:

Inform macOS that the call no longer exists.

After processing:

The call interface immediately disappears.

---

# Call Accepted

Purpose:

Notify Android that the user accepted the call from macOS.

Android performs the actual operating system action.

The protocol merely transports the request.

---

# Call Declined

Purpose:

Notify Android that the user rejected the incoming call.

Android performs the rejection using system APIs.

---

# Device Commands

Device commands control supported device-level features.

Version 1 defines:

Ring Phone

Future versions may expand this category.

---

# Ring Phone

Purpose:

Request Android to begin ringing.

Workflow:

User selects Ring Phone

↓

macOS creates command

↓

Android receives command

↓

Android starts ringing

↓

Android confirms execution

The protocol does not define ringtone behavior.

Only the request itself.

---

# Synchronization Commands

Synchronization commands maintain consistency between devices.

Examples include:

• Initial synchronization.

• State refresh.

• Session synchronization.

• Connection recovery.

Synchronization commands do not represent user actions.

They maintain protocol consistency.

---

# Initial Synchronization

Purpose:

Synchronize current application state immediately after authentication.

Examples include:

• Existing notifications.

• Connection information.

• Current device status.

Initial synchronization prepares both devices for normal communication.

---

# State Refresh

Purpose:

Correct temporary inconsistencies.

Examples include:

• Lost packets.

• Interrupted synchronization.

• Recovered sessions.

State refresh always favors verified current state.

---

# Heartbeat Commands

Heartbeat commands confirm that an authenticated session remains active.

Heartbeat commands contain no application data.

Heartbeat processing should remain lightweight.

Failure to receive expected heartbeats eventually results in session recovery.

---

# Error Commands

Error commands communicate protocol failures.

Examples include:

• Unsupported protocol version.

• Invalid command.

• Authentication failure.

• Trust validation failure.

• Session expired.

Error commands communicate failure.

They do not attempt automatic recovery.

---

# Command Execution Rules

Commands execute only when:

• Session authenticated.

• Trust verified.

• Packet validated.

• Packet decrypted.

• Command recognized.

Commands failing any prerequisite are rejected immediately.

---

# Command Ordering

Certain commands require ordered execution.

Example:

Notification Created

↓

Notification Updated

↓

Notification Removed

Executing these commands in reverse order may produce inconsistent state.

Ordering rules must therefore be respected.

---

# Command Idempotency

Whenever practical, commands should be idempotent.

Executing the same command more than once should not produce duplicate results.

Examples include:

• Removing an already removed notification.

• Ending an already ended call.

• Ring request already active.

This simplifies duplicate packet handling.

---

# Unsupported Commands

When a device receives an unsupported command:

• The command is rejected.

• No partial execution occurs.

• An appropriate protocol error may be returned.

The remaining communication session remains unaffected whenever possible.

---

# Future Commands

Future protocol versions may introduce new commands.

Existing implementations should ignore unsupported commands safely rather than assuming undefined behavior.

Backward compatibility should remain a protocol priority.

---

# Command Naming Rules

Every protocol command should:

• Describe one action.

• Use consistent terminology.

• Avoid ambiguity.

• Remain platform independent.

Protocol names should describe intent rather than implementation.

---

# Command Review Checklist

Before introducing a new command, verify:

✓ Does the command have one responsibility?

✓ Is authentication required?

✓ Is acknowledgement behavior defined?

✓ Is failure behavior documented?

✓ Can duplicate execution occur safely?

✓ Does it fit an existing command category?

✓ Does it preserve protocol compatibility?

✓ Can older implementations safely ignore it?

Every protocol command should remain simple, deterministic, and independently testable.

---

# Protocol Commands

Protocol commands define the actions exchanged between authenticated devices.

Each command represents a single logical operation.

Commands must remain:

• Deterministic.

• Independent.

• Authenticated.

• Version compatible.

Every command belongs to a predefined command category.

Unknown commands must never be executed.

---

# Command Design Principles

Every protocol command must:

• Have one clearly defined purpose.

• Produce one predictable result.

• Be authenticated.

• Be encrypted.

• Support acknowledgement.

• Be safe to reject.

Commands must never depend upon undocumented behavior.

---

# Command Categories

Version 1 defines the following command categories.

• Pairing Commands

• Authentication Commands

• Session Commands

• Notification Commands

• Call Commands

• Device Commands

• Synchronization Commands

• Heartbeat Commands

• Error Commands

Future protocol versions may introduce additional categories without modifying existing behavior.

---

# Pairing Commands

Pairing commands exist only during the pairing protocol.

They are never used during normal communication.

Examples include:

• Pairing Request

• Pairing Response

• Identity Exchange

• Public Key Exchange

• Pairing Confirmation

• Pairing Cancellation

Once pairing completes successfully, these commands become invalid.

---

# Authentication Commands

Authentication commands establish a trusted communication session.

Examples include:

• Authentication Request

• Authentication Challenge

• Authentication Response

• Authentication Success

• Authentication Failure

Authentication commands execute before application commands.

---

# Session Commands

Session commands manage communication lifecycle.

Examples include:

• Session Start

• Session Ready

• Session Closing

• Session Closed

• Session Recovery

These commands coordinate communication without interacting with operating system functionality.

---

# Notification Commands

Notification commands synchronize notifications from Android to macOS.

Version 1 supports:

Notification Created

Notification Updated

Notification Removed

These commands represent notification state changes.

The protocol does not assume notifications are permanent.

---

# Notification Created

Purpose:

Deliver a newly received Android notification.

Typical information includes:

• Notification identifier.

• Application information.

• Notification title.

• Notification content.

• Available actions.

After successful processing:

The notification becomes visible on macOS.

---

# Notification Updated

Purpose:

Synchronize changes to an existing notification.

Examples include:

• Message edited.

• Progress updated.

• Additional content received.

Only changed information should be transmitted whenever practical.

---

# Notification Removed

Purpose:

Remove an existing notification.

Examples include:

• User dismissed notification.

• Application cancelled notification.

• Notification expired.

After processing:

The notification should disappear from macOS.

---

# Notification Reply Command

Purpose:

Send a reply entered on macOS back to Android.

Typical workflow:

User types reply

↓

macOS creates command

↓

Android receives command

↓

Android delivers reply using operating system APIs

↓

Android confirms completion

The protocol transports the reply.

Android performs the actual reply.

---

# Call Commands

Call commands synchronize incoming call state.

Supported Version 1 commands include:

Incoming Call

Call Updated

Call Ended

Call Accepted

Call Declined

---

# Incoming Call

Purpose:

Notify macOS that a call is arriving.

Typical information includes:

• Caller name.

• Caller number (if available).

• Call identifier.

• Current call state.

After processing:

The incoming call interface becomes visible.

---

# Call Updated

Purpose:

Reflect changes to an active call.

Examples include:

• Ringing.

• Answered.

• On hold.

• Ending.

The interface updates without recreating the call.

---

# Call Ended

Purpose:

Inform macOS that the call no longer exists.

After processing:

The call interface immediately disappears.

---

# Call Accepted

Purpose:

Notify Android that the user accepted the call from macOS.

Android performs the actual operating system action.

The protocol merely transports the request.

---

# Call Declined

Purpose:

Notify Android that the user rejected the incoming call.

Android performs the rejection using system APIs.

---

# Device Commands

Device commands control supported device-level features.

Version 1 defines:

Ring Phone

Future versions may expand this category.

---

# Ring Phone

Purpose:

Request Android to begin ringing.

Workflow:

User selects Ring Phone

↓

macOS creates command

↓

Android receives command

↓

Android starts ringing

↓

Android confirms execution

The protocol does not define ringtone behavior.

Only the request itself.

---

# Synchronization Commands

Synchronization commands maintain consistency between devices.

Examples include:

• Initial synchronization.

• State refresh.

• Session synchronization.

• Connection recovery.

Synchronization commands do not represent user actions.

They maintain protocol consistency.

---

# Initial Synchronization

Purpose:

Synchronize current application state immediately after authentication.

Examples include:

• Existing notifications.

• Connection information.

• Current device status.

Initial synchronization prepares both devices for normal communication.

---

# State Refresh

Purpose:

Correct temporary inconsistencies.

Examples include:

• Lost packets.

• Interrupted synchronization.

• Recovered sessions.

State refresh always favors verified current state.

---

# Heartbeat Commands

Heartbeat commands confirm that an authenticated session remains active.

Heartbeat commands contain no application data.

Heartbeat processing should remain lightweight.

Failure to receive expected heartbeats eventually results in session recovery.

---

# Error Commands

Error commands communicate protocol failures.

Examples include:

• Unsupported protocol version.

• Invalid command.

• Authentication failure.

• Trust validation failure.

• Session expired.

Error commands communicate failure.

They do not attempt automatic recovery.

---

# Command Execution Rules

Commands execute only when:

• Session authenticated.

• Trust verified.

• Packet validated.

• Packet decrypted.

• Command recognized.

Commands failing any prerequisite are rejected immediately.

---

# Command Ordering

Certain commands require ordered execution.

Example:

Notification Created

↓

Notification Updated

↓

Notification Removed

Executing these commands in reverse order may produce inconsistent state.

Ordering rules must therefore be respected.

---

# Command Idempotency

Whenever practical, commands should be idempotent.

Executing the same command more than once should not produce duplicate results.

Examples include:

• Removing an already removed notification.

• Ending an already ended call.

• Ring request already active.

This simplifies duplicate packet handling.

---

# Unsupported Commands

When a device receives an unsupported command:

• The command is rejected.

• No partial execution occurs.

• An appropriate protocol error may be returned.

The remaining communication session remains unaffected whenever possible.

---

# Future Commands

Future protocol versions may introduce new commands.

Existing implementations should ignore unsupported commands safely rather than assuming undefined behavior.

Backward compatibility should remain a protocol priority.

---

# Command Naming Rules

Every protocol command should:

• Describe one action.

• Use consistent terminology.

• Avoid ambiguity.

• Remain platform independent.

Protocol names should describe intent rather than implementation.

---

# Command Review Checklist

Before introducing a new command, verify:

✓ Does the command have one responsibility?

✓ Is authentication required?

✓ Is acknowledgement behavior defined?

✓ Is failure behavior documented?

✓ Can duplicate execution occur safely?

✓ Does it fit an existing command category?

✓ Does it preserve protocol compatibility?

✓ Can older implementations safely ignore it?

Every protocol command should remain simple, deterministic, and independently testable.

---

# Delivery Guarantees

The protocol defines how command delivery should be interpreted.

Version 1 guarantees:

• Commands are authenticated.

• Commands are validated.

• Commands are processed at most once.

• Duplicate execution is prevented.

The protocol intentionally does not guarantee instantaneous delivery.

Reliable communication is defined by correctness rather than speed.

---

# Delivery States

Every outgoing packet exists in one delivery state.

Created

↓

Queued

↓

Transmitting

↓

Delivered

↓

Acknowledged

or

Failed

State transitions must always occur in this order.

Skipping states is prohibited.

---

# Reliable Delivery

Reliable delivery requires:

• Successful transmission.

• Successful validation.

• Successful command execution.

• Successful acknowledgement.

Only after acknowledgement may the sender consider the command complete.

---

# Pending Delivery Queue

Packets awaiting acknowledgement remain inside a temporary delivery queue.

The queue exists only for active communication sessions.

Its responsibilities include:

• Tracking pending packets.

• Managing retransmissions.

• Removing acknowledged packets.

The queue must never become the permanent source of truth.

---

# Retry Philosophy

Retries exist to recover from temporary communication failures.

Retries should never compensate for permanent protocol errors.

Retrying invalid packets is prohibited.

Retrying failed authentication is prohibited.

Retrying corrupted packets is prohibited.

Only temporary delivery failures are eligible for retry.

---

# Retry Conditions

Retries may occur when:

• Temporary network interruption.

• Backend relay interruption.

• Packet timeout.

• Connection recovery.

Retries should not occur when:

• Authentication fails.

• Trust validation fails.

• Packet rejected.

• Unsupported protocol version.

---

# Retry Limits

Every packet has a finite retry limit.

After the retry limit is exceeded:

• Packet marked failed.

• Sender notified.

• Pending packet removed.

Unlimited retries are prohibited.

---

# Retry Interval

Retries should use progressive timing rather than immediate repetition.

Repeated immediate retransmission increases unnecessary network traffic.

The protocol recommends increasing delay between retry attempts.

Specific timing values are implementation dependent.

---

# Packet Timeout

Every transmitted packet has an acknowledgement timeout.

If acknowledgement is not received before timeout:

• Retry logic begins.

or

• Packet fails.

Timeout duration should balance:

• Network latency.

• User experience.

• Resource usage.

Exact timeout values are implementation specific.

---

# Session Timeout

Communication sessions should not remain active indefinitely without activity.

Inactive sessions eventually expire.

Session expiration triggers:

• Session destruction.

• Temporary state cleanup.

• Future re-authentication.

Trust information remains unaffected.

The connection timeout is 90 seconds of undetected activity.

---

# Heartbeat Timeout

Heartbeat monitoring detects silent connection failures.

The heartbeat interval is 30 seconds.

If expected heartbeats are not received:

• Session considered unhealthy.

• Communication suspended.

• Recovery procedure initiated.

Heartbeats exist to monitor session health rather than application activity.

---

# Offline Communication

Temporary offline operation is considered a normal operating condition.

The protocol should fail gracefully rather than unexpectedly.

Offline state never invalidates trust.

It only prevents communication.

---

# Offline Queue Behavior

Commands generated while offline require deterministic handling.

Version 1 follows these principles:

Commands requiring an active peer should not execute locally.

Commands awaiting delivery may remain queued temporarily if appropriate.

Expired commands should be discarded safely.

Applications should clearly communicate when an action cannot currently be completed.

---

# Message Expiration

Not every command remains useful forever.

Examples:

Incoming call notifications.

Temporary status updates.

Pairing requests.

Such commands may expire after a reasonable lifetime.

Expired commands must never execute.

---

# Permanent Commands

Certain commands should never expire while delivery remains possible.

Examples include:

Trust changes.

Explicit unpair requests.

These commands remain logically important until processed or intentionally discarded.

---

# Failure Classification

Protocol failures are divided into categories.

Temporary Failures

Permanent Failures

Security Failures

Compatibility Failures

Each category requires different recovery behavior.

---

# Temporary Failures

Examples include:

• Network interruption.

• Backend restart.

• Packet timeout.

• Session interruption.

These failures may trigger retry or recovery procedures.

---

# Permanent Failures

Examples include:

• Unsupported protocol version.

• Invalid packet structure.

• Missing required fields.

• Unsupported command.

Retries are prohibited.

---

# Security Failures

Examples include:

• Authentication failure.

• Trust validation failure.

• Invalid signature.

• Integrity failure.

Security failures immediately terminate communication.

No automatic retry occurs.

---

# Compatibility Failures

Examples include:

• Unknown protocol version.

• Unsupported packet type.

• Unsupported command.

Devices should fail safely while preserving existing trust information.

---

# Recovery Philosophy

Recovery should always prioritize:

Security

↓

Consistency

↓

Reliability

↓

Performance

Recovering quickly is less important than recovering correctly.

---

# Automatic Recovery

Version 1 supports automatic recovery for:

• Lost connectivity.

• Backend restart.

• Temporary packet loss.

• Device wake from sleep.

Automatic recovery always begins with fresh authentication.

---

# Manual Recovery

Certain failures require user intervention.

Examples include:

• Application reinstallation.

• Lost trust information.

• Permission removal.

• Explicit unpairing.

Automatic recovery should never bypass required security checks.

---

# Network Switching

Devices may change networks during active communication.

Examples include:

Wi-Fi → Mobile Data

Mobile Data → Wi-Fi

Wi-Fi → Different Wi-Fi

Network switching should trigger:

• Session interruption.

• Fresh authentication.

• Communication recovery.

Trust remains unchanged.

---

# Backend Recovery

Backend availability should never become the source of trust.

After backend recovery:

• Devices reconnect.

• Authentication repeats.

• Communication resumes.

No trust information should depend on backend persistence.

A backend restart does not invalidate pairing.

Devices automatically reconnect and sessions automatically re-authenticate.

No QR re-pairing is required.

No user interaction is required.

---

# Protocol Version Negotiation

Before normal communication begins, devices compare supported protocol versions.

The objective is to determine whether safe communication is possible.

Version negotiation occurs before application commands.

---

# Version Compatibility Strategy

Compatible versions communicate normally.

Older implementations ignore unsupported optional features whenever possible.

Breaking changes require a new major protocol version.

Minor enhancements should preserve backward compatibility.

---

# Unknown Protocol Version

If an unknown protocol version is encountered:

• Communication stops.

• Commands not executed.

• Existing trust remains unchanged.

The user may be informed that an application update is required.

---

# Protocol Evolution

Future protocol versions should extend rather than replace existing behavior.

Whenever practical:

New packet types should be added.

Existing packet behavior should remain unchanged.

Removing existing protocol behavior should be considered a breaking change.

---

# Deprecation Strategy

Protocol features may eventually become deprecated.

Deprecation should occur gradually.

Older implementations should continue functioning whenever practical.

Immediate removal should be avoided except for critical security reasons.

---

# Resource Management

Communication resources should remain proportional to actual activity.

Inactive sessions should release temporary resources.

Expired packets should be removed.

Completed sessions should destroy temporary state.

Long-lived unused protocol state is discouraged.

---

# Performance Considerations

The protocol should minimize:

• Network traffic.

• Packet size.

• Battery consumption.

• Memory usage.

• CPU overhead.

Efficiency should never weaken security guarantees.

---

# Failure Logging

Implementations should log meaningful protocol failures.

Examples include:

• Authentication failure.

• Session timeout.

• Unsupported version.

• Packet rejection.

Sensitive application data must never appear in logs.

---

# Protocol Review Checklist

Before modifying protocol reliability behavior, verify:

✓ Does recovery preserve security?

✓ Are retries limited?

✓ Are expired commands discarded safely?

✓ Are failures classified correctly?

✓ Does recovery require fresh authentication?

✓ Does compatibility remain intact?

✓ Can older implementations fail safely?

✓ Does trust remain independent of backend availability?

Every modification should improve reliability without weakening protocol correctness.

---

# Protocol Security Rules

The protocol shall never weaken the security guarantees established by the Security Model.

Every implementation must preserve:

• Authentication.

• Trust validation.

• End-to-end encryption.

• Packet integrity.

• Packet authenticity.

• Replay protection.

Protocol optimization must never reduce security.

---

# Trust Independence

The protocol operates independently from infrastructure.

The backend facilitates communication.

The backend never owns trust.

The backend never authenticates devices.

The backend never stores permanent trust relationships.

Trust always exists exclusively between paired devices.

---

# End-to-End Confidentiality

Application data must remain confidential throughout its entire lifecycle.

Information shall remain encrypted:

• During transmission.

• While traversing backend infrastructure.

• Until received by the authenticated destination.

Only authenticated paired devices may decrypt application payloads.

---

# Protocol Invariants

The following rules are protocol invariants.

They must remain true for every protocol version.

• Every session begins unauthenticated.

• Every session requires authentication.

• Every command requires authentication.

• Every packet is validated before execution.

• Every command executes at most once.

• Trust never depends upon backend infrastructure.

• Temporary session state never becomes permanent state.

Breaking a protocol invariant constitutes a breaking protocol change.

---

# Implementation Guidelines

Every implementation should follow the protocol exactly as specified.

Implementation details may differ between platforms.

Protocol behavior must not.

Android, macOS, and backend implementations should produce identical protocol behavior for identical inputs.

Behavioral consistency is more important than implementation similarity.

---

# Cross-Platform Consistency

Although Android and macOS use different operating systems and frameworks, they must interpret protocol behavior identically.

Examples include:

• Authentication decisions.

• Session lifecycle.

• Packet validation.

• Duplicate detection.

• Command ordering.

Platform-specific behavior must never change protocol semantics.

---

# Deterministic Behavior

The same protocol input must always produce the same protocol outcome.

Protocol behavior must never depend upon:

• Device manufacturer.

• Operating system implementation details.

• Hardware characteristics.

• Processing speed.

Deterministic behavior simplifies debugging, testing, and maintenance.

---

# Error Handling Principles

Every protocol failure must produce one clearly defined outcome.

Undefined behavior is prohibited.

When uncertainty exists, the protocol should reject communication safely rather than guessing intended behavior.

Security always takes precedence over convenience.

---

# Logging Guidelines

Protocol implementations may log operational events required for debugging and diagnostics.

Examples include:

• Session creation.

• Authentication success.

• Authentication failure.

• Packet rejection.

• Session recovery.

• Protocol version mismatch.

Logs must never contain:

• Private keys.

• Decrypted payloads.

• Notification contents.

• User replies.

• Session secrets.

• Cryptographic material.

Diagnostic logging must never compromise user privacy.

---

# Privacy Requirements

The protocol is designed according to the principle of minimum information exposure.

Only information necessary to complete a protocol operation should be transmitted.

Unused metadata should never be introduced.

Future protocol extensions should preserve this principle.

---

# Resource Usage Principles

The protocol should remain lightweight.

Communication should minimize:

• CPU usage.

• Memory usage.

• Battery consumption.

• Network bandwidth.

Protocol complexity should grow only when justified by measurable benefit.

---

# Scalability

The protocol should support future growth without architectural redesign.

Examples include:

• Multiple paired devices.

• Clipboard synchronization.

• File transfer.

• Device groups.

• Shared sessions.

• Additional operating systems.

Future expansion should extend existing protocol behavior rather than replace it.

---

# Backward Compatibility

Whenever practical, protocol evolution should preserve compatibility with previous versions.

Older implementations should continue functioning unless prevented by security or architectural requirements.

Breaking compatibility should remain a rare event.

---

# Forward Compatibility

Older implementations should safely ignore protocol elements they do not understand whenever doing so cannot compromise security.

Unknown optional functionality should not terminate communication unnecessarily.

Unknown mandatory functionality should fail safely.

---

# Compliance Requirements

An implementation may be considered protocol compliant only if it satisfies all mandatory protocol rules.

Compliance includes:

• Correct authentication.

• Correct packet validation.

• Correct session management.

• Correct command handling.

• Correct acknowledgement behavior.

• Correct recovery procedures.

Partial compliance should not be considered protocol compatibility.

---

# Testing Requirements

Every protocol implementation should be tested against the specification rather than against another implementation.

Testing should verify:

• Authentication.

• Packet validation.

• Duplicate detection.

• Recovery.

• Ordering.

• Retry behavior.

• Timeout handling.

• Compatibility.

Conformance testing should produce identical results across all supported platforms.

---

# Reference Implementation

If a reference implementation is developed in the future, it serves as an example of protocol usage.

The specification always takes precedence.

The protocol specification remains the authoritative source of truth.

Implementation code must never redefine protocol behavior.

---

# Future Protocol Extensions

Future protocol versions should introduce additional capabilities without weakening existing guarantees.

Possible future extensions include:

• Clipboard synchronization.

• File transfer.

• Battery synchronization.

• Camera access.

• Phone screen sharing.

• Device capability negotiation.

• Multi-device routing.

• Administrative device management.

All future extensions must remain compatible with the architectural principles established by this specification.

---

# Protocol Governance

Any proposed modification to the protocol should undergo formal architectural review.

Each proposal should answer:

• What problem does this solve?

• Does it introduce security risk?

• Does it preserve compatibility?

• Does it increase protocol complexity?

• Can the same objective be achieved more simply?

Protocol evolution should remain deliberate and well documented.

---

# Protocol Review Checklist

Before approving any protocol modification, verify:

✓ Authentication remains unchanged.

✓ Trust relationships remain unchanged.

✓ Packet validation remains deterministic.

✓ Duplicate execution remains impossible.

✓ Recovery procedures remain correct.

✓ Version compatibility is preserved.

✓ Security guarantees are maintained.

✓ Privacy is unaffected.

✓ Resource usage remains acceptable.

✓ Documentation is updated.

Protocol modifications are not complete until the documentation has been updated accordingly.

---

# Conclusion

The MacEcho Protocol Specification defines a secure, reliable, and extensible communication foundation for the platform.

It establishes a common language shared by Android, macOS, and backend components while preserving the architectural principles defined throughout the project documentation.

The protocol prioritizes correctness over speed, security over convenience, and consistency over implementation-specific behavior.

By separating communication rules from implementation details, the protocol remains stable even as technologies, frameworks, and operating systems evolve.

This document serves as the authoritative specification for all communication performed within the MacEcho platform.

Every implementation must conform to the rules defined herein to ensure interoperability, reliability, and long-term maintainability.

---