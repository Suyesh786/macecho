---
Document: Implementation Plan
Version: 1.0
Status: Draft
Last Updated: YYYY-MM-DD
Owner: MacEcho Team
Review Required: Yes
---

# Implementation Plan

# Purpose

This document is the authoritative execution guide for building MacEcho from an empty repository to a complete Version 1 release.

The Development Roadmap defines what must be built and in what order, at a milestone level.

This Implementation Plan defines exactly how development proceeds, broken into small, independently verifiable phases.

Any coding agent — human or AI — should be able to open this document, identify the next incomplete phase, and know precisely what to build, how to verify it, and when to stop.

---

# Scope

This document covers:

• The complete phase-by-phase implementation sequence for Version 1.

• Dependencies between phases.

• Acceptance criteria and internal verification for each phase.

• Coding philosophy for agents implementing MacEcho.

• Assumptions that require confirmation before implementation begins.

This document does not contain implementation code, does not redefine product requirements, and does not alter any architectural, security, or protocol decision already recorded elsewhere in this repository.

---

# Relationship To Other Documents

This plan must remain fully consistent with:

• 00_PROJECT_OVERVIEW.md

• 01_MASTER_CONTEXT.md

• 02_PRODUCT_REQUIREMENTS.md

• 03_SYSTEM_ARCHITECTURE.md

• 04_SECURITY_MODEL.md

• 05_EDGE_CASES.md

• 06_UI_GUIDELINES.md

• 07_PROTOCOL_SPECIFICATION.md

• 08_DEVELOPMENT_ROADMAP.md

• 09_ARCHITECTURE_DECISIONS.md

• 10_TESTING_SPECIFICATION.md

If any instruction in this document appears to conflict with one of the documents above, the other document takes precedence, and implementation must stop until the conflict is resolved.

---

# Assumptions Requiring Confirmation

The following implementation-level details are not explicitly pinned by existing documentation. This plan proceeds using the stated assumption. A coding agent encountering evidence that contradicts these assumptions must stop and request clarification rather than proceeding.

• Android application language: Kotlin, using standard Android Gradle tooling. This follows from the "Native Applications Instead of Cross-Platform Frameworks" decision but is not explicitly named in 09_ARCHITECTURE_DECISIONS.md.

• macOS application language and UI framework: Swift, using AppKit for the menu bar utility (NSStatusItem) and SwiftUI for popover content. This follows from the same native-applications decision but is not explicitly named.

• Backend hosting and deployment infrastructure (hosting provider, container strategy, scaling configuration) is not defined anywhere in the repository. This plan treats backend deployment as a Phase 26 open item requiring a decision before Version 1 release, not as a blocker for earlier phases.

These assumptions do not affect protocol wire behavior, cryptography, or security guarantees, all of which are fully pinned by 04_SECURITY_MODEL.md, 07_PROTOCOL_SPECIFICATION.md, and 09_ARCHITECTURE_DECISIONS.md.

---

# Coding Philosophy

Every coding agent working on MacEcho must follow these principles throughout the entire project.

• Never invent undocumented behavior. If a decision is not written in the documentation, stop and ask rather than guess.

• Follow the architecture, security, and protocol documents exactly. Do not "improve" on documented decisions during implementation.

• Keep commits focused. One phase, or one task within a phase, per logical commit wherever practical.

• Keep implementations modular, matching the component boundaries defined in 03_SYSTEM_ARCHITECTURE.md.

• Prefer readable code over clever code. MacEcho prioritizes long-term maintainability over cleverness or brevity.

• Stop when uncertainty becomes architectural rather than implementation-related. Naming a variable is an implementation decision. Choosing a retry limit that isn't documented is architectural — stop and ask.

• Never modify documentation unless implementation reveals a genuine inconsistency, and never modify documentation silently — flag the inconsistency explicitly before changing anything.

• Never implement future-version features. Anything listed under "Explicitly Out of Scope" in 02_PRODUCT_REQUIREMENTS.md must not be built, even partially, even as a convenience.

• Never begin a later phase while an earlier phase remains incomplete, unverified, or has known blocking issues.

---

# Phase Design Principles

• Phases are kept small and independently testable rather than large and multi-purpose.

• Phases are kept independent of each other wherever the architecture allows it.

• Unrelated features are never combined into a single phase.

• Foundational work always precedes functionality. Functionality always precedes optimization. Optimization always precedes polishing.

• Every phase produces a working, buildable project — never a partially-wired, broken intermediate state left unresolved at the phase boundary.

---

# Internal Verification (Applies To Every Phase)

Before a coding agent considers any phase complete, it must verify:

• Does the project build?

• Does the project compile without warnings introduced by this phase's changes?

• Are there obvious bugs?

• Does the implementation match the documentation exactly?

• Are all acceptance criteria for this phase satisfied?

• Has unnecessary code been introduced?

• Has the architecture been respected — no boundary violations, no skipped layers?

If any uncertainty exists at the end of a phase, the coding agent must explicitly state:

• What is uncertain.

• Why it is uncertain.

• What assumption would be required to continue.

The coding agent must never silently guess an architectural or product decision to make a phase "pass."

---

# The One-Phase Rule

Development occurs one phase at a time.

A coding agent must never begin work on a later phase until the current phase is fully implemented, builds successfully, has been reviewed internally, has been verified against the documentation, and is free of known blocking issues.

Attempting multiple phases within a single implementation session is strongly discouraged, even when a phase appears simple.

Every phase ends with an explicit stop. The next phase begins only when explicitly requested.

---

# Phase Index

1. Repository Foundation

2. Development Environment

3. Backend Foundation

4. Android Foundation

5. macOS Foundation

6. Shared Protocol Data Contracts

7. WebSocket Transport Layer

8. Cryptographic Primitives

9. Secure Key Storage

10. Packet Serialization and Validation Pipeline

11. Replay Protection and Sequencing

12. QR Pairing Protocol

13. Authentication and Session Establishment

14. Backend Relay and Rate Limiting

15. Session Recovery and Reconnection

16. Android Notification Listener Integration

17. Notification Synchronization (End-to-End)

18. Notification Detail View (macOS)

19. Notification Reply

20. Lock Screen Privacy

21. Call Management

22. Ring Phone

23. Full System Integration

24. Automated Testing

25. Manual Validation and Stabilization

26. Version 1 Release Preparation

---

# Phase 1

## Goal

Establish the empty repository's structure, conventions, and non-negotiable ground rules before any code is written.

## Why This Phase Exists

Every later phase assumes a consistent repository layout and contribution convention. Establishing this first prevents structural rework later.

## Dependencies

None. This is the first phase.

## Estimated Complexity

Small

## Estimated AI Coding Sessions

1 Session

## Tasks

1. Create the top-level repository structure matching 00_PROJECT_OVERVIEW.md: `docs/`, `android/`, `macos/`, `backend/`, `shared/`, `assets/`.

2. Move all existing numbered documentation files into `docs/`.

3. Create a root `README.md` summarizing the project and pointing to `docs/00_PROJECT_OVERVIEW.md`.

4. Create a root `.gitignore` covering Node.js, Android/Gradle, and Xcode build artifacts.

5. Define and document the branch strategy (for example: `main` protected, feature branches per phase).

6. Add a `LICENSE` file if one has been decided; if not, flag this as an open item rather than guessing.

7. Record the coding conventions referenced in this plan (Coding Philosophy section) as a `CONTRIBUTING.md`.

## Files or Modules Expected

• `README.md`

• `.gitignore`

• `CONTRIBUTING.md`

• `docs/` (containing all existing numbered documents)

• Empty `android/`, `macos/`, `backend/`, `shared/`, `assets/` directories with placeholder `.gitkeep` or equivalent.

## Acceptance Criteria

