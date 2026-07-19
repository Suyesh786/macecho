---
Document: Edge Cases
Version: 1.0
Status: Draft
Last Updated: YYYY-MM-DD
Owner: MacEcho Team
Review Required: Yes
---

# Edge Cases

# Purpose

This document defines how MacEcho behaves under exceptional, uncommon, or unexpected conditions.

While normal user flows are documented elsewhere, this document focuses on situations that occur outside the ideal path. Every edge case described here has an explicitly defined system response to ensure consistent, predictable, and secure behavior.

The purpose of this document is to eliminate ambiguity during implementation by documenting how the application should respond to failures, interruptions, invalid states, unexpected user actions, and uncommon environmental conditions.

---

# Scope

This document covers:

• Pairing edge cases

• Authentication edge cases

• Connectivity interruptions

• Device lifecycle events

• Backend availability

• User behavior

• Operating system events

• Notification delivery

• Call handling

• Data consistency

• Trust synchronization

• Unexpected failures

---

# General Principles

Every edge case must follow these principles.

• Never compromise security.

• Never leave the application in an inconsistent state.

• Never silently corrupt trust information.

• Recover automatically whenever possible.

• Request user intervention only when recovery is impossible.

• Always preserve user privacy.

• Every failure must end in a deterministic state.

---

# Pairing Edge Cases

## QR Code Expires Before Scan

Scenario

The user generates a QR code but waits too long before scanning.

Expected Behavior

• Pairing immediately fails.

• The QR code becomes invalid.

• A new QR code must be generated.

No previous pairing information is retained.

---

## QR Code Scanned Multiple Times

Scenario

The same QR code is scanned multiple times.

Expected Behavior

• Only the first successful pairing is accepted.

• All subsequent attempts are rejected.

• The QR code is permanently invalidated after successful use.

---

## Multiple QR Codes Generated

Scenario

The user repeatedly generates new QR codes.

Expected Behavior

• Only the newest QR code remains valid.

• Every previously generated QR code immediately expires.

---

## Android App Closed During Pairing

Expected Behavior

• Pairing session is cancelled.

• Temporary pairing information is destroyed.

• No trust relationship is created.

---

## macOS App Closed During Pairing

Expected Behavior

• Pairing immediately terminates.

• Android returns to the unpaired state.

• User must restart pairing.

---

## Internet Disconnects During Pairing

Expected Behavior

• Pairing fails.

• Temporary session is deleted.

• Devices remain unpaired.

• User restarts the pairing process.

---

# Authentication Edge Cases

## Authentication Failure

Scenario

Authentication fails after devices connect.

Expected Behavior

• Communication terminates immediately.

• No commands are executed.

• Session information is discarded.

---

## Public Key Mismatch

Scenario

Stored public key differs from the received identity.

Expected Behavior

• Trust validation fails.

• Communication stops.

• Device is considered no longer trusted.

• Re-pairing becomes mandatory.

---

## Unknown Device Attempts Connection

Expected Behavior

• Connection rejected.

• No authentication continues.

• No information is disclosed.

---

# Connectivity Edge Cases

## Temporary Internet Loss

Expected Behavior

• Existing trust remains unchanged.

• Communication pauses.

• Automatic reconnection begins when connectivity returns.

---

## Backend Unavailable

Expected Behavior

• Existing trust remains intact.

• Communication becomes temporarily unavailable.

• Application informs the user of connectivity issues.

• Automatic retry continues.

---

## Backend Restart

Expected Behavior

• Backend restart does not invalidate pairing.

• Existing sessions reconnect automatically.

• Authentication occurs again.

• Trust is revalidated.

• No QR re-pairing is required.

• No user interaction is required.

Reconnection follows the standard reconnect timing: 1 second initial delay, exponential backoff, 30 second maximum delay, with random jitter.

---

## High Network Latency

Expected Behavior

• Delayed communication is tolerated.

• Duplicate processing is prevented.

• Security verification remains unchanged.

---

## Heartbeat Missed

Scenario

Expected heartbeat (sent every 30 seconds) is not received.

