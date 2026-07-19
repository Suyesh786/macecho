---
Document: Security Model
Version: 1.0
Status: Draft
Last Updated: YYYY-MM-DD
Owner: MacEcho Team
Review Required: Yes
---

# Security Model

# Purpose

This document defines the complete security architecture of MacEcho.

It establishes the principles, trust boundaries, cryptographic philosophy, authentication model, and security responsibilities that every component of the system must follow.

The purpose of this document is not merely to describe encryption techniques, but to define how trust is established, maintained, validated, and revoked throughout the lifecycle of the application.

Every future implementation must comply with the rules defined in this document.

No implementation may weaken or bypass these security requirements without an explicit architectural review.

---

# Scope

This document covers:

• Security philosophy

• Security objectives

• Trust model

• Device identity

• Cryptographic responsibilities

• Pairing security

• Authentication model

• Secure communication

• Secure storage

• Session trust

• Offline security

• Device lifecycle

• Threat model

• Security boundaries

• Security assumptions

Implementation-specific details such as packet formats, API endpoints, encryption algorithms, and protocol specifications are documented separately in their respective documents.

---

# Security Philosophy

MacEcho is designed around the principle that security is a core architectural feature rather than an optional enhancement.

Every feature added to the application must preserve the confidentiality, integrity, authenticity, and availability of user data.

The system assumes that networks cannot be trusted, backend services may become compromised, and devices may temporarily become unavailable.

Therefore, trust is established directly between paired devices rather than delegated to infrastructure.

Security decisions always take precedence over convenience whenever a conflict exists.

---

# Core Security Principles

MacEcho follows the following principles throughout the entire system.

• Trust only verified devices.

• Never trust the communication network.

• Never trust the backend with user data.

• Encrypt everything before transmission.

• Keep private keys on the originating device.

• Minimize stored sensitive information.

• Grant the minimum required permissions.

• Assume every incoming packet could be malicious until verified.

• Every authenticated action must be verifiable.

• Every device must prove its identity.

• Every security decision must be deterministic.

• Security must remain consistent even while devices are offline.

• Privacy must never depend upon backend honesty.

---

# Security Objectives

The primary objectives of the MacEcho security model are:

• Protect user privacy.

• Prevent unauthorized device access.

• Prevent unauthorized message reading.

• Prevent packet tampering.

• Prevent replay attacks.

• Prevent impersonation.

• Prevent unauthorized pairing.

• Prevent trust hijacking.

• Maintain secure communication across untrusted networks.

• Ensure compromised infrastructure cannot expose user content.

• Preserve trust throughout the lifetime of paired devices.

---

# Security Architecture Overview

MacEcho follows an end-to-end trust architecture.

Trust exists only between paired devices.

The backend acts solely as an encrypted transport layer.

At no point does the backend possess sufficient information to impersonate either device or decrypt exchanged data.

Every secure operation depends upon cryptographic proof rather than assumptions about network security.

---

# Trust Model

Trust is the foundation of the MacEcho security architecture.

The system intentionally separates communication from trust.

Communication is handled by the backend.

Trust is owned exclusively by paired devices.

The backend never decides which devices trust each other.

The backend never creates trust.

The backend never restores trust.

The backend never revokes trust.

Only paired devices possess the authority to establish or terminate their mutual trust relationship.

---

# Trust Relationships

Version 1 supports only one trust relationship.

One Android device.

One macOS device.

One active pairing.

No additional trusted devices may exist simultaneously.

This restriction significantly simplifies security verification while reducing the attack surface.

Future versions may expand this model through carefully designed trust groups without changing the underlying security architecture.

---

# Source of Truth

The paired devices themselves are the only source of truth regarding trust.

The backend is never considered authoritative.

If conflicting information exists between a device and the backend, the device always takes precedence.

This prevents compromised infrastructure from forcing unwanted pairing state changes.

Examples include:

• A compromised backend reporting an active pairing that no longer exists.

• A compromised backend reporting an unpaired state.

• Delayed synchronization.

• Corrupted backend data.

None of these situations may alter local trust stored on a trusted device.

---

# Device Identity

