import AppKit

/// AppDelegate — Phase 5
///
/// Application lifecycle entry point. Thin orchestrator responsible for:
///   1. Setting up the menu bar presence via StatusItemController
///
/// What does NOT belong here:
///   - Backend communication          → Phase 7
///   - WebSocket logic                → Phase 7
///   - Pairing logic                  → Phase 12
///   - Cryptography                   → Phase 8
///   - Authentication                 → Phase 13
///   - Notification handling          → Phase 16/17
///   - Business logic of any kind
///
/// The StatusItemController owns the NSStatusItem and NSPopover.
/// AppDelegate only holds a strong reference so the controller is not
/// deallocated — it does not call any methods on it after creation.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Strong reference — prevents ARC from deallocating the controller.
    // AppDelegate calls no methods on this after initialisation.
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()
    }
}