Expected Behavior

• Session considered unhealthy once the connection timeout of 90 seconds is reached.

• Communication suspended.

• Automatic reconnection begins using standard reconnect timing.

---

## Reconnection After Long Offline Period

Scenario

A device reconnects after being offline for an extended period.

Expected Behavior

• Pairing remains valid, since pairing persists until manually revoked.

• No QR code is required to reconnect.

• Trust validation and authentication occur as part of normal reconnection.

---

# Device Lifecycle Edge Cases

## Android Restart

Expected Behavior

• Secure storage remains intact.

• Trust remains intact.

• Services restart.

• Authentication occurs during reconnection.

---

## macOS Restart

Expected Behavior

• Menu bar application launches automatically if enabled.

• Trust remains unchanged.

• Secure communication resumes after authentication.

---

## Device Sleeps

Expected Behavior

• Communication pauses.

• Trust remains valid.

• Authentication occurs after wake.

---

## Device Hibernation

Expected Behavior

Same behavior as sleep.

---

## Device Time Changes

Scenario

User manually changes system time.

Expected Behavior

• Security mechanisms relying on timestamps validate packet freshness safely.

• Trust is unaffected.

• Invalid packets remain rejected.

---

# Application Lifecycle Edge Cases

## Android Application Force Closed

Expected Behavior

• Background services stop.

• Communication pauses.

• Existing trust remains valid.

• Communication resumes after restart and authentication.

---

## macOS Application Quit

Expected Behavior

• Menu bar icon disappears.

• Communication stops.

• Trust remains stored.

• Communication resumes when the application launches again.

---

## Application Update

Expected Behavior

• Trust information remains preserved.

• Secure storage remains unchanged.

• Authentication occurs after update.

---

## Application Reinstallation

Expected Behavior

• New cryptographic identity generated.

• Existing trust invalidated.

• Full re-pairing required.

---

# Permission Edge Cases

## Notification Permission Revoked

Expected Behavior

• Notification synchronization stops.

• Other features continue where possible.

• User receives guidance to restore permission.

---

## Notification Reply Permission Revoked

Expected Behavior

• Notifications remain visible.

• Reply feature becomes unavailable.

---

## Call Permission Revoked

Expected Behavior

• Call management becomes unavailable.

• Remaining features continue normally.

---

# Notification Edge Cases

## Duplicate Notification

Expected Behavior

• Duplicate display prevented.

• Existing notification updated if appropriate.

---

## Notification Arrives While Offline

Expected Behavior

• Notification cannot be delivered.

• No inconsistent state created.

• Future notifications continue normally after reconnection.

---

## Notification Deleted On Phone

Expected Behavior

• macOS updates its displayed notification if synchronization supports deletion.

---

## Very Large Notification

Expected Behavior

• The complete notification payload is transmitted; no artificial truncation occurs during transmission.

• The native macOS notification banner may truncate long text according to normal macOS behavior.

• The full content remains available and readable via the scrollable Notification Detail View.

• Application remains stable.

---

## Multi-Line Notification Message

Expected Behavior

• Full multi-line content is transmitted without truncation.

• The Notification Detail View displays the complete message inside its scrollable container.

• The native banner follows normal macOS truncation behavior.

---

## Notification Contains Emoji

Expected Behavior

• Emoji are transmitted and displayed as part of the notification content without corruption.

---

## Rich Text Content

Scenario

The originating Android notification contains rich text formatting.

Expected Behavior

• Rich text is converted to plain text where necessary for transmission and display.

• No formatting-related transmission failures occur.

---

## Notification Already Truncated By Originating Application

Scenario

The originating Android application itself truncates the notification text before MacEcho receives it.

Expected Behavior

• MacEcho transmits and displays whatever content Android's NotificationListenerService exposes.

• MacEcho does not attempt to recover content that Android never made available.

---

## Missing Sender Information

Scenario

A notification does not include identifiable sender information.

Expected Behavior

• The Notification Detail View omits the sender field rather than displaying incorrect or placeholder information.

• Application icon, app name, timestamp, and content continue to display normally.