• Repository structure matches 00_PROJECT_OVERVIEW.md exactly.

• All ten (now eleven, including this document) documentation files exist under `docs/`.

• No source code exists yet — this phase is structural only.

## Internal Verification Checklist

✓ Directory structure matches documentation.

✓ No application code was written during this phase.

✓ README accurately describes the project without inventing undocumented features.

## Common Mistakes

• Creating source folders before this phase's structure is agreed upon.

• Writing placeholder application code "to get started early."

• Inventing a license or legal terms not provided by the project owner.

## Deliverables

An empty, well-structured repository containing only documentation, configuration, and contribution guidelines.

## Recommended Git Commit

`chore(repo): initialize repository structure`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 2. Because this is the first phase, there is no previous known-good commit to restore to — fix the issue directly in place, then re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 2 automatically. Phase 2 should only begin when explicitly requested.

---

# Phase 2

## Goal

Establish working development environments and toolchains for all three components without writing application logic.

## Why This Phase Exists

Backend, Android, and macOS development each require a working local toolchain before any feature work can begin. Verifying this early avoids blocking later phases on environment issues.

## Dependencies

Phase 1 complete.

## Estimated Complexity

Small

## Estimated AI Coding Sessions

1 Session

## Tasks

1. Initialize the backend as a Node.js (LTS) project using TypeScript and Fastify, per Architecture Decision 14.

2. Configure backend linting, formatting, and TypeScript strict mode.

3. Initialize the Android project using Kotlin and standard Gradle tooling (see Assumptions Requiring Confirmation).

4. Initialize the macOS project as a Swift menu bar application target (see Assumptions Requiring Confirmation).

5. Verify each project builds an empty "hello world" equivalent successfully.

6. Document how to run each project locally in `CONTRIBUTING.md`.

## Files or Modules Expected

• `backend/package.json`, `backend/tsconfig.json`, `backend/src/`

• `android/` Gradle project skeleton

• `macos/` Xcode project skeleton

• Updates to `CONTRIBUTING.md`

## Acceptance Criteria

• Backend project builds and runs an empty Fastify server.

• Android project builds an empty app shell.

• macOS project builds an empty menu bar app shell.

• No business logic exists in any project yet.

## Internal Verification Checklist

✓ All three projects build from a clean checkout.

✓ No networking, cryptography, or UI logic beyond an empty shell exists.

✓ Toolchain versions are documented.

## Common Mistakes

• Adding dependencies not required by any documented decision.

• Beginning UI work before Phase 4 / Phase 5.

• Skipping strict TypeScript configuration, which later phases rely on for packet-type safety.

## Deliverables

Three independently buildable, empty project skeletons and documented local setup instructions.

## Recommended Git Commit

`chore(env): configure development environment`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 3. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 1, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 3 automatically. Phase 3 should only begin when explicitly requested.

---

# Phase 3

## Goal

Implement the backend as a minimal, running relay skeleton with no protocol logic.

## Why This Phase Exists

The backend must exist as a running service before transport, authentication, or relay logic can be layered on top of it, per the Backend Relay responsibilities in 03_SYSTEM_ARCHITECTURE.md.

## Dependencies

Phase 2 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Implement a Fastify HTTP server with a basic health-check endpoint.

2. Add structured logging, ensuring logs never contain notification content, reply content, private keys, session secrets, or encrypted payloads, per the Security Logging rules in 04_SECURITY_MODEL.md.

3. Add basic process configuration (environment variables, port configuration).

4. Confirm the backend still performs no decryption, no trust storage, and no business logic, per the Backend Security Limitations in 04_SECURITY_MODEL.md.

## Files or Modules Expected

• `backend/src/server.ts`

• `backend/src/logging/`

• `backend/src/config/`

## Acceptance Criteria

• Backend starts and responds to a health-check request.

• Logging is structured and excludes sensitive fields by construction.

• No WebSocket, cryptography, or relay logic exists yet.

## Internal Verification Checklist

✓ Backend builds and starts successfully.

✓ Health-check endpoint responds correctly.

✓ Logging configuration cannot accidentally log payload contents.

## Common Mistakes

• Adding WebSocket handling early, before Phase 7.

• Logging full request bodies, which risks violating the Security Logging rules.

## Deliverables

A minimal, running backend service with health-check and logging only.

## Recommended Git Commit

`feat(backend): implement backend foundation`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 4. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 2, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 4 automatically. Phase 4 should only begin when explicitly requested.

---

# Phase 4

## Goal

Implement the Android application as a minimal running shell with no operating system integrations yet.

## Why This Phase Exists

The Android application needs a stable shell — application lifecycle, navigation scaffold, and settings scaffold — before Notification Listener, call detection, or cryptography can be added.

## Dependencies

Phase 2 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Implement the base Application class and a single home Activity/Composable matching the Android Home Screen layout described in 06_UI_GUIDELINES.md (status placeholders only, no live data).

2. Implement an empty Settings screen scaffold matching the sections listed in 06_UI_GUIDELINES.md (Permissions, Connection, Notifications, About, Privacy).

3. Add no permission requests yet — only the navigation scaffold.

4. Confirm the app builds and launches on a minimum Android 10 (API 29) target, per Architecture Decision 21.

## Files or Modules Expected

• `android/app/src/main/...` home screen and settings scaffold

• No networking, storage, or permission-handling code yet

## Acceptance Criteria

• App builds and launches showing static placeholder status.

• Settings screen scaffold exists with the documented sections, no functionality behind them.

• Minimum SDK is set to API 29.

## Internal Verification Checklist

✓ App builds and installs on a device or emulator at the minimum supported API level.

✓ No notification, call, or network permissions are requested yet.

✓ UI matches the structure described in 06_UI_GUIDELINES.md, not final visual design (visual design system is a separate, undocumented concern — flag if blocking).

## Common Mistakes

• Requesting permissions before the features that need them exist.

• Wiring real connection status before pairing exists.

## Deliverables

A minimal, installable Android application shell with static screens matching the documented structure.

## Recommended Git Commit

`feat(android): implement android foundation`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 5. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 3, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 5 automatically. Phase 5 should only begin when explicitly requested.

---

# Phase 5

## Goal

Implement the macOS application as a minimal running menu bar shell with no operating system integrations yet.

## Why This Phase Exists

The macOS application needs a stable menu bar presence and popover scaffold before pairing, notifications, or call handling can be added.

## Dependencies

Phase 2 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Implement an NSStatusItem-based menu bar icon that opens an empty popover instantly, with no splash screen, per 06_UI_GUIDELINES.md.

2. Implement the popover's default home screen scaffold listing the documented menu items (Device status, Connected device, Generate QR, Ring phone, Unpair device, Launch at login, About, Quit) as inert placeholders.

3. Implement the Quit action only, since it requires no other feature.

4. Confirm the app builds and runs on a minimum macOS 13 Ventura target, per Architecture Decision 21.

## Files or Modules Expected

• `macos/MacEcho/` app shell, status item controller, popover scaffold

## Acceptance Criteria

• App builds and shows a working menu bar icon.

• Clicking the icon opens the popover instantly with no splash screen.

• Quit works. All other menu items are visibly present but inert.

## Internal Verification Checklist

✓ App builds and runs on macOS 13+.

✓ Popover opens instantly on click.

✓ No pairing, notification, or call logic exists yet.

## Common Mistakes

• Adding a splash screen, which 06_UI_GUIDELINES.md explicitly forbids.

• Wiring "Generate QR" before Phase 12 exists.

## Deliverables

A minimal, running macOS menu bar application shell matching the documented structure.

## Recommended Git Commit

`feat(macos): implement macos foundation`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 6. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 4, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 6 automatically. Phase 6 should only begin when explicitly requested.

