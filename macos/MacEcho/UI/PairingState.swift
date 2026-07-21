// PairingState.swift — Phase 12.1
//
// Observable pairing state enum that drives the HomeViewController status
// indicator. All state values in Phase 12.1 default to `.unpaired`.
//
// Phase 12.2 wires this enum to real session state from the pairing manager.
//
// Must NOT contain:
//   - Trust operations         → Phase 12.2
//   - Key exchange             → Phase 12.2
//   - Network observation      → Phase 15
//   - Authentication           → Phase 13

import AppKit

/// Observable pairing state for the macOS menu bar application.
/// Per 06_UI_GUIDELINES.md §macOS Status Indicators: "each state should
/// have clear visual distinction."
enum PairingState: Sendable {
    case unpaired
    case pairing
    case paired
    case offline

    /// Short display label shown alongside the status dot in the header.
    var label: String {
        switch self {
        case .unpaired: "Unpaired"
        case .pairing:  "Pairing…"
        case .paired:   "Paired"
        case .offline:  "Offline"
        }
    }

    /// Color of the 8pt circular status indicator dot.
    var dotColor: NSColor {
        switch self {
        case .unpaired: NSColor(white: 0.72, alpha: 1.0)
        case .pairing:  .systemYellow
        case .paired:   .systemGreen
        case .offline:  .systemRed
        }
    }
}
