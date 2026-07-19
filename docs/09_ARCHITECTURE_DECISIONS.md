---
Document: Architecture Decisions
Version: 1.0
Status: Draft
Last Updated: YYYY-MM-DD
Owner: MacEcho Team
Review Required: Yes
---

# Architecture Decisions

# Purpose

This document records the significant architectural decisions made during the design of the MacEcho platform.

Unlike the System Architecture document, which describes how the platform is organized, this document explains why important architectural choices were made.

Documenting these decisions preserves engineering knowledge, reduces repeated discussions, and provides future contributors with the context required to understand the system.

This document should evolve whenever major architectural decisions are introduced or revised.

---

# Scope

This document covers:

• Architectural philosophy

• Technology-neutral design decisions

• Security-related decisions

• Communication decisions

• Product scope decisions

• Development decisions

• Future architectural evolution

Implementation details are intentionally excluded.

---

# Decision-Making Philosophy

Architectural decisions should always be intentional.

Every significant decision should solve a clearly identified problem while introducing the least possible complexity.

Whenever multiple solutions are available, preference should be given to the approach that best satisfies:

• Simplicity.

• Maintainability.

• Security.

• Scalability.

• Reliability.

• Long-term sustainability.

---

# Decision Format

Every architectural decision should document:

• The problem.

• The selected solution.

• The rationale.

• Alternatives considered.

• Consequences.

This ensures future developers understand not only what was chosen, but why it was chosen.

---

# Decision 1

## Title

Native Applications Instead of Cross-Platform Frameworks

---

### Problem

MacEcho requires deep integration with Android system services and macOS operating system capabilities.

The application interacts with notifications, call management, secure storage, background services, and operating system lifecycle events.

---

### Decision

Develop separate native applications for Android and macOS.

---

### Rationale

Native development provides:

• Better operating system integration.

• Lower resource usage.

• Higher reliability.

• Better access to platform-specific APIs.

• Improved long-term maintainability.

---

### Alternatives Considered

Cross-platform frameworks.

Examples include:

• Flutter.

• React Native.

• Electron.

These options simplify code sharing but increase abstraction and reduce direct platform integration.

---

### Consequences

Positive:

• Better platform integration.

• Better performance.

• Native user experience.

Negative:

• Two codebases require maintenance.

The benefits outweigh the additional maintenance effort.

---

# Decision 2

## Title

Backend Relay Instead of Direct Peer-to-Peer Communication

---

### Problem

Android and macOS devices frequently operate behind NATs, firewalls, mobile networks, and changing IP addresses.

Reliable direct connectivity cannot be guaranteed.

---

### Decision

Introduce a lightweight backend relay responsible only for encrypted packet forwarding.

---

### Rationale

The relay provides:

• Reliable connectivity.

• Simplified networking.

• Easier deployment.

• Better recovery after network changes.

The relay does not become part of the trust model.

---

### Alternatives Considered

Direct peer-to-peer communication.

While attractive in theory, it introduces:

• NAT traversal complexity.

• Firewall issues.

• Increased connection failures.

• More complicated recovery logic.

---

### Consequences

Positive:

• Higher reliability.

• Simpler networking.

• Better user experience.

Negative:

• Backend infrastructure becomes required.

Because trust remains end-to-end, the backend does not introduce unacceptable security risk.

---

# Decision 3

## Title

Protocol-First Architecture

---

### Problem

Independent Android, macOS, and backend implementations require a common communication language.

Without a defined protocol, implementations easily diverge.

---

### Decision

Design and document the protocol before implementation begins.

---

### Rationale

Protocol-first development:

• Reduces ambiguity.

• Enables independent implementation.

• Improves testing.

• Simplifies future expansion.

• Encourages loose coupling.

---

### Alternatives Considered

Protocol development during implementation.

This often leads to undocumented assumptions and incompatible implementations.

---

### Consequences

Positive:

• Consistent communication.

• Better documentation.

• Easier maintenance.

Negative:

• Longer planning phase.

The reduced implementation risk justifies the additional planning effort.