---

# Phase 6

## Goal

Define the shared protocol data contracts (packet structure and command shapes) as concrete types, with no networking or cryptography behavior yet.

## Why This Phase Exists

Every later networking phase depends on a single, consistent definition of packet structure. Defining this once, and independently of transport or crypto, prevents drift between the three codebases.

## Dependencies

Phase 3, Phase 4, and Phase 5 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Define the Universal Packet Structure (Header, Metadata, Encrypted Payload) from 07_PROTOCOL_SPECIFICATION.md as TypeScript types in `backend/`, matching structures in `shared/` documentation for reference.

2. Define equivalent Kotlin data classes in `android/` and Swift structs in `macos/`.

3. Include all header fields: protocol version, packet type, session identifier, sender identifier, Packet UUID, Session Sequence Number, Timestamp.

4. Define the packet categories from 07_PROTOCOL_SPECIFICATION.md: Authentication Packets, Pairing Packets, Application Command Packets, Acknowledgement Packets.

5. Define JSON as the serialization format for all packet types, per Architecture Decision 17.

6. Write unit tests verifying JSON encode/decode round-trips for every packet type, per the Serialization section of 10_TESTING_SPECIFICATION.md.

## Files or Modules Expected

• `backend/src/protocol/packets.ts`

• `android/.../protocol/Packets.kt`

• `macos/.../Protocol/Packets.swift`

• `shared/protocol/` reference documentation (non-code) if useful for cross-team clarity

## Acceptance Criteria

• Packet types exist consistently across all three codebases.

• JSON round-trip unit tests pass for every packet type.

• No field beyond those documented in 07_PROTOCOL_SPECIFICATION.md is introduced.

## Internal Verification Checklist

✓ Field names and types match 07_PROTOCOL_SPECIFICATION.md exactly.

✓ No transport, cryptography, or business logic is present in this phase.

✓ Unit tests cover every documented packet category.

## Common Mistakes

• Inventing extra fields "for future use." Only documented fields belong here.

• Implementing encryption inline with serialization — these remain separate concerns until Phase 10.

## Deliverables

Consistent, tested packet data contracts across backend, Android, and macOS.

## Recommended Git Commit

`feat(protocol): define shared packet contracts`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 7. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 5, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 7 automatically. Phase 7 should only begin when explicitly requested.

---

# Phase 7

## Goal

Implement the WebSocket transport layer with heartbeat and reconnection, carrying opaque data only.

## Why This Phase Exists

07_PROTOCOL_SPECIFICATION.md defines the Transport Layer as understanding delivery only, not meaning. Implementing this in isolation, before authentication or encryption exist, keeps the layering clean.

## Dependencies

Phase 6 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

2 Sessions

## Tasks

1. Implement a WebSocket server endpoint in the backend, per Architecture Decision 15.

2. Implement WebSocket client connection logic in Android and macOS.

3. Implement Ping/Pong heartbeat with a 30-second interval, per Architecture Decision 7 and 04_SECURITY_MODEL.md Session Management.

4. Implement a 90-second connection timeout.

5. Implement automatic reconnection with 1-second initial delay, exponential backoff, 30-second maximum delay, and random jitter.

6. Ensure the transport layer treats all packets as opaque binary/text payloads — no parsing of packet meaning at this layer.

## Files or Modules Expected

• `backend/src/transport/websocket.ts`

• `android/.../transport/WebSocketClient.kt`

• `macos/.../Transport/WebSocketClient.swift`

## Acceptance Criteria

• A client can connect, receive heartbeats, and reconnect automatically after a simulated disconnect, using the documented timing.

• No authentication or encryption occurs at this layer.

## Internal Verification Checklist

✓ Heartbeat interval and timeout match documented values exactly (30s / 90s).

✓ Reconnect backoff matches documented values exactly (1s initial, exponential, 30s max, jitter).

✓ Transport layer contains no packet-meaning logic.

## Common Mistakes

• Embedding authentication checks into the transport layer, violating the Layered Protocol Model.

• Using arbitrary or undocumented timeout values.

## Deliverables

A working, reconnecting WebSocket transport layer across all three components, verified against documented timing.

## Recommended Git Commit

`feat(transport): implement websocket communication`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 8. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 6, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 8 automatically. Phase 8 should only begin when explicitly requested.

---

# Phase 8

## Goal

Implement the mandatory cryptographic primitives as isolated, unit-tested modules.

## Why This Phase Exists

Pairing, authentication, and payload encryption all depend on a single, correct cryptography implementation. Isolating and testing this before it is wired into protocol logic reduces security risk.

## Dependencies

Phase 6 complete. Does not require Phase 7.

## Estimated Complexity

Large

## Estimated AI Coding Sessions

2–3 Sessions

## Tasks

1. Implement X25519 key exchange in Android and macOS (key generation, shared secret derivation).

2. Implement Ed25519 digital signatures (key generation, signing, verification) in Android and macOS.

3. Implement AES-256-GCM symmetric encryption and decryption in Android and macOS.

4. Implement HKDF-SHA256 key derivation in Android and macOS.

5. Implement SHA-256 hashing where required by the protocol.

6. Write unit tests for every primitive, per the Cryptography section of 10_TESTING_SPECIFICATION.md, including rejection of invalid signatures.

7. The backend implements only what its role requires: it never performs decryption or holds private keys, per 04_SECURITY_MODEL.md Backend Security Limitations. Confirm no private-key or payload-decryption code is added to the backend in this phase.

## Files or Modules Expected

• `android/.../crypto/`

• `macos/.../Crypto/`

• No new backend cryptography beyond what Phase 3/14 requires for public key handling.

## Acceptance Criteria

• All five primitives are implemented and unit tested on Android and macOS.

• Invalid signatures are correctly rejected in tests.

• No private key material appears in backend code.

## Internal Verification Checklist

✓ Algorithm names and parameters match Architecture Decision 16 exactly (X25519, Ed25519, AES-256-GCM, HKDF-SHA256, SHA-256).

✓ Unit tests cover both success and rejection paths.

✓ No cryptographic material is logged, per Security Logging rules.

## Common Mistakes

• Substituting a "similar" algorithm (for example RSA instead of X25519) for convenience.

• Adding key export or debug-logging of key material.

## Deliverables

Tested, isolated cryptographic primitive modules on Android and macOS, ready to be wired into pairing and session logic.

## Recommended Git Commit

`feat(crypto): implement cryptographic primitives`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 9. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 7, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 9 automatically. Phase 9 should only begin when explicitly requested.

---

# Phase 9

## Goal

Implement secure key storage and local trust metadata storage on both native platforms.

## Why This Phase Exists

Private keys must never exist outside operating-system-provided secure storage, per 04_SECURITY_MODEL.md. This must be in place before any real key material is generated during pairing.

## Dependencies

Phase 8 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Implement Android Keystore-backed storage for the device's private key, per Architecture Decision 18.

2. Implement Apple Keychain-backed storage for the device's private key.

3. Implement encrypted local storage for trusted device metadata (Trusted Device Identifier, Trusted Public Key, Pairing Timestamp, Trust Status, Device Metadata) on both platforms, per the Local Trust Database section of 04_SECURITY_MODEL.md.

4. Implement device identity generation: a cryptographically secure identifier not derived from MAC address, IMEI, Android ID, hardware identifier, email, phone number, or IP address, per the Device Identifier section of 04_SECURITY_MODEL.md.

5. Write unit tests confirming private keys never appear outside secure storage APIs.

## Files or Modules Expected

• `android/.../storage/KeystoreManager.kt`, `android/.../storage/TrustStore.kt`

• `macos/.../Storage/KeychainManager.swift`, `macos/.../Storage/TrustStore.swift`

## Acceptance Criteria