Every device participating in MacEcho possesses a permanent identity created during initial setup.

This identity remains unique throughout the lifetime of the installation.

Each identity consists of:

• Device Identifier

• Device Name

• Device Type

• Cryptographic Public Key

• Cryptographic Private Key

• Local Trust Database

The identity is generated locally.

No external service generates identities for devices.

---

# Device Identifier

Every installation generates a cryptographically secure unique identifier.

This identifier is permanent for the lifetime of the installation.

The identifier is not derived from:

• MAC Address

• IMEI

• Android ID

• Apple Hardware Identifier

• Email Address

• Phone Number

• IP Address

This prevents device tracking outside the application's trust model.

---

# Cryptographic Identity

Every installation creates its own asymmetric key pair during initialization, using X25519 for key exchange.

The private key never leaves the device.

The public key is shared only during the secure pairing process.

The cryptographic identity becomes the permanent proof of ownership for that installation.

Future authentication relies upon this identity rather than passwords or backend-generated credentials.

---

# Private Keys

Private keys represent the highest security asset within the entire application.

The following rules always apply.

Private keys:

• Are generated locally.

• Never leave the originating device.

• Are never transmitted.

• Are never backed up to the backend.

• Are never visible to users.

• Are never exported.

• Are never logged.

• Are never embedded inside packets.

Compromise of a private key is considered equivalent to compromise of the entire device identity.

---

# Public Keys

Public keys are intentionally shareable.

Their purpose is to allow devices to verify identities and establish encrypted communication.

Public keys may be exchanged only during authenticated pairing.

Changing a public key automatically invalidates the existing trust relationship.

A new pairing process becomes mandatory.

---

# Secure Storage

Sensitive information must always remain inside operating-system-provided secure storage.

Android uses the Android Keystore for private keys, and encrypted local storage for trusted device metadata.

macOS uses the Apple Keychain for private keys, and encrypted local storage for trusted device metadata.

Private keys must never be stored in ordinary application storage, databases, preferences, cache directories, or configuration files.

Only non-sensitive metadata may exist outside secure storage.

The backend stores only:

• Public keys.

• Session metadata.

• Routing metadata.

The backend never stores:

• Private keys.

• Shared secrets.

• Decrypted payloads.

---

# Local Trust Database

Each paired device maintains a local trust database.

This database stores information necessary to recognize trusted peers.

Typical information includes:

• Trusted Device Identifier

• Trusted Public Key

• Pairing Timestamp

• Trust Status

• Device Metadata

The local trust database never stores another device's private key.

The backend has no authority to modify the local trust database.

Only the local application may update trust records after successful security validation.

---

# Security Boundaries

MacEcho divides responsibilities into strict security boundaries.

Android is responsible for Android operating system interactions.

macOS is responsible for macOS operating system interactions.

The backend is responsible only for encrypted message transport.

The communication protocol defines secure interaction rules.

Each boundary operates independently.

Crossing a boundary always requires verification.

No component is permitted to assume another component is trustworthy without cryptographic validation.

---

# Pairing Security

Pairing is the most security-critical operation performed by MacEcho.

Every future secure interaction depends upon the integrity of the initial pairing process.

A successful pairing establishes a trusted relationship between exactly one Android device and one macOS device.

If pairing security is compromised, every future encrypted communication becomes untrustworthy.

For this reason, pairing follows a strict verification process designed to prevent unauthorized devices from entering the trust relationship.

---

# Pairing Objectives

The pairing process is designed to achieve the following objectives.

• Establish mutual trust between devices.

• Exchange cryptographic identities securely.

• Prevent unauthorized device enrollment.

• Prevent replay of pairing requests.

• Prevent impersonation.

• Ensure the backend never establishes trust.

• Ensure only physically present users can initiate pairing.

• Produce a trusted relationship that survives normal device restarts.

---

# Pairing Requirements

A successful pairing requires:

• One Android device.

• One macOS device.

• User interaction on both devices.

• A valid QR code.

• Active internet connectivity during the initial pairing.

• Successful cryptographic verification.

If any requirement fails, pairing must terminate without creating a trust relationship.

Partial pairing states must never exist.

---