---

# Decision 4

## Title

Documentation Before Development

---

### Problem

Software projects often accumulate undocumented assumptions, leading to inconsistent implementation and difficult maintenance.

---

### Decision

Complete core architectural documentation before beginning production development.

---

### Rationale

Documentation-first development:

• Establishes shared understanding.

• Reduces architectural drift.

• Simplifies onboarding.

• Supports long-term maintenance.

---

### Alternatives Considered

Writing documentation after implementation.

This frequently results in incomplete or outdated documentation.

---

### Consequences

Positive:

• Clear implementation guidance.

• Reduced ambiguity.

• Better project organization.

Negative:

• Longer initial planning.

The long-term benefits significantly outweigh the initial investment.

---

# Decision 5

## Title

End-to-End Encryption for All Application Communication

---

### Problem

MacEcho transmits sensitive user information, including notifications, notification replies, call events, and device commands.

Since communication passes through a backend relay, user data must remain confidential even if the relay infrastructure is compromised.

---

### Decision

All application data shall be protected using end-to-end encryption.

The backend will only transport encrypted packets and will never possess the ability to decrypt application data.

---

### Rationale

End-to-end encryption ensures:

• User privacy.

• Backend neutrality.

• Protection against infrastructure compromise.

• Secure communication over untrusted networks.

This approach aligns with the principle that only trusted devices should have access to user information.

---

### Alternatives Considered

Transport-layer encryption (TLS) without application-layer encryption.

Although TLS protects data during transmission, the backend would still be able to read decrypted payloads.

---

### Consequences

Positive:

• Strong privacy guarantees.

• Backend cannot inspect user data.

• Reduced trust requirements for infrastructure.

Negative:

• Increased implementation complexity.

The security benefits outweigh the additional engineering effort.

---

# Decision 6

## Title

QR Code-Based Device Pairing

---

### Problem

Users require a simple and secure method to establish trust between Android and macOS devices without manually exchanging cryptographic information.

---

### Decision

Use a time-limited QR code to bootstrap the pairing process.

The QR code establishes communication only and never represents trust by itself.

---

### Rationale

QR-based pairing:

• Requires physical user presence.

• Eliminates manual configuration.

• Reduces user error.

• Enables rapid onboarding.

• Simplifies first-time setup.

---

### Alternatives Considered

• Manual pairing codes.

• Password-based pairing.

• Bluetooth discovery.

• Automatic LAN discovery.

Each alternative either reduces usability, weakens security, or increases implementation complexity.

---

### Consequences

Positive:

• Fast pairing experience.

• Strong user intent verification.

• Minimal configuration.

Negative:

• Requires camera access on Android.

This trade-off is acceptable given the significant usability improvements.

---

# Decision 7

## Title

Permanent Trust with Temporary Sessions

---

### Problem

Authentication must occur repeatedly while avoiding repeated pairing.

---

### Decision

Trust established during pairing remains persistent, while communication sessions remain temporary and disposable.

---

### Rationale

Separating trust from sessions provides:

• Better recovery after interruptions.

• Simpler authentication.

• Improved resilience.

• Reduced user friction.

Users should not repeat the pairing process after every application restart or network interruption.

---

### Alternatives Considered

Creating trust during every connection attempt.

This would significantly reduce usability and unnecessarily complicate normal operation.

---

### Consequences

Positive:

• Faster reconnection.

• Improved user experience.

• Simplified session management.

Negative:

• Permanent trust records require secure local storage.

---

# Decision 8

## Title

Local Trust Instead of Cloud Trust

---

### Problem

The system must determine whether two devices trust each other.

A centralized trust database introduces additional privacy and security concerns.

---

### Decision

Trust records shall exist only on the paired Android and macOS devices.

The backend will not store or manage trust relationships.

---

### Rationale

Local trust:

• Preserves user privacy.

• Eliminates centralized trust databases.

• Prevents backend compromise from affecting trust.

• Maintains end-to-end security.

---

### Alternatives Considered

Cloud-managed trust relationships.