• Private keys are generated and stored only via Keystore/Keychain APIs.

• Trust metadata storage exists and is encrypted at rest.

• Device identifiers are not derivable from hardware or personal identifiers.

## Internal Verification Checklist

✓ No private key ever touches ordinary application storage, preferences, or logs.

✓ Trust database schema matches the fields listed in 04_SECURITY_MODEL.md.

✓ Device identifier generation avoids every excluded source listed in the Security Model.

## Common Mistakes

• Storing trust metadata inside the same secure enclave API used for private keys, which the Security Model separates.

• Deriving device identifiers from any hardware-linked value for "simplicity."

## Deliverables

Secure, tested key and trust storage on Android and macOS, ready for use during pairing.

## Recommended Git Commit

`feat(crypto): implement secure key storage`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 10. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 8, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 10 automatically. Phase 10 should only begin when explicitly requested.

---

# Phase 10

## Goal

Implement JSON packet serialization together with the full packet validation pipeline.

## Why This Phase Exists

07_PROTOCOL_SPECIFICATION.md defines a strict Packet Verification Order. This must exist before any real authenticated or encrypted traffic flows between devices.

## Dependencies

Phase 7, Phase 8, and Phase 9 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

2 Sessions

## Tasks

1. Implement JSON encoding and decoding for all packet types defined in Phase 6.

2. Implement the Packet Validation Pipeline in this exact order: confirm packet structure, verify protocol compatibility, verify sender identity, verify digital signature, verify packet integrity, verify packet freshness, decrypt payload, validate decrypted contents, execute application logic.

3. Implement rejection behavior for malformed structure, missing required fields, unsupported packet type, and invalid signatures, per Invalid Packet Handling in 07_PROTOCOL_SPECIFICATION.md.

4. Write unit tests for the validation pipeline covering both valid and each documented invalid case.

## Files or Modules Expected

• `android/.../protocol/PacketValidator.kt`

• `macos/.../Protocol/PacketValidator.swift`

• `backend/src/protocol/packetRouting.ts` (structural validation only; the backend cannot perform decryption)

## Acceptance Criteria

• The validation pipeline executes in the documented order, with no step skipped or reordered.

• Every documented failure case is rejected correctly and tested.

## Internal Verification Checklist

✓ Validation step order matches 07_PROTOCOL_SPECIFICATION.md exactly.

✓ Decryption occurs only after every preceding validation step succeeds.

✓ Backend-side validation never attempts payload decryption.

## Common Mistakes

• Decrypting before verifying signature or freshness.

• Allowing partially-valid packets to reach application logic "to be lenient."

## Deliverables

A fully tested packet validation pipeline on Android and macOS, and structural packet routing on the backend.

## Recommended Git Commit

`feat(protocol): implement packet serialization and validation pipeline`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 11. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 9, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 11 automatically. Phase 11 should only begin when explicitly requested.

---

# Phase 11

## Goal

Implement replay protection and packet ordering on top of the validation pipeline.

## Why This Phase Exists

Replay protection is a distinct, security-critical concern layered on top of basic validation, and is fully specified in both 04_SECURITY_MODEL.md and 07_PROTOCOL_SPECIFICATION.md.

## Dependencies

Phase 10 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Implement a Session Sequence Number that starts at 1 per session and increments on every outgoing packet, per Architecture Decision 5.

2. Implement a temporary cache of processed Packet UUIDs, rejecting duplicates.

3. Implement rejection of stale Session Sequence Numbers.

4. Implement clock skew tolerance and rejection of packets outside the allowed window.

5. Implement temporary buffering of out-of-order packets, and handling of missing packets according to the recovery rules referenced in 07_PROTOCOL_SPECIFICATION.md.

6. Write unit and integration tests covering duplicate delivery, stale sequence numbers, out-of-clock-skew timestamps, and out-of-order delivery, per 10_TESTING_SPECIFICATION.md and 05_EDGE_CASES.md.

## Files or Modules Expected

• `android/.../protocol/ReplayGuard.kt`, `android/.../protocol/SequenceTracker.kt`

• `macos/.../Protocol/ReplayGuard.swift`, `macos/.../Protocol/SequenceTracker.swift`

## Acceptance Criteria

• All edge cases listed under Backend Edge Cases in 05_EDGE_CASES.md relating to duplicate, out-of-order, and clock-skew packets behave exactly as documented.

## Internal Verification Checklist

✓ Sequence numbering starts at 1 and increments correctly per session.

✓ Duplicate UUIDs are rejected without executing the associated command twice.

✓ Out-of-order packets are buffered, not dropped, unless recovery rules dictate otherwise.

## Common Mistakes

• Resetting sequence numbers mid-session.

• Permanently discarding out-of-order packets instead of buffering them as documented.

## Deliverables

Tested replay protection and ordering logic, ready to support authenticated sessions.

## Recommended Git Commit

`feat(protocol): implement replay protection and sequencing`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 12. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 10, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 12 automatically. Phase 12 should only begin when explicitly requested.

---

# Phase 12

## Goal

Implement the complete QR-based pairing flow establishing mutual trust between exactly one Android device and one macOS device.

## Why This Phase Exists

Pairing is, per 04_SECURITY_MODEL.md, "the most security-critical operation performed by MacEcho." It must be implemented as a complete, correct unit before any other authenticated feature depends on trust existing.

## Dependencies

Phase 9 and Phase 11 complete.

## Estimated Complexity

Large

## Estimated AI Coding Sessions

2–3 Sessions

## Tasks

1. Implement macOS QR code generation, representing a temporary, single-use, short-lived pairing session, per the QR Code Lifetime and Single-Use Pairing sections of 04_SECURITY_MODEL.md.

2. Implement Android QR code scanning and pairing session initiation.

3. Implement the Secure Pairing Flow exactly as sequenced in 04_SECURITY_MODEL.md: temporary session creation, QR generation, scan, backend relay connection, public key exchange, mutual verification, trust establishment, local trust database update, pairing session destruction, secure communication begins.

4. Implement QR expiration and invalidation of previously generated QR codes when a new one is generated.

5. Implement pairing failure handling leaving both devices in their original unpaired state with no partial trust, per Pairing Failure in 04_SECURITY_MODEL.md.

6. Implement the pairing-replacement rule: a new pairing replaces existing trust, or requires explicit unpairing if already paired, per Architecture Decision 9 and 15.

7. Write integration tests for the full pairing flow, expired QR rejection, reused QR rejection, and pairing cancellation, per 10_TESTING_SPECIFICATION.md.

## Files or Modules Expected

• `backend/src/pairing/`

• `android/.../pairing/`

• `macos/.../Pairing/`

## Acceptance Criteria

• A real Android device and macOS device can complete pairing end-to-end using a generated QR code.

• Expired, reused, or invalid QR codes are rejected without creating partial trust.

• Local trust databases on both devices reflect the new trust relationship after success.

## Internal Verification Checklist

✓ Every step of the Secure Pairing Flow is implemented and in the documented order.

✓ No partial trust state can exist after a failed pairing attempt.

✓ The backend never gains authority over trust at any point in this flow.

## Common Mistakes

• Treating QR code scanning alone as sufficient for trust, which 04_SECURITY_MODEL.md explicitly forbids.

• Allowing multiple concurrent valid QR codes.

## Deliverables

A complete, tested, end-to-end pairing flow between Android and macOS.

## Recommended Git Commit

`feat(pairing): implement secure QR pairing`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 13. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 11, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 13 automatically. Phase 13 should only begin when explicitly requested.

---

# Phase 13

## Goal

Implement session authentication and trust (re)validation for ongoing and reconnected sessions.

## Why This Phase Exists