---

## Notification Received While macOS Is Locked

Expected Behavior

• The native banner shows only that a notification was received and the originating application's icon.

• Notification title, message body, images, and attachments remain hidden until the Mac is unlocked.

• Quick reply remains disabled until the Mac is unlocked.

---

# Call Handling Edge Cases

## Incoming Call Ends Before User Responds

Expected Behavior

• Call notification disappears.

• No further action executed.

---

## Multiple Incoming Calls

Expected Behavior

• Calls handled according to Android operating system behavior.

• Mac interface reflects current call state.

---

## User Accepts Call On Phone

Expected Behavior

• macOS immediately updates the call state.

---

## User Rejects Call On Phone

Expected Behavior

• macOS removes the call interface.

---

# Ring Phone Edge Cases

## Multiple Ring Requests

Expected Behavior

• Duplicate requests ignored.

• Existing ring session continues.

---

## Phone Already Ringing

Expected Behavior

• Additional ring requests have no effect.

---

## Phone Offline

Expected Behavior

• Ring request cannot be delivered.

• User informed accordingly.

---

# Trust Synchronization Edge Cases

## Android Unpairs While Mac Offline

Expected Behavior

• Android removes trust immediately.

• Mac detects failed authentication during future reconnection.

• Mac removes obsolete trust automatically.

---

## Mac Unpairs While Android Offline

Expected Behavior

Identical behavior.

Both devices eventually converge to the same trust state.

---

## Trust Database Corruption

Expected Behavior

• Trust validation fails safely.

• Communication stops.

• User performs a new pairing.

---

# Backend Edge Cases

## Duplicate Packet Delivery

Expected Behavior

• Duplicate packet identified by Packet UUID or stale Session Sequence Number.

• Duplicate packet ignored.

• Action executes only once.

---

## Packet Arrives Out Of Order

Expected Behavior

• Session Sequence Number (starting at 1 per session, incremented per outgoing packet) determines ordering.

• Out-of-order packets are buffered temporarily.

• Missing packets are handled according to protocol recovery rules.

• Invalid ordering never corrupts application state.

---

## Packet Outside Allowed Clock Skew

Scenario

A packet's Timestamp falls outside the allowed clock skew.

Expected Behavior

• Packet rejected.

• Communication continues normally using subsequent valid packets.

---

## Packet Corruption

Expected Behavior

• Packet rejected.

• Communication continues normally.

---

# User Behavior Edge Cases

## User Clicks Reply Repeatedly

Expected Behavior

• Duplicate replies prevented where appropriate.

---

## User Presses Ring Phone Repeatedly

Expected Behavior

• Existing ring session maintained.

• Additional requests ignored.

---

## User Attempts Unsupported Feature

Expected Behavior

• Clear explanation provided.

• No unexpected behavior occurs.

---

# Data Consistency

Whenever inconsistent information exists:

• Local trust always takes precedence over backend state.

• Authentication always overrides assumptions.

• Invalid state transitions are rejected.

• Security always takes priority over convenience.

---

# Recovery Principles

Whenever possible, MacEcho should recover automatically.

Automatic recovery includes:

• Reconnection.

• Re-authentication.

• Session recreation.

• Notification resynchronization where supported.

User intervention should be required only when security demands it.

---

# Edge Case Review Checklist

Before implementing any new feature, verify:

✓ Does it define failure behavior?

✓ Does it preserve trust?

✓ Does it maintain privacy?

✓ Does it recover safely?

✓ Does it avoid inconsistent states?

✓ Does it preserve security?

✓ Does it avoid duplicate execution?

✓ Does it handle interrupted communication?

✓ Is the edge case documented?

---

# Conclusion

Edge cases are not exceptional situations—they are expected behaviors that every robust system must handle correctly.

MacEcho is designed to behave predictably under both normal and abnormal operating conditions.

Every failure path must preserve security, maintain consistency, and either recover automatically or guide the user toward a safe resolution.

This document serves as the authoritative reference for handling non-standard scenarios throughout the MacEcho platform.