Although this simplifies account management, it introduces unnecessary infrastructure complexity and increases the attack surface.

---

### Consequences

Positive:

• Better privacy.

• Reduced backend responsibility.

• Stronger security model.

Negative:

• Reinstalling an application requires re-pairing.

The simplicity and privacy benefits outweigh this inconvenience.

---

# Decision 9

## Title

Single Android Device Paired with a Single macOS Device in Version 1

---

### Problem

Supporting multiple paired devices significantly increases synchronization complexity, routing logic, conflict resolution, and user interface requirements.

---

### Decision

Version 1 supports one trusted Android device paired with one trusted macOS device.

One phone pairs with one Mac.

One Mac pairs with one phone.

A new pairing replaces the existing trust relationship, or requires explicit unpairing if a trust relationship already exists.

Multi-device pairing is out of scope for Version 1.

---

### Rationale

Limiting the scope:

• Simplifies implementation.

• Reduces testing complexity.

• Produces a more stable initial release.

• Allows future expansion without architectural changes.

---

### Alternatives Considered

Supporting multiple Android devices or multiple desktop devices from the initial release.

While technically feasible, this would substantially increase development time and project risk.

---

### Consequences

Positive:

• Simpler protocol.

• Easier testing.

• Lower maintenance burden.

Negative:

• Limited flexibility in Version 1.

The architecture remains extensible for future multi-device support.

---

# Decision 10

## Title

Menu Bar Utility Instead of Traditional Desktop Application

---

### Problem

MacEcho is intended to function as a background companion rather than a primary productivity application.

Launching a large desktop window for routine interactions would interrupt the user's workflow.

---

### Decision

Implement MacEcho as a lightweight menu bar application.

---

### Rationale

A menu bar utility:

• Remains easily accessible.

• Consumes minimal screen space.

• Supports background operation.

• Aligns with common macOS interaction patterns.

• Reduces unnecessary interface complexity.

---

### Alternatives Considered

A traditional desktop application with a permanent main window.

Although this allows additional interface space, it is unnecessary for the Version 1 feature set.

---

### Consequences

Positive:

• Cleaner user experience.

• Faster interactions.

• Better integration with macOS.

Negative:

• Limited interface space for future features.

If future functionality requires more complex workflows, additional windows can be introduced without changing the underlying architecture.

---

# Decision 11

## Title

Modular Architecture Over Monolithic Design

---

### Problem

As MacEcho evolves, new features such as file transfer, clipboard synchronization, multi-device support, and battery monitoring will increase system complexity.

A tightly coupled architecture would make future enhancements difficult and increase the risk of regressions.

---

### Decision

Design the platform as a collection of well-defined, loosely coupled modules with clear responsibilities.

Each module should expose only the interfaces required by other components.

---

### Rationale

A modular architecture provides:

• Better maintainability.

• Easier testing.

• Improved scalability.

• Reduced coupling.

• Independent feature development.

---

### Alternatives Considered

A monolithic implementation where components directly depend on each other.

Although initially simpler, this approach becomes increasingly difficult to maintain as the project grows.

---

### Consequences

Positive:

• Easier future expansion.

• Reduced maintenance effort.

• Improved code organization.

Negative:

• Requires greater architectural discipline.

The long-term benefits significantly outweigh the additional design effort.

---

# Decision 12

## Title

Semantic Versioning for Releases

---

### Problem

As the project evolves, developers and users require a predictable method for understanding the impact of new releases.

Without a structured versioning strategy, compatibility expectations become unclear.

---

### Decision

Adopt Semantic Versioning (MAJOR.MINOR.PATCH) for all public releases.

---

### Rationale

Semantic Versioning provides:

• Clear expectations.

• Predictable upgrade paths.

• Better dependency management.

• Easier release planning.

---

### Alternatives Considered

Date-based versions or arbitrary version numbers.

While simple to generate, they communicate little about compatibility or change impact.

---

### Consequences

Positive:

• Clear release communication.

• Easier maintenance.

• Better ecosystem compatibility.