Pairing establishes trust once. Every subsequent session must independently authenticate using that trust, per the Authentication Philosophy in 04_SECURITY_MODEL.md.

## Dependencies

Phase 12 complete.

## Estimated Complexity

Large

## Estimated AI Coding Sessions

2–3 Sessions

## Tasks

1. Implement the Authentication Handshake sequence from 07_PROTOCOL_SPECIFICATION.md, occurring before any application data is exchanged.

2. Implement Trust Validation on every session start: confirm peer is still trusted, stored public key matches, cryptographic authenticity verified.

3. Implement Reconnection Validation, ensuring previous trust never bypasses fresh authentication.

4. Implement rejection and safe unpairing behavior for public key mismatch, per the Public Key Mismatch edge case in 05_EDGE_CASES.md.

5. Implement Handling Asymmetric Unpairing, where one device has unpaired while the other was offline, per 04_SECURITY_MODEL.md and 05_EDGE_CASES.md.

6. Write integration tests for successful authentication, authentication failure, and asymmetric unpairing convergence, per 10_TESTING_SPECIFICATION.md.

## Files or Modules Expected

• `android/.../auth/`

• `macos/.../Auth/`

• `backend/src/auth/` (session/connection bookkeeping only, never trust decisions)

## Acceptance Criteria

• A session cannot exchange application data before authentication succeeds.

• Public key mismatch results in trust removal and mandatory re-pairing, exactly as documented.

• Asymmetric unpairing scenarios converge to a consistent trust state on both devices.

## Internal Verification Checklist

✓ No application command executes before authentication completes.

✓ Trust validation occurs on every session, not only the first.

✓ The backend never makes or influences a trust decision.

## Common Mistakes

• Caching "last known good" authentication across sessions instead of re-validating.

• Allowing the backend to signal trust state.

## Deliverables

Tested, per-session authentication and trust validation across Android and macOS.

## Recommended Git Commit

`feat(auth): implement session authentication`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 14. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 12, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 14 automatically. Phase 14 should only begin when explicitly requested.

---

# Phase 14

## Goal

Implement backend message relay logic and rate limiting.

## Why This Phase Exists

The backend's only responsibilities are routing, delivery, and abuse protection. Implementing this after client-side authentication exists allows the backend to be tested against real authenticated traffic.

## Dependencies

Phase 7 and Phase 13 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

2 Sessions

## Tasks

1. Implement encrypted packet relay between connected Android and macOS WebSocket sessions, without inspecting or modifying payloads, per 03_SYSTEM_ARCHITECTURE.md and 07_PROTOCOL_SPECIFICATION.md.

2. Implement connection protection, authentication protection, packet protection, and abuse detection rate limits, using the exact initial values from Architecture Decision 19: 20 concurrent connections per IP, 10 pairing attempts per IP per hour, 5 authentication failures before cooldown, 100 packets per second, 64 KB maximum packet size.

3. Implement rejection behavior when limits are exceeded, without leaking information about why to unauthenticated callers beyond what is necessary.

4. Write integration tests confirming the backend never decrypts payloads and correctly enforces every documented limit.

## Files or Modules Expected

• `backend/src/relay/`

• `backend/src/rateLimit/`

## Acceptance Criteria

• The backend relays encrypted packets correctly between two connected, authenticated sessions.

• Every documented rate limit is enforced with the exact documented values.

• The backend cannot decrypt, log, or persist payload contents.

## Internal Verification Checklist

✓ Rate limit values match Architecture Decision 19 exactly — no rounding or approximation.

✓ Relay logic never parses or stores decrypted payload content.

✓ Maximum packet size (64 KB) is enforced at the transport boundary.

## Common Mistakes

• Adjusting rate limits "to make testing easier" without documenting the change as a decision update.

• Adding payload inspection for debugging purposes.

## Deliverables

A tested backend relay enforcing all documented rate limits, ready for realistic multi-device traffic.

## Recommended Git Commit

`feat(backend): implement relay and rate limiting`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 15. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 13, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 15 automatically. Phase 15 should only begin when explicitly requested.

---

# Phase 15

## Goal

Implement full session recovery behavior, including backend restart resilience.

## Why This Phase Exists

04_SECURITY_MODEL.md and 07_PROTOCOL_SPECIFICATION.md both require that backend restarts and connectivity loss never require re-pairing. This must be verified as its own phase before feature work is layered on top.

## Dependencies

Phase 14 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

2 Sessions

## Tasks

1. Verify and, if needed, harden automatic reconnection (from Phase 7) against a real backend restart.

2. Confirm sessions automatically re-authenticate after backend restart with no user interaction and no QR code, per Architecture Decision 13.

3. Implement handling for Temporary Internet Loss, Backend Unavailable, and High Network Latency edge cases exactly as described in 05_EDGE_CASES.md.

4. Write integration tests simulating backend restart, extended offline periods, and high latency, per 10_TESTING_SPECIFICATION.md.

## Files or Modules Expected

• Refinements to `backend/src/transport/websocket.ts`, `android/.../transport/`, `macos/.../Transport/`

• No new top-level modules expected; this phase hardens existing ones.

## Acceptance Criteria

• A simulated backend restart results in automatic reconnection and re-authentication with no manual steps.

• Pairing remains valid across all tested connectivity failure scenarios.

## Internal Verification Checklist

✓ No scenario in this phase requires a new QR code or manual re-pairing.

✓ Reconnection timing still matches the documented backoff values after hardening.

✓ Trust state remains unchanged across every tested failure scenario.

## Common Mistakes

• Introducing a "just re-pair to be safe" fallback, which contradicts Architecture Decision 13.

• Only testing the happy path reconnection, not backend-restart-specific timing.

## Deliverables

Verified, resilient session recovery across backend restarts and connectivity failures.

## Recommended Git Commit

`feat(session): implement recovery and reconnection`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 16. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 14, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 16 automatically. Phase 16 should only begin when explicitly requested.

---

# Phase 16

## Goal

Implement the Android Notification Listener integration, capturing notification data without yet transmitting it.

## Why This Phase Exists

Notification capture and notification transmission are separable concerns. Implementing capture first, with local logging only, allows this OS-integration-heavy work to be verified independently of the protocol layer.

## Dependencies

Phase 4 complete. Does not require pairing to be functional.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Implement Android's NotificationListenerService.

2. Implement the notification permission request UX described in 06_UI_GUIDELINES.md: explain why the permission is required, what depends on it, and whether it can be granted later, before requesting it.

3. Capture the complete notification payload exposed by NotificationListenerService, per the Notification Payload Transmission section of 07_PROTOCOL_SPECIFICATION.md — no truncation at capture time.

4. Implement handling for Notification Permission Revoked, per 05_EDGE_CASES.md: notification sync stops, other features continue, user is guided to restore permission.

5. Implement background execution requirements for the listener service (foreground service where required, battery-optimization exemption prompt), consistent with the app remaining lightweight per 02_PRODUCT_REQUIREMENTS.md.

## Files or Modules Expected

• `android/.../notifications/NotificationListener.kt`

• `android/.../permissions/NotificationPermissionFlow.kt`

## Acceptance Criteria

• The app captures full notification payloads locally when permission is granted.

• Permission revocation is handled exactly as documented, without crashing or silently failing other features.

## Internal Verification Checklist

✓ No artificial truncation occurs at capture time.

✓ Permission request UX matches 06_UI_GUIDELINES.md exactly.

✓ No network transmission occurs in this phase — capture only.

## Common Mistakes

• Requesting the permission before explaining it, violating the documented permission experience.

• Truncating notification content at capture time instead of at the native macOS banner, which contradicts the Full Notification Detail View decision.

## Deliverables

A working, permissioned Android notification capture pipeline with no network transmission yet.

## Recommended Git Commit