# QR Code Philosophy

The QR code is not a password.

It is not a permanent pairing token.

It is not proof of trust.

Instead, the QR code serves only as a temporary bootstrap mechanism that enables two devices to discover each other securely.

Trust is established only after all verification steps have successfully completed.

Scanning a QR code alone never creates trust.

---

# QR Code Lifetime

Every QR code generated by the macOS application must have a short validity period.

The QR code must expire automatically after a predefined duration.

Expired QR codes become permanently invalid.

Generating a new QR code immediately invalidates any previously generated unused QR codes.

Only one active pairing QR code may exist at any given time.

This prevents multiple concurrent pairing attempts using stale pairing information.

---

# Single-Use Pairing

Every pairing QR code is single-use.

After successful pairing:

• The QR code becomes permanently invalid.

• It cannot be reused.

• It cannot pair another device.

• It cannot restore trust.

A completely new pairing session requires generation of a new QR code.

---

# Physical Presence Requirement

MacEcho intentionally requires physical access to both devices during pairing.

The user must:

• Open the macOS application.

• Generate a pairing QR code.

• Scan the QR code using the Android application.

This requirement significantly reduces the possibility of unauthorized remote pairing.

Remote pairing is intentionally unsupported.

---

# Secure Pairing Flow

The high-level pairing process follows the sequence below.

1. The macOS application generates a temporary pairing session.

2. A single-use QR code is created.

3. The Android application scans the QR code.

4. Both devices establish communication through the backend relay.

5. Each device exchanges its public key.

6. Each device verifies the received information.

7. Mutual trust is established.

8. Local trust databases are updated.

9. Pairing session is destroyed.

10. Secure communication begins.

At no point does the backend gain authority over trust.

---

# Mutual Authentication

Both devices authenticate each other.

Authentication is never one-sided.

Android verifies macOS.

macOS verifies Android.

Trust exists only if both verifications succeed.

Failure on either side causes immediate termination of the pairing process.

---

# Public Key Exchange

During pairing, devices exchange their public keys.

These public keys become the permanent cryptographic identities used for future authentication.

The exchange occurs only after the pairing session has been successfully established.

Private keys are never exchanged.

---

# Trust Establishment

Trust is established only after:

• Device identities are verified.

• Public keys are exchanged.

• Verification succeeds.

• Both devices explicitly acknowledge successful pairing.

Only then may each device store the other as trusted.

Until this point, every received message must be treated as untrusted.

---

# Pairing Session

Every pairing operation creates a temporary pairing session.

The session exists only for the duration of the pairing process.

After completion:

• Temporary session information is destroyed.

• Temporary tokens are invalidated.

• Temporary identifiers become unusable.

The pairing session must never remain active after pairing concludes.

---

# Pairing Failure

Pairing immediately fails if:

• QR code expires.

• QR code is invalid.

• QR code was already used.

• Public key verification fails.

• Authentication fails.

• Network communication fails before completion.

• User cancels pairing.

• Device identity validation fails.

Failure must leave both devices in their original unpaired state.

No partial trust may remain.

---

# Authentication Philosophy

Authentication proves identity.

Authorization grants permission.

MacEcho separates these concepts.

A device must first authenticate itself.

Only authenticated trusted devices may perform authorized actions.

Successful authentication alone does not automatically authorize every operation.

Future permissions may further restrict actions while preserving trust.

---

# Session Authentication

Every communication session begins with authentication.

Both devices must confirm that they are communicating with their previously trusted peer.

Authentication occurs before application data is exchanged.

Failure immediately terminates the session.

No notification data, replies, or commands may be exchanged before authentication completes successfully.

---

# Trust Validation

Trust is continuously validated throughout the lifetime of the application.

Trust is not assumed simply because pairing occurred previously.

Whenever a communication session begins, both devices verify:

• Device identity.

• Stored public key.

• Cryptographic authenticity.

Only after successful validation may secure communication continue.

---

# Reconnection Validation

Devices frequently disconnect due to:

• Internet outages.

• Sleep mode.

• Device restart.

• Application restart.

• Temporary backend interruptions.

Every reconnection requires trust validation before communication resumes.