Negative:

• Requires disciplined release management.

---

# Decision 13

## Title

Documentation as a First-Class Project Artifact

---

### Problem

Documentation frequently becomes outdated when treated as an optional activity after implementation.

This creates confusion and increases onboarding time for future contributors.

---

### Decision

Treat documentation with the same importance as source code.

Any architectural, protocol, security, or product change must be reflected in the corresponding documentation before the work is considered complete.

---

### Rationale

Documentation-first maintenance:

• Preserves architectural knowledge.

• Reduces ambiguity.

• Improves collaboration.

• Supports long-term sustainability.

---

### Alternatives Considered

Maintaining documentation only for major releases.

This often results in documentation lagging behind implementation.

---

### Consequences

Positive:

• Consistently accurate documentation.

• Faster onboarding.

• Better maintainability.

Negative:

• Slightly higher development overhead.

The long-term reduction in maintenance cost justifies the additional effort.

---

# Decision 14

## Title

Backend Technology Stack

---

### Problem

The backend relay requires a concrete, agreed-upon technology stack before implementation can begin.

---

### Decision

The official backend stack for Version 1 is:

• Runtime: Node.js (LTS).

• Language: TypeScript.

• Framework: Fastify.

---

### Rationale

This stack provides:

• Strong compatibility with realtime, connection-heavy relay workloads.

• Type safety through TypeScript, reducing runtime errors.

• A lightweight, high-performance framework in Fastify.

• A large ecosystem and long-term maintainability.

---

### Alternatives Considered

Other backend languages and frameworks were considered.

These alternatives did not offer a clear advantage over the chosen stack for a lightweight relay service and would introduce unnecessary variation from the team's existing expertise.

---

### Consequences

Positive:

• Consistent, well-supported stack.

• Strong tooling and type safety.

• Suitable for realtime relay workloads.

Negative:

• Ties backend implementation to the Node.js ecosystem.

This tradeoff is acceptable given the backend's limited, well-defined responsibilities.

---

# Decision 15

## Title

Communication Transport

---

### Problem

Android, macOS, and the backend require a concrete transport mechanism capable of realtime, bidirectional, persistent communication.

---

### Decision

MacEcho uses a persistent WebSocket connection for communication between each client and the backend relay.

The transport provides:

• Bidirectional communication.

• Ping/Pong heartbeat.

• Automatic reconnection.

• Session recovery.

• Encrypted packets transmitted over the WebSocket connection.

---

### Rationale

WebSocket connections:

• Support realtime, low-latency, bidirectional delivery.

• Maintain a persistent connection suited to a relay architecture.

• Are widely supported across native platform networking libraries.

• Allow heartbeat and reconnection logic to be layered on top of a single connection type.

---

### Alternatives Considered

Repeated HTTP polling or long-polling were considered.

These approaches introduce higher latency and unnecessary overhead compared to a persistent WebSocket connection.

---

### Consequences

Positive:

• Low-latency realtime delivery.

• Simplified connection model.

• Native support for reconnection and heartbeat patterns.

Negative:

• Requires explicit reconnection and session recovery handling.

This is addressed directly by the Session Management decision and the Protocol Specification.

---

# Decision 16

## Title

Cryptographic Algorithm Selection

---

### Problem

The Security Model and Protocol Specification require concrete, agreed-upon cryptographic primitives before implementation can begin.

---

### Decision

MacEcho uses the following cryptographic algorithms. These algorithms are mandatory for Version 1.

• Key Exchange: X25519.

• Digital Signatures: Ed25519.

• Symmetric Encryption: AES-256-GCM.

• Key Derivation: HKDF-SHA256.

• Hash Algorithm: SHA-256.

---

### Rationale

These algorithms:

• Are widely reviewed, modern, and well-supported across Android and macOS cryptographic libraries.

• Provide strong security guarantees consistent with the principles defined in the Security Model.

• Allow consistent, interoperable implementation across both native applications.

---

### Alternatives Considered

Other cryptographic primitives, including RSA-based key exchange and signatures, were considered.