`feat(android): integrate notification listener`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 17. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 15, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 17 automatically. Phase 17 should only begin when explicitly requested.

---

# Phase 17

## Goal

Implement end-to-end notification synchronization: encrypted transmission from Android to macOS and the native macOS banner display.

## Why This Phase Exists

This is the first true end-user feature, and depends on every lower layer (transport, crypto, pairing, authentication, replay protection) being complete and correct.

## Dependencies

Phase 12, Phase 13, Phase 15, and Phase 16 complete.

## Estimated Complexity

Large

## Estimated AI Coding Sessions

2–3 Sessions

## Tasks

1. Implement Notification Created, Notification Updated, and Notification Removed commands per 07_PROTOCOL_SPECIFICATION.md.

2. Encrypt the complete notification payload before transmission; transmit the entire payload with no artificial truncation, per the Notification Payload Transmission section of 07_PROTOCOL_SPECIFICATION.md.

3. Implement macOS-side decryption and display as a standard native macOS notification banner, per 06_UI_GUIDELINES.md — MacEcho must not customize or replace the native banner.

4. Implement Duplicate Notification and Notification Arrives While Offline edge cases exactly as described in 05_EDGE_CASES.md.

5. Write end-to-end tests for notification delivery, per 10_TESTING_SPECIFICATION.md.

## Files or Modules Expected

• `android/.../notifications/NotificationSync.kt`

• `macos/.../Notifications/NotificationReceiver.swift`, `macos/.../Notifications/NativeBannerPresenter.swift`

• `backend/src/relay/` (reused from Phase 14, no changes expected)

## Acceptance Criteria

• A real Android notification appears as a native macOS banner end-to-end, fully encrypted in transit, with no content truncated during transmission.

• Duplicate and offline-arrival edge cases behave exactly as documented.

## Internal Verification Checklist

✓ The backend relays these packets without ever decrypting them (verify by inspection, not just by absence of a decrypt call).

✓ No content truncation occurs anywhere except the native banner's own OS-level rendering.

✓ Notification removal correctly updates or clears the macOS-side notification.

## Common Mistakes

• Building a custom notification UI at this phase — that belongs to Phase 18, and the native banner itself must never be replaced.

• Truncating payloads "to save bandwidth," which directly contradicts the approved product decision.

## Deliverables

A working, tested, end-to-end encrypted notification synchronization feature using native macOS banners.

## Recommended Git Commit

`feat(notification): synchronize android notifications`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 18. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 16, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 18 automatically. Phase 18 should only begin when explicitly requested.

---

# Phase 18

## Goal

Implement the Notification Detail View: the popover experience opened from a clicked notification banner.

## Why This Phase Exists

This is a distinct, newly-approved product decision with specific UI behavior, separable from the underlying synchronization built in Phase 17.

## Dependencies

Phase 17 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Implement banner-click handling that opens the MacEcho popover directly into the Notification Detail View, rather than the default home screen, per 06_UI_GUIDELINES.md.

2. Implement the Notification Detail View layout: app icon, app name, sender (when available), timestamp, and full notification content.

3. Implement the vertically scrollable message container, keeping the popover itself compact regardless of message length.

4. Implement the rule that manually opening MacEcho from the menu bar icon (not via a notification) opens the default home screen instead, per 06_UI_GUIDELINES.md.

5. Implement the Missing Sender Information edge case: omit the sender field rather than showing a placeholder, per 05_EDGE_CASES.md.

6. Implement Multi-Line Notification Message, Notification Contains Emoji, and Rich Text Content edge cases from 05_EDGE_CASES.md.

7. Write UI and integration tests for detail view navigation behavior, per 10_TESTING_SPECIFICATION.md.

## Files or Modules Expected

• `macos/.../Notifications/NotificationDetailView.swift`

• `macos/.../Notifications/NotificationDetailViewModel.swift`

## Acceptance Criteria

• Clicking a notification banner opens the popover directly into the correct detail view with full content.

• Manually opening the menu bar icon never shows the previous notification.

• Extremely long messages remain fully readable via scrolling without growing the popover.

## Internal Verification Checklist

✓ Popover size remains compact regardless of message length; only the message container scrolls.

✓ Sender field is omitted, not blanked or placeholdered, when unavailable.

✓ Manual menu bar opening never shows notification detail content.

## Common Mistakes

• Letting the popover grow to fit long messages instead of scrolling internally.

• Showing the most recent notification when the icon is clicked manually, which 06_UI_GUIDELINES.md explicitly forbids.

## Deliverables

A working, tested Notification Detail View matching the approved product decision exactly.

## Recommended Git Commit

`feat(macos): implement notification detail view`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 19. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 17, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 19 automatically. Phase 19 should only begin when explicitly requested.

---

# Phase 19

## Goal

Implement notification reply from macOS back to Android for supported notifications.

## Why This Phase Exists

Reply is a distinct command flow building on the notification pipeline, and is explicitly scoped in 02_PRODUCT_REQUIREMENTS.md as a Version 1 feature.

## Dependencies

Phase 17 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

2 Sessions

## Tasks

1. Implement the Notification Reply Command per 07_PROTOCOL_SPECIFICATION.md: macOS creates the command, Android receives it, Android delivers the reply using operating system APIs, Android confirms completion.

2. Implement the reply UI on macOS, reachable with minimal interaction per 06_UI_GUIDELINES.md.

3. Implement Android-side reply delivery using the appropriate RemoteInput / notification action API for supported notifications only.

4. Implement User Clicks Reply Repeatedly edge case: duplicate replies prevented, per 05_EDGE_CASES.md.

5. Implement Notification Reply Permission Revoked edge case: notifications remain visible, reply becomes unavailable, per 05_EDGE_CASES.md.

## Files or Modules Expected

• `android/.../notifications/ReplyHandler.kt`

• `macos/.../Notifications/ReplyComposer.swift`

## Acceptance Criteria

• A reply typed on macOS is delivered on Android for a supported notification, end-to-end, encrypted in transit.

• Repeated reply submissions do not produce duplicate sends.

• Reply permission revocation degrades gracefully without affecting notification display.

## Internal Verification Checklist

✓ The protocol only transports the reply; Android performs the actual delivery, exactly as documented.

✓ Duplicate-submission protection is verified with an automated test, not just manual observation.

## Common Mistakes

• Allowing reply attempts on notification types that do not support it, without documented allow-list logic (see Product Requirements: "supported notifications").

• Missing duplicate-submission protection.

## Deliverables

A working, tested notification reply feature.

## Recommended Git Commit

`feat(reply): implement notification reply`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 20. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 18, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 20 automatically. Phase 20 should only begin when explicitly requested.

---

# Phase 20

## Goal

Implement lock screen privacy behavior on macOS.

## Why This Phase Exists

This is a distinct, security-and-privacy-relevant behavior spanning notification display and reply availability, and is fully specified across 02_PRODUCT_REQUIREMENTS.md, 04_SECURITY_MODEL.md, and 05_EDGE_CASES.md.

## Dependencies

Phase 17 and Phase 19 complete.

## Estimated Complexity

Small

## Estimated AI Coding Sessions

1 Session

## Tasks

1. Detect macOS lock state.

2. While locked, show only that a notification was received and the originating application's icon; hide title, body, images, and attachments.

3. Disable quick reply while macOS is locked.

4. Restore full content and reply availability immediately upon unlock, with no re-authentication of the underlying session required (this is a display-layer restriction, not a trust or session concern).

5. Write UI and integration tests for the Notification Received While macOS Is Locked edge case, per 05_EDGE_CASES.md.

## Files or Modules Expected

• `macos/.../Security/LockStateObserver.swift`

• Updates to `macos/.../Notifications/NativeBannerPresenter.swift` and `ReplyComposer.swift`