The previous existence of trust does not bypass this verification.

---

# Trust Persistence

A trusted relationship remains valid until one of the following occurs.

• User manually unpairs.

• Cryptographic identity changes.

• Local trust data is removed.

• Application is reinstalled.

• Secure storage is reset.

Temporary disconnections do not remove trust.

Normal restarts do not remove trust.

Internet outages do not remove trust.

Trust survives these events because it is stored securely on each device.

---

# Trust Revocation

Trust may be revoked only by the trusted devices themselves.

The backend cannot revoke trust.

The backend cannot restore trust.

The backend cannot modify trust.

The backend cannot fabricate trusted relationships.

Trust revocation always originates from a legitimate trusted device or from deletion of local secure storage.

---

# End-to-End Encryption

All communication between paired devices must be protected using end-to-end encryption.

Encryption occurs on the originating device before any data leaves the device.

Decryption occurs only on the intended receiving device.

At no point during transmission does the backend possess the ability to decrypt, inspect, or modify protected application data.

This design ensures that user privacy does not depend upon trusting network infrastructure or backend services.

MacEcho uses the following cryptographic algorithms. These algorithms are mandatory:

• Key Exchange: X25519.

• Digital Signatures: Ed25519.

• Symmetric Encryption: AES-256-GCM.

• Key Derivation: HKDF-SHA256.

• Hash Algorithm: SHA-256.

---

# Encryption Philosophy

MacEcho follows a simple principle.

"If a device is not the intended recipient, it should never be capable of reading the data."

This principle applies to:

• Notifications

• Notification replies

• Call events

• Ring phone requests

• Pairing messages

• Future application commands

Every sensitive packet follows this rule.

---

# Data Classification

MacEcho classifies data into multiple security levels.

## Public Data

Information that is not sensitive.

Examples include:

• Application version

• Protocol version

• Device capabilities

Public data may be transmitted without encryption when appropriate.

---

## Protected Data

Information intended only for paired devices.

Examples include:

• Notification content

• Notification metadata

• Contact names

• Ring phone requests

• Reply messages

• Call events

Protected data must always remain encrypted during transmission.

---

## Secret Data

Information that must never leave the originating device.

Examples include:

• Private keys

• Secure storage contents

• Local trust database internals

• Operating system secure storage

Secret data is never transmitted under any circumstances.

---

# Packet Integrity

Encryption alone is insufficient.

Every packet must also provide integrity.

Integrity guarantees that a packet has not been modified after leaving the originating device.

If any portion of a protected packet changes during transmission, the receiving device must reject it immediately.

Corrupted packets must never reach application logic.

---

# Packet Authenticity

Every protected packet must prove its origin.

The receiving device must be able to verify that the packet originated from the trusted paired device.

Packets lacking verifiable authenticity must be discarded immediately.

Authentication always occurs before processing packet contents.

---

# Digital Signatures

Every authenticated communication relies upon cryptographic proof rather than device identifiers.

Digital signatures provide this proof.

MacEcho uses Ed25519 for digital signatures.

A valid signature demonstrates that:

• The sender possesses the correct private key.

• The packet originated from the trusted device.

• The packet has not been modified after signing.

Packets with invalid signatures must never be processed.

---

# Packet Verification Order

Every received packet follows the same verification sequence.

1. Confirm packet structure.

2. Verify protocol compatibility.

3. Verify sender identity.

4. Verify digital signature.

5. Verify packet integrity.

6. Verify packet freshness.

7. Decrypt payload.

8. Validate decrypted contents.

9. Execute application logic.

If any step fails, packet processing immediately terminates.

---

# Packet Freshness

Every protected packet must prove that it represents a recent legitimate message.

Old packets must not be accepted indefinitely.

Freshness validation prevents attackers from replaying previously captured packets.

Freshness verification occurs before application processing begins.

---

# Replay Attack Prevention

Replay attacks occur when previously intercepted packets are retransmitted in an attempt to repeat legitimate actions.

Examples include:

• Repeating a ring phone command.

• Replaying a notification reply.

• Replaying an authentication request.

• Replaying a pairing message.