Elliptic-curve primitives were preferred for their smaller key sizes, strong security margins, and better performance on mobile hardware.

---

### Consequences

Positive:

• Consistent, interoperable cryptography across platforms.

• Strong, modern security guarantees.

Negative:

• Requires both native applications to use libraries supporting these exact primitives.

This requirement is considered acceptable given the security-critical nature of the application.

---

# Decision 17

## Title

Packet Serialization Format

---

### Problem

The Protocol Specification requires a concrete serialization format for packet contents.

---

### Decision

All protocol packets are serialized using JSON.

---

### Rationale

JSON:

• Is human-readable, simplifying debugging and diagnostics.

• Is natively supported across Node.js, Kotlin/Java, and Swift toolchains.

• Is sufficiently compact for the message sizes MacEcho handles.

---

### Alternatives Considered

Binary serialization formats, such as Protocol Buffers, were considered.

These formats offer smaller payload sizes but introduce additional tooling and schema-compilation overhead not currently justified by MacEcho's message volume.

---

### Consequences

Positive:

• Simple, debuggable, broadly supported format.

Negative:

• Larger payload size compared to binary formats.

This tradeoff is acceptable given MacEcho's message sizes and the Maximum Packet Size defined under Backend Rate Limiting.

---

# Decision 18

## Title

Secure Key Storage Architecture

---

### Problem

Private keys and trust metadata must be stored securely and consistently across Android, macOS, and the backend.

---

### Decision

Android stores private keys in the Android Keystore.

Android stores trusted device metadata in encrypted local storage.

macOS stores private keys in the Apple Keychain.

macOS stores trusted device metadata in encrypted local storage.

The backend stores only:

• Public keys.

• Session metadata.

• Routing metadata.

The backend never stores:

• Private keys.

• Shared secrets.

• Decrypted payloads.

---

### Rationale

This architecture:

• Keeps the highest-sensitivity material inside operating-system-provided secure storage.

• Keeps the backend's stored data limited to information that carries no confidentiality risk if exposed.

• Is directly consistent with the trust model defined in the Security Model.

---

### Alternatives Considered

Storing trust metadata inside the same secure enclave as private keys was considered.

Separating metadata into encrypted local storage was preferred, since metadata does not require hardware-backed key storage and benefits from simpler access patterns.

---

### Consequences

Positive:

• Clear separation between highest-sensitivity and lower-sensitivity data.

• Reduced impact of backend compromise.

Negative:

• Requires maintaining two storage mechanisms per client platform.

This is consistent with the existing Local Trust Instead of Cloud Trust decision.

---

# Decision 19

## Title

Backend Rate Limiting

---

### Problem

The backend relay is internet-facing and requires protection against connection abuse, authentication abuse, and packet flooding.

---

### Decision

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

---

### Rationale

Rate limiting:

• Reduces the impact of denial-of-service attempts.

• Limits brute-force pairing and authentication attempts.

• Protects backend resources from packet flooding.

---

### Alternatives Considered

Operating without explicit rate limits was considered and rejected, since the backend is directly internet-facing and Version 1 defines no alternative abuse protection.

---

### Consequences

Positive:

• Reduced abuse surface.

• More predictable backend resource usage.

Negative:

• Legitimate users on shared networks may occasionally encounter connection limits.

Initial limits may be tuned after Version 1 release based on observed usage.

---

# Decision 20

## Title

Android Call Detection Strategy

---

### Problem

Android provides multiple APIs for detecting call state, with different capability and approval requirements.

---

### Decision

On Android 12 and above, MacEcho uses TelephonyCallback.

On older supported Android versions, MacEcho uses PhoneStateListener.

MacEcho detects:

• Incoming calls.

• Outgoing calls.

• Answered calls.

• Ended calls.

MacEcho is not a replacement dialer.

MacEcho does not use InCallService or CallScreeningService.

---

### Rationale

TelephonyCallback and PhoneStateListener:

• Provide sufficient call-state visibility for MacEcho's Version 1 feature set.