## Acceptance Criteria

• Locked-screen behavior matches the documented show/hide rules exactly.

• Reply is unavailable while locked and available immediately after unlock.

## Internal Verification Checklist

✓ No sensitive content (title, body, images, attachments) is rendered anywhere on screen while locked.

✓ This restriction is implemented as a presentation-layer rule, not conflated with authentication or trust logic.

## Common Mistakes

• Implementing this as a network-level restriction instead of a local display restriction, which would incorrectly couple it to session state.

• Forgetting to also gate quick reply, not just banner content.

## Deliverables

A working, tested lock screen privacy behavior.

## Recommended Git Commit

`feat(privacy): implement lock screen privacy`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 21. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 19, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 21 automatically. Phase 21 should only begin when explicitly requested.

---

# Phase 21

## Goal

Implement call detection on Android and the call interface on macOS.

## Why This Phase Exists

Call handling is architecturally independent of notifications and depends on a distinct Android API strategy, justifying its own phase.

## Dependencies

Phase 12, Phase 13, and Phase 15 complete. Does not require Phase 16–20.

## Estimated Complexity

Large

## Estimated AI Coding Sessions

2–3 Sessions

## Tasks

1. Implement call state detection using TelephonyCallback on Android 12+, and PhoneStateListener on older supported versions, per Architecture Decision 20.

2. Detect and transmit incoming calls, outgoing calls, answered calls, and ended calls.

3. Confirm no use of InCallService or CallScreeningService anywhere in the implementation, per Architecture Decision 20 and 02_PRODUCT_REQUIREMENTS.md.

4. Implement the Incoming Call, Call Updated, Call Ended, Call Accepted, and Call Declined commands per 07_PROTOCOL_SPECIFICATION.md.

5. Implement the macOS Call Interface per 06_UI_GUIDELINES.md: immediate appearance, Accept/Decline/Dismiss actions, automatic disappearance when the call ends. Audio remains on the phone.

6. Implement Call Permission Revoked, Incoming Call Ends Before User Responds, Multiple Incoming Calls, User Accepts Call On Phone, and User Rejects Call On Phone edge cases from 05_EDGE_CASES.md.

## Files or Modules Expected

• `android/.../calls/CallStateMonitor.kt`

• `macos/.../Calls/CallInterface.swift`

## Acceptance Criteria

• Incoming, answered, and ended calls on Android are reflected correctly and promptly on macOS.

• Accept/Decline from macOS correctly controls the call state on Android; audio remains on the phone.

• No dialer-replacement API is used anywhere in the implementation.

## Internal Verification Checklist

✓ Call API choice matches the Android version rule exactly (TelephonyCallback 12+, PhoneStateListener older).

✓ No InCallService or CallScreeningService reference exists anywhere in the codebase.

✓ Call interface disappears automatically when the call ends, without requiring user dismissal.

## Common Mistakes

• Reaching for InCallService for "better control," which is explicitly disallowed.

• Attempting to route call audio through macOS, which is out of scope.

## Deliverables

A working, tested call detection and control feature.

## Recommended Git Commit

`feat(call): implement incoming call management`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 22. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 20, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 22 automatically. Phase 22 should only begin when explicitly requested.

---

# Phase 22

## Goal

Implement the Ring Phone feature.

## Why This Phase Exists

Ring Phone is architecturally simple but end-user facing, and depends only on the pairing, authentication, and transport layers already completed.

## Dependencies

Phase 12, Phase 13, and Phase 15 complete.

## Estimated Complexity

Medium

## Estimated AI Coding Sessions

1–2 Sessions

## Tasks

1. Implement the Ring Phone command per 07_PROTOCOL_SPECIFICATION.md.

2. Implement the macOS Ring Phone Interface per 06_UI_GUIDELINES.md: immediate confirmation of sent, failed, or waiting-for-delivery status.

3. Implement Android-side ringing behavior upon receiving the command.

4. Implement Multiple Ring Requests, Phone Already Ringing, and Phone Offline edge cases exactly as described in 05_EDGE_CASES.md.

5. Implement User Presses Ring Phone Repeatedly edge case: existing ring session maintained, additional requests ignored, per 05_EDGE_CASES.md.

## Files or Modules Expected

• `android/.../ring/RingHandler.kt`

• `macos/.../Ring/RingRequestController.swift`

## Acceptance Criteria

• Triggering Ring Phone from macOS causes the paired Android device to ring, with correct status feedback on macOS.

• Repeated ring requests do not create multiple overlapping ring sessions.

## Internal Verification Checklist

✓ macOS always shows one of: sent, failed, or waiting-for-delivery — never an ambiguous state.

✓ Duplicate ring requests are provably idempotent via test, not just observation.

## Common Mistakes

• Allowing overlapping ring sessions when the button is pressed multiple times.

• Failing silently when the phone is offline instead of informing the user, per the documented edge case.

## Deliverables

A working, tested Ring Phone feature.

## Recommended Git Commit

`feat(ring): implement ring phone feature`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 23. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 21, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 23 automatically. Phase 23 should only begin when explicitly requested.

---

# Phase 23

## Goal

Integrate all previously independent features and verify the complete cross-feature edge case surface.

## Why This Phase Exists

Phases 16 through 22 were built and tested largely independently. This phase verifies they behave correctly when used together and under the full range of documented edge cases.

## Dependencies

Phase 17, Phase 18, Phase 19, Phase 20, Phase 21, and Phase 22 complete.

## Estimated Complexity

Very Large

## Estimated AI Coding Sessions

3–4 Sessions

## Tasks

1. Verify all remaining edge cases in 05_EDGE_CASES.md not already covered by an individual feature phase, including Pairing Edge Cases, Authentication Edge Cases, Device Lifecycle Edge Cases, Application Lifecycle Edge Cases, and Trust Synchronization Edge Cases.

2. Verify concurrent use of multiple features (for example, a notification arriving during an active call, or a ring request during pairing) does not produce inconsistent state.

3. Verify the Android Settings screens (Phase 4 scaffold) are now fully wired to real permission, connection, and unpair functionality.

4. Verify the macOS home screen (Phase 5 scaffold) is now fully wired to real device status, connected device information, and unpair functionality.

5. Resolve any inconsistency discovered between implementation and documentation by flagging it explicitly rather than silently changing either.

## Files or Modules Expected

No new modules expected. This phase wires and verifies existing modules; any new files should be limited to integration glue code.

## Acceptance Criteria

• Every edge case listed in 05_EDGE_CASES.md has been manually or automatically verified against the running implementation.

• Settings and home screens are fully functional, not placeholder scaffolds.

• No known cross-feature inconsistency remains unresolved.

## Internal Verification Checklist

✓ Every section of 05_EDGE_CASES.md has been checked off against the implementation.

✓ No placeholder UI element remains from Phase 4 or Phase 5.

✓ Any discovered documentation/implementation conflict has been explicitly flagged, not silently resolved.

## Common Mistakes

• Treating this phase as optional because "each feature already works individually."

• Quietly changing documented behavior to match a implementation shortcut instead of flagging the conflict.

## Deliverables

A fully integrated application with every documented edge case verified.

## Recommended Git Commit

`test(integration): complete system integration`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 24. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 22, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 24 automatically. Phase 24 should only begin when explicitly requested.

---

# Phase 24

## Goal

Implement the complete automated test suite defined in 10_TESTING_SPECIFICATION.md, filling any coverage gaps left by earlier phases.

## Why This Phase Exists

Earlier phases required tests for their own scope. This phase ensures the full, consolidated suite — unit, integration, and end-to-end — exists and passes as a whole, per 10_TESTING_SPECIFICATION.md.

## Dependencies

Phase 23 complete.

## Estimated Complexity

Very Large