MacEcho prevents replay attacks by ensuring that previously accepted packets cannot be accepted again.

Each authenticated packet must contain sufficient information to distinguish it from every previous authenticated packet.

Previously processed packets must never be executed twice.

Every packet contains:

• Packet UUID.

• Session Sequence Number.

• Timestamp.

The receiver must:

• Reject duplicate Packet UUIDs.

• Reject stale Session Sequence Numbers.

• Reject packets outside the allowed clock skew.

• Maintain a temporary cache of processed Packet UUIDs.

---

# Duplicate Packet Protection

Network conditions occasionally result in duplicate packet delivery.

Duplicate packets are not automatically considered malicious.

However, duplicate protected commands must never execute multiple times.

The receiving device must identify duplicate authenticated packets and safely discard redundant executions.

---

# Message Ordering

Certain application events depend upon correct ordering.

Examples include:

• Notification arrives before reply.

• Call begins before call ends.

• Pairing completes before secure communication begins.

Packets received outside their expected logical order must be handled safely.

Ordering validation improves consistency without weakening security.

---

# Communication Confidentiality

Only trusted paired devices may view protected application content.

Neither:

• Backend infrastructure

• Internet providers

• Network administrators

• Wi-Fi operators

• Proxy servers

• Third-party relays

should possess sufficient information to reconstruct encrypted communication.

---

# Backend Security Responsibilities

The backend performs only infrastructure responsibilities.

Its responsibilities include:

• Routing packets.

• Maintaining active connections.

• Delivering encrypted payloads.

• Supporting temporary pairing sessions.

The backend intentionally avoids access to application secrets.

---

# Backend Security Limitations

The backend must never:

• Store private keys.

• Generate device identities.

• Decide trust.

• Read notification contents.

• Read reply messages.

• Decrypt encrypted payloads.

• Forge trusted packets.

• Permanently store sensitive application data.

The backend remains intentionally limited to reduce the consequences of infrastructure compromise.

---

# Backend Rate Limiting

The backend enforces rate limiting across four areas:

• Connection protection.

• Authentication protection.

• Packet protection.

• Abuse detection.

Initial limits for Version 1:

• Concurrent Connections per IP: 20.

• Pairing Attempts per IP: 10 per hour.

• Authentication Failures: 5 before cooldown.

• Packets per Second: 100.

• Maximum Packet Size: 64 KB.

These limits reduce the impact of denial-of-service attempts, brute-force pairing attempts, and packet flooding.

---

# Backend Compromise Scenario

The MacEcho security model assumes that backend compromise is possible.

If an attacker gains complete control over backend infrastructure, the attacker may:

• Delay messages.

• Drop messages.

• Reorder packets.

• Disconnect clients.

• Refuse delivery.

However, the attacker must never gain the ability to:

• Read encrypted notifications.

• Read replies.

• Pair unauthorized devices.

• Forge trusted identities.

• Decrypt application traffic.

• Recover private keys.

This assumption significantly strengthens long-term security.

---

# Man-in-the-Middle Protection

All communication assumes that intermediate networks may be hostile.

Potential hostile intermediaries include:

• Public Wi-Fi

• Internet service providers

• Proxy servers

• Corporate gateways

• Compromised routers

MacEcho prevents intermediaries from successfully impersonating trusted devices by requiring cryptographic authentication for every secure communication session.

Possession of network access alone never grants trust.

---

# Device Impersonation Protection

Knowledge of another device's identifier is insufficient to impersonate that device.

An attacker must also possess the corresponding private key.

Since private keys never leave secure storage, device identifiers alone provide no meaningful attack advantage.

---

# Lock Screen Privacy

When the macOS device is locked, MacEcho limits the sensitive information exposed on screen.

While macOS is locked, notifications show only:

• That a notification was received.

• The originating application's icon.

While macOS is locked, notifications hide:

• Notification title.

• Message body.

• Images.

• Attachments.

Quick reply is disabled while macOS is locked.

Sensitive notification content becomes available only after the Mac is unlocked.

This rule applies regardless of the underlying trust and encryption state, since it protects against shoulder-surfing and unattended-device exposure rather than network-level threats.

