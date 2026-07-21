import AppKit

/// StatusItemController — Phase 5
///
/// Owns the NSStatusItem (menu bar icon) and the NSPopover it controls.
///
/// Responsibilities:
///   - Create and configure the menu bar status item
///   - Create and configure the popover
///   - Toggle the popover open/closed on status item click
///
/// Must NOT contain:
///   - Backend communication          → Phase 7
///   - WebSocket logic                → Phase 7
///   - Pairing logic                  → Phase 12
///   - Cryptography                   → Phase 8
///   - Authentication                 → Phase 13
///   - Connection status observation  → Phase 15
///   - Notification handling          → Phase 16/17
///   - Business logic of any kind
///
/// AppDelegate creates exactly one instance of this class and stores it.
/// No other class interacts with NSStatusItem directly.
final class StatusItemController: NSObject {

    // -------------------------------------------------------------------------
    // Private State
    // -------------------------------------------------------------------------

    private let statusItem: NSStatusItem
    private let popover: NSPopover

    // -------------------------------------------------------------------------
    // Initialisation
    // -------------------------------------------------------------------------

    override init() {
        // Status item ─ variable length lets the system size the button
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Popover ─ configured before super.init so button target can be set
        popover = NSPopover()
        // Phase 12.1: AppNavigationController replaces the Phase 5 PopoverViewController.
        // It manages the full page stack (Home → PairDevice / RingPhone / etc.).
        // Popover size is driven by AppNavigationController.preferredContentSize.
        popover.contentViewController = AppNavigationController()
        popover.behavior = .transient   // closes automatically when focus leaves
        popover.animates = true         // Phase 12.1: smooth popover open/close

        super.init()

        configureStatusItemButton()
    }

    // -------------------------------------------------------------------------
    // Private Helpers
    // -------------------------------------------------------------------------

    private func configureStatusItemButton() {
        guard let button = statusItem.button else { return }

        // Placeholder icon using an SF Symbol available on macOS 11+.
        // A proper branded icon will replace this in a later UI phase.
        if let icon = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right",
                              accessibilityDescription: "MacEcho") {
            button.image = icon
        } else {
            // Fallback text if the symbol is unavailable (should not occur on 13+)
            button.title = "MacEcho"
        }

        button.action = #selector(statusItemButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    @objc private func statusItemButtonClicked(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            // Activate the process so it is in the foreground, then explicitly make
            // the popover's window the key window. Without makeKey(), the popover
            // is visible but not key, so the user must click inside it once before
            // any button or interaction works.
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