## Estimated AI Coding Sessions

3–4 Sessions

## Tasks

1. Audit existing unit tests against the Cryptography, Protocol, Serialization, and Session Management sections of 10_TESTING_SPECIFICATION.md; fill any gaps.

2. Audit existing integration tests against the Android ↔ Backend, Backend ↔ macOS, Pairing, Notifications, and Reconnection sections; fill any gaps.

3. Implement any missing end-to-end tests: Pairing, Notification Sync, Reply, Calls, Ring Phone, Backend Restart, Device Reboot, Network Failure.

4. Run the full suite and resolve any failures.

## Files or Modules Expected

• Test directories within `backend/`, `android/`, and `macos/`, matching each project's standard test structure.

## Acceptance Criteria

• Every test listed in 10_TESTING_SPECIFICATION.md's Unit Tests, Integration Tests, and End-to-End Tests sections exists and passes.

## Internal Verification Checklist

✓ Every named test category in 10_TESTING_SPECIFICATION.md maps to at least one actual test.

✓ Full suite passes with no skipped or ignored tests left unexplained.

## Common Mistakes

• Marking a difficult-to-simulate scenario (for example, backend restart) as skipped instead of implementing a proper simulation.

• Treating test-writing as optional cleanup instead of a required phase.

## Deliverables

A complete, passing automated test suite matching 10_TESTING_SPECIFICATION.md exactly.

## Recommended Git Commit

`test: implement automated test suite`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 25. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 23, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 25 automatically. Phase 25 should only begin when explicitly requested.

---

# Phase 25

## Goal

Execute the manual validation checklist and stabilize the release candidate.

## Why This Phase Exists

Some behaviors — OEM-specific battery optimization, real sleep/wake cycles, real large-notification rendering — cannot be fully verified by automated tests alone, per 10_TESTING_SPECIFICATION.md.

## Dependencies

Phase 24 complete.

## Estimated Complexity

Large

## Estimated AI Coding Sessions

2–3 Sessions

## Tasks

1. Execute the full Manual Validation Checklist from 10_TESTING_SPECIFICATION.md: Android 10+ devices, macOS 13+ devices, Sleep/Wake, Battery Saver, Large Notifications, Security Regression.

2. Log and triage every defect found during manual validation.

3. Fix all blocking defects; explicitly document any known non-blocking issue rather than hiding it.

4. Re-run the automated suite from Phase 24 after fixes to confirm no regression.

## Files or Modules Expected

No new modules expected. Bug fixes only, scoped to existing modules.

## Acceptance Criteria

• The full manual validation checklist has been executed and passed, or every failure has been fixed and re-verified.

• The automated suite still passes after stabilization fixes.

## Internal Verification Checklist

✓ Every item on the Manual Validation Checklist has a recorded pass/fail result.

✓ No known blocking issue remains open.

✓ Any known non-blocking issue is explicitly documented, not silently ignored.

## Common Mistakes

• Skipping OEM-specific battery optimization testing because it is inconvenient — this is a documented, real risk area per prior architecture review.

• Fixing a bug in a way that silently contradicts documented behavior instead of flagging the conflict.

## Deliverables

A stabilized release candidate with a documented, passing manual validation record.

## Recommended Git Commit

`chore(qa): stabilize release candidate`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not continue to Phase 26. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 24, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, stop implementation. Do not begin Phase 26 automatically. Phase 26 should only begin when explicitly requested.

---

# Phase 26

## Goal

Prepare and execute the Version 1 release.

## Why This Phase Exists

Release packaging, signing, and deployment are distinct from feature completeness and must not be rushed alongside final feature work.

## Dependencies

Phase 25 complete.

## Estimated Complexity

Large

## Estimated AI Coding Sessions

2–3 Sessions

## Tasks

1. Resolve the backend hosting and deployment decision flagged under Assumptions Requiring Confirmation; this must be an explicit, documented decision before deployment, not an implementation-time guess.

2. Configure macOS code signing, notarization, and Login Item registration for distribution.

3. Configure Android release signing and Play Store (or documented alternative) packaging.

4. Deploy the backend to the decided hosting environment and verify the health-check endpoint from Phase 3 responds correctly in production.

5. Perform a final full pairing-through-ring-phone smoke test against the production backend.

6. Tag the release and update the version metadata in all three projects.

## Files or Modules Expected

• Release/signing configuration files in `android/` and `macos/`.

• Deployment configuration in `backend/`.

## Acceptance Criteria

• The backend is deployed and reachable in production.

• Signed, distributable builds exist for Android and macOS.

• A full end-to-end smoke test passes against the production backend.

## Internal Verification Checklist

✓ Backend hosting decision is documented, not assumed.

✓ Signing and notarization complete without errors.

✓ Production smoke test covers pairing, notification sync, reply, calls, and ring phone.

## Common Mistakes

• Deploying to an undocumented, ad hoc hosting choice without recording the decision.

• Treating the production smoke test as optional because staging tests already passed.

## Deliverables

A deployed, signed, distributable Version 1 release of MacEcho.

## Recommended Git Commit

`chore(release): prepare version 1 release`

## Rollback Procedure

If verification for this phase fails, stop implementation immediately. Do not proceed with any future-version work. If the issue cannot be resolved quickly, restore the previous known-good commit from the end of Phase 25, fix the issue, and re-run verification. Continue only once this phase passes all acceptance criteria.

## Stop Condition

After completing this phase, implementation of Version 1 is complete. Do not begin any future-version feature. Future work requires a new roadmap and implementation plan revision.

---

# Conclusion

This Implementation Plan translates the MacEcho architecture, security, protocol, product, and testing documentation into a strict, sequential, independently verifiable build order.

Each phase is deliberately small, builds on a fully verified predecessor, and ends with an explicit stop. No phase should ever be combined with another, skipped, or reordered without updating this document first.

Where this plan encounters a gap in existing documentation, it states an explicit, minimal assumption rather than inventing undocumented behavior, and flags that assumption for confirmation before the affected phase begins.

This document should be treated with the same authority as the other documents in this repository, and kept consistent with them as the project evolves.

---

# Standard AI Coding Prompt

The following prompt template is intended to be copied into Claude Code, Codex, Cursor, or a similar AI coding agent at the start of any implementation session. Replace `[PHASE NUMBER]` with the specific phase to be implemented.

```
Read 11_IMPLEMENTATION_PLAN.md in full.

Locate Phase [PHASE NUMBER] and read its Goal, Why This Phase Exists, Dependencies,
Estimated Complexity, Estimated AI Coding Sessions, Tasks, Files or Modules Expected,
Acceptance Criteria, Internal Verification Checklist, Common Mistakes, Deliverables,
Recommended Git Commit, Rollback Procedure, and Stop Condition sections.

Read every dependency document referenced by Phase [PHASE NUMBER], including any
document listed under Relationship To Other Documents that this phase depends on.

Confirm that all Dependencies listed for Phase [PHASE NUMBER] are already complete
before proceeding. If they are not, stop and report this instead of proceeding.

Implement only Phase [PHASE NUMBER]. Do not begin any future phase, even partially,
even as a convenience, and even if it appears simple.

Follow the Coding Philosophy and Phase Design Principles sections of
11_IMPLEMENTATION_PLAN.md throughout implementation.

After implementation, run the Internal Verification Checklist for this phase exactly
as written, and run any relevant automated tests.

If verification fails, follow the Rollback Procedure defined for this phase rather
than proceeding or silently working around the failure.

If verification succeeds, report the following:

- Completed tasks
- Files created or modified
- Test results
- Known issues
- Uncertainties

Stop after completing and reporting on Phase [PHASE NUMBER]. Do not begin the next
phase automatically. The next phase should only begin when explicitly requested.
```