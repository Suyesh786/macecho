// PopoverViewController.swift
//
// ──────────────────────────────────────────────────────────────────────────────
// SUPERSEDED BY PHASE 12.1
// ──────────────────────────────────────────────────────────────────────────────
//
// This file contained the Phase 5 UI scaffold (static status labels + inert
// buttons). It has been replaced by the following classes introduced in Phase 12.1:
//
//   AppNavigationController  — NSPopover contentViewController, owns page stack
//   HomeViewController       — the home page (card layout)
//   PairDeviceViewController — QR pairing page
//   TrustedDevicesViewController
//   PermissionsViewController
//   RingPhoneViewController
//
// The file is retained in the project to preserve its Phase 5 documentation
// history. The class definition is kept as an empty stub so that any
// accidental reference produces a clear compiler error rather than a linker
// error.
//
// Phase 5 must-not list remains valid for all successor view controllers.
//
// Original file: Phase 5 — commit history preserved in git.

import AppKit

/// Phase 5 stub — class body intentionally empty.
/// The Phase 12.1 navigation stack replaces this class entirely.
/// See AppNavigationController + HomeViewController.
final class PopoverViewController: NSViewController {
    override func loadView() {
        // Intentionally empty — this class is no longer instantiated.
        // StatusItemController uses AppNavigationController as contentViewController.
        view = NSView()
    }
}