---

# Session Security

Every communication session begins from an untrusted state.

Authentication establishes trust for that session.

Trust is maintained only while verification remains valid.

Whenever the session ends, temporary session state is discarded.

The next session begins with fresh authentication.

No session inherits trust without verification.

---

# Secure Session Lifecycle

Each communication session follows the same lifecycle.

1. Connection established.

2. Authentication begins.

3. Identity verified.

4. Trust confirmed.

5. Secure communication enabled.

6. Commands exchanged.

7. Session terminates.

8. Temporary session state destroyed.

Each session is treated independently.

---

# Session Management

Pairing is persistent and remains valid until manually revoked.

Communication sessions, in contrast, are temporary and are re-established through automatic reconnection.

Session liveness is monitored using a heartbeat sent every 30 seconds.

A session is considered timed out after 90 seconds without activity.

Reconnection is automatic and follows this timing:

• Initial reconnect delay: 1 second.

• Backoff strategy: exponential.

• Maximum reconnect delay: 30 seconds.

• Random jitter applied to each attempt.

A QR code is required only for:

• Initial pairing.

• Manual unpair.

• Security reset.

Reconnection and re-authentication after normal disconnection never require a new QR code, since the underlying pairing remains valid throughout.

---

# Command Authorization

Authentication confirms identity.

Authorization determines what authenticated devices are permitted to do.

Only authenticated paired devices may execute protected commands.

Unknown devices are never authorized regardless of packet contents.

Future versions may introduce finer-grained permissions without changing the authentication architecture.

---

# Offline Security

MacEcho is designed to remain secure even when one or both devices are temporarily offline.

Temporary loss of connectivity must never weaken the trust relationship between paired devices.

Security decisions are based on cryptographic trust rather than continuous connectivity.

Offline operation is considered a normal operating condition rather than an exceptional event.

---

# Offline Communication

When a device is offline:

• No secure commands are exchanged.

• No trust assumptions are modified.

• No automatic unpairing occurs.

• No new trust relationships may be established.

Previously established trust remains unchanged until proper verification can occur.

---

# Offline Trust

Trust is independent of network connectivity.

A device does not become untrusted simply because it has been offline for an extended period.

Similarly, reconnecting after a long absence does not automatically restore communication.

Every reconnection must undergo trust validation before secure communication resumes.

---

# Backend Failure Recovery

A backend restart does not invalidate pairing.

Devices automatically reconnect once the backend becomes available again.

Sessions automatically re-authenticate as part of normal reconnection.

No QR re-pairing is required.

No user interaction is required.

This behavior is consistent with the principle that trust is owned by paired devices, never by backend infrastructure.

---

# Unpairing Security

Unpairing permanently destroys the trust relationship between paired devices.

Once trust has been removed, future communication requires a completely new pairing process.

Unpairing is irreversible.

Trust cannot be restored using previously generated QR codes, cached session information, or old authentication data.

---

# Local Unpairing

When a user chooses to unpair a device:

• Local trust information is removed.

• Trusted public keys are deleted.

• Session information is destroyed.

• Pairing metadata is removed.

• Future authentication attempts from the previously paired device are rejected.

The device immediately returns to an unpaired state.

---

# Remote Trust Recovery

MacEcho does not support remote restoration of trust.

If trust has been removed from either device, a completely new pairing process is required.

Trust is never recreated automatically.

---

# Trust Revalidation

Whenever two previously paired devices reconnect after being disconnected, they perform trust validation before exchanging application data.

During validation, each device confirms:

• The peer is still trusted.

• The stored public key matches.

• Authentication succeeds.

• Cryptographic identity remains unchanged.

Only after successful validation does secure communication resume.

---

# Handling Asymmetric Unpairing

It is possible for one device to remove trust while the other device remains offline.

Example:

The Android device unpairs.

The Mac remains offline.

When the Mac later reconnects, it attempts to authenticate using its previous trusted relationship.

The Android device rejects authentication because trust no longer exists.

The Mac recognizes that authentication has failed due to trust removal.

It deletes its obsolete trust relationship and returns to the unpaired state.