• Do not require MacEcho to register as a default or system dialer companion.

• Avoid the additional OEM approval and role-management requirements associated with InCallService and CallScreeningService.

---

### Alternatives Considered

Using InCallService to gain deeper call control was considered.

This was rejected for Version 1, since it would require MacEcho to participate in the default phone/dialer role, which conflicts with the goal of remaining a lightweight companion application.

---

### Consequences

Positive:

• Simpler permission and approval requirements.

• Consistent with MacEcho's role as a companion application, not a dialer replacement.

Negative:

• Reduced call-control capability compared to InCallService.

This is acceptable, since Version 1 call features are limited to Accept, Decline, and status display, as defined in the Product Requirements.

---

# Decision 21

## Title

Minimum Supported Operating Systems

---

### Problem

The Product Requirements previously left minimum supported operating system versions unresolved.

---

### Decision

Android minimum supported version: Android 10 (API 29).

macOS minimum supported version: macOS 13 Ventura.

---

### Rationale

These minimums:

• Provide access to the notification, call-detection, and secure-storage APIs required by MacEcho.

• Cover a substantial portion of actively used devices on each platform.

• Avoid the added complexity of supporting significantly older, less capable operating system APIs.

---

### Alternatives Considered

Supporting older operating system versions was considered and rejected, since it would require additional compatibility handling for APIs that MacEcho's core features depend upon.

---

### Consequences

Positive:

• Access to modern, required platform APIs.

• Reduced compatibility testing burden.

Negative:

• Users on older operating systems cannot use MacEcho.

This tradeoff is acceptable given MacEcho's reliance on modern notification and security APIs.

---

# Decision Review Process

Architectural decisions should not be changed casually.

Every proposed modification should answer the following questions:

• What problem exists today?

• Why is the current decision no longer appropriate?

• What benefits does the proposed change provide?

• What new risks are introduced?

• Which documents require updates?

• Will the protocol remain compatible?

• Will existing implementations continue to function correctly?

Only after these questions have been evaluated should an architectural decision be revised.

---

# Recording Future Decisions

Future architectural decisions should follow the same structure used throughout this document.

Each new decision should include:

1. Title

2. Problem

3. Decision

4. Rationale

5. Alternatives Considered

6. Consequences

Maintaining a consistent structure simplifies future reviews and historical analysis.

---

# Decision Lifecycle

Every architectural decision progresses through the following lifecycle:

Proposed

↓

Reviewed

↓

Approved

↓

Implemented

↓

Documented

↓

Maintained

↓

Revisited (if necessary)

Architectural decisions should evolve deliberately rather than reactively.

---

# Architecture Review Checklist

Before approving a significant architectural change, verify:

✓ The problem is clearly defined.

✓ The proposed solution addresses the identified problem.

✓ Alternative approaches have been evaluated.

✓ Security implications have been reviewed.

✓ Performance implications have been considered.

✓ Scalability has been assessed.

✓ Maintainability has been evaluated.

✓ Documentation updates have been identified.

✓ Backward compatibility has been reviewed.

✓ Long-term consequences are understood.

No architectural decision should be accepted without completing this review.

---

# Guiding Principles

Every future architectural decision should remain consistent with the core principles established for MacEcho.

Those principles are:

• Simplicity over unnecessary complexity.

• Security before convenience.

• Reliability before optimization.

• Native platform experience.

• Privacy by design.

• Loose coupling.

• Clear documentation.

• Incremental evolution.

These principles serve as the foundation for all future development.

---

# Conclusion

The Architecture Decisions document preserves the engineering rationale behind the MacEcho platform.

While the System Architecture defines how the platform is structured, this document explains why those structures, technologies, workflows, and design patterns were chosen.

By recording architectural reasoning alongside implementation guidance, MacEcho becomes easier to maintain, extend, and evolve over time.

Future contributors should consult this document before introducing significant architectural changes to ensure that new decisions remain consistent with the project's long-term vision and guiding principles.

This document serves as the authoritative record of architectural intent for the MacEcho project.

---