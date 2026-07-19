---
Document: Testing Specification
Version: 1.0
Status: Draft
Last Updated: YYYY-MM-DD
Owner: MacEcho Team
Review Required: Yes
---

# Testing Specification

# Purpose

This document defines the testing strategy for the MacEcho platform.

It establishes the categories of testing performed throughout development, what each category verifies, and the manual validation checklist required before a Version 1 release.

This document serves as the authoritative reference for testing scope across Android, macOS, and the backend.

---

# Scope

This document covers:

• Unit testing.

• Integration testing.

• End-to-end testing.

• Manual validation.

Implementation-specific testing tools, frameworks, and CI configuration are not mandated here.

---

# Testing Philosophy

Testing exists to verify the guarantees established throughout the architecture, security, and protocol documentation — not to replace them.

Every security-critical behavior defined in the Security Model must have corresponding test coverage before release.

Testing complements, and never substitutes for, the design principles defined elsewhere in this repository.

---

# Unit Tests

Unit tests verify individual components in isolation.

## Cryptography

• Key generation (X25519, Ed25519).

• Encryption and decryption using AES-256-GCM.

• Key derivation using HKDF-SHA256.

• Hashing using SHA-256.

• Signature creation and verification.

• Rejection of invalid signatures.

---

## Protocol

• Packet header parsing.

• Packet validation pipeline.

• Sequence number handling.

• Packet UUID uniqueness enforcement.

• Clock skew rejection.

---

## Serialization

• JSON encoding and decoding of every packet type.

• Rejection of malformed JSON payloads.

• Rejection of packets with missing required fields.

---

## Session Management

• Heartbeat timing.

• Session timeout behavior.

• Reconnect backoff calculation (initial delay, exponential growth, maximum delay, jitter).

---

# Integration Tests

Integration tests verify interaction between components.

## Android ↔ Backend

• Connection establishment over WebSocket.

• Authentication handshake.

• Packet delivery and acknowledgement.

---

## Backend ↔ macOS

• Connection establishment over WebSocket.

• Authentication handshake.

• Packet delivery and acknowledgement.

---

## Pairing

• Full QR pairing flow between Android and macOS through the backend.

• Rejection of expired or reused QR codes.

• Rejection of invalid public key exchange.

---

## Notifications

• Full notification payload delivery without truncation.

• Notification reply delivery back to Android.

• Notification removal synchronization.

---

## Reconnection

• Session recovery after temporary disconnection.

• Session recovery after backend restart.

• Trust revalidation on reconnection.

---

# End-to-End Tests

End-to-end tests verify complete user-facing flows across both native applications and the backend.

• Pairing, from QR generation through established trust.

• Notification synchronization, from Android notification to macOS display.

• Notification reply, from macOS entry to Android delivery.

• Incoming call handling, from Android call state to macOS call interface.

• Ring Phone, from macOS request to Android ringing.

• Backend restart, verifying pairing remains valid and reconnection is automatic.

• Device reboot, verifying trust and secure storage remain intact.

• Network failure, verifying automatic reconnection and no inconsistent state.

---

# Manual Validation Checklist

Before a Version 1 release, manually verify:

✓ Android 10+ devices.

✓ macOS 13+ devices.

✓ Sleep/Wake behavior on both platforms.

✓ Battery Saver / Doze Mode behavior on Android.

✓ Large notification content displays and scrolls correctly in the Notification Detail View.

✓ Lock screen privacy behavior on macOS (notification content hidden while locked).

✓ Security regression checks against the Security Review Checklist in the Security Model.

---

# Testing Review Checklist

Before approving a release candidate, verify:

✓ Unit test coverage exists for cryptography, protocol, serialization, and session management.

✓ Integration tests cover every major component pairing.

✓ End-to-end tests cover every Version 1 feature.

✓ The manual validation checklist has been completed.

✓ No known security regressions remain unresolved.

---

# Conclusion

Testing verifies that MacEcho's implementation honors the guarantees defined throughout the architecture, security, and protocol documentation.

This document should be updated whenever new features, commands, or edge cases are introduced elsewhere in the repository, so that test coverage remains aligned with the platform's actual behavior.