This ensures both devices eventually converge to the same trust state without requiring backend authority.

---

# Lost Device Scenario

If a trusted device is permanently lost:

The remaining device should be manually unpaired.

This destroys the previous trust relationship.

Any replacement device must complete a completely new pairing process.

Trust never transfers automatically between physical devices.

---

# Destroyed Device Scenario

If one device is physically destroyed before communicating an unpair request:

No security weakness is introduced.

The surviving device may unpair locally.

When the destroyed installation never reconnects, the obsolete trust relationship naturally expires from practical use.

If the destroyed installation is restored from backup or unexpectedly reconnects in the future, authentication will fail because trust has already been removed.

The restored installation must complete a new pairing process before communication can resume.

---

# Application Reinstallation

Reinstalling the application creates a new device identity.

Previous cryptographic identities are not reused.

Previous trust relationships become invalid.

Existing paired devices must reject authentication attempts originating from the new installation until a new pairing process is completed.

---

# Secure Storage Reset

If operating system secure storage is reset:

• Private keys are lost.

• Cryptographic identity changes.

• Previous trust relationships become invalid.

The application must behave as a new installation.

---

# Security Logging

Security-related events may be logged for diagnostic purposes.

Examples include:

• Pairing success.

• Pairing failure.

• Authentication failure.

• Trust validation failure.

• Replay attack detection.

• Invalid signature detection.

Logs must never contain:

• Notification contents.

• Reply contents.

• Private keys.

• Session secrets.

• Encrypted payloads.

Diagnostic information must never compromise user privacy.

---

# Threat Model

The MacEcho security architecture is designed to defend against realistic threats including:

• Packet interception.

• Packet modification.

• Replay attacks.

• Device impersonation.

• Unauthorized pairing attempts.

• Backend compromise.

• Public Wi-Fi interception.

• Malicious network operators.

• Stolen communication logs.

The architecture does not attempt to protect against complete operating system compromise or physical extraction from already-unlocked devices.

Those scenarios fall outside the application's security boundary.

---

# Security Assumptions

The security model assumes:

• Operating system secure storage functions correctly.

• Cryptographic libraries are trustworthy.

• Android Keystore protects private keys.

• Apple Keychain protects private keys.

• Users keep their devices reasonably secure.

• Devices receive operating system security updates.

Violation of these assumptions may weaken application security independently of the application architecture.

---

# Future Security Enhancements

Future versions may introduce additional capabilities such as:

• Multi-device trust management.

• Key rotation.

• Trusted device groups.

• Device trust history.

• Additional authentication factors.

• Security notifications.

• Device approval workflows.

• Administrative trust management.

These enhancements must preserve the security principles established by Version 1.

---

# Security Design Rules

Every future security feature must satisfy the following requirements.

• Never weaken existing trust guarantees.

• Never expose private keys.

• Never require trusting backend infrastructure.

• Never bypass authentication.

• Never reduce user privacy.

• Never introduce undocumented trust relationships.

Security improvements may strengthen the architecture but must never reduce the guarantees already established.

---

# Security Review Checklist

Before approving any feature affecting security, verify the following.

✓ Does it preserve end-to-end encryption?

✓ Does it preserve the trust model?

✓ Does it avoid exposing private keys?

✓ Does it prevent unauthorized pairing?

✓ Does it require new permissions?

✓ Does it increase the attack surface?

✓ Does it preserve user privacy?

✓ Does it remain compatible with existing authentication?

✓ Does it avoid backend trust?

✓ Does it maintain architectural simplicity?

Features failing any of these checks require a formal security review before implementation.

---

# Conclusion

Security within MacEcho is founded upon a simple principle:

**Trust devices—not infrastructure.**

Every component of the system is designed around this philosophy.

Trust is established directly between paired devices, protected through cryptographic identity, preserved using secure local storage, continuously validated during communication, and never delegated to backend services.

By minimizing trust assumptions and clearly separating responsibilities, MacEcho achieves a security architecture that is resilient against compromised networks, compromised infrastructure, and common communication attacks while remaining simple, maintainable, and scalable for future development.

This document serves as the definitive security reference for all current and future implementations of the MacEcho platform.