// AppNavigationController.swift — Phase 12.1
//
// Container view controller that replaces the Phase 5 PopoverViewController
// as the NSPopover's contentViewController.
//
// Manages a simple page stack and drives horizontal slide transitions.
//   push(_:)  — slides new page in from the trailing edge (right)
//   pop()     — slides current page out to the trailing edge
//
// Navigation constraints (06_UI_GUIDELINES.md §Navigation Principles):
//   • All navigation stays INSIDE the popover — no new windows, no sheets.
//   • Maximum useful depth: 2 (home → detail). Spec: "extremely shallow."
//   • Animation duration: 0.22 s with ease-in-out curve.
//
// Must NOT contain:
//   - Pairing logic       → Phase 12.2
//   - Business logic of any kind

import AppKit
import Foundation

// MARK: - Navigable

/// Page view controllers that need a reference to their hosting navigation
/// controller should conform to this protocol.
@MainActor
protocol Navigable: AnyObject {
    var navigationController: AppNavigationController? { get set }
}

// MARK: - AppNavigationController

@MainActor
final class AppNavigationController: NSViewController {

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    static let popoverWidth:  CGFloat = 320
    static let popoverHeight: CGFloat = 468

    private static let slideDuration: TimeInterval = 0.22

    // -------------------------------------------------------------------------
    // Private state
    // -------------------------------------------------------------------------

    /// Clip layer — ensures pages are invisible while off-screen.
    private let container = NSView()

    /// Ordered stack. Last element is the currently visible page.
    private var stack: [NSViewController] = []

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    override func loadView() {
        preferredContentSize = NSSize(
            width:  Self.popoverWidth,
            height: Self.popoverHeight
        )
        let root = NSView(frame: NSRect(
            x: 0, y: 0,
            width:  Self.popoverWidth,
            height: Self.popoverHeight
        ))
        root.wantsLayer = true
        view = root

        // Container fills the root view and clips page views during transitions.
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: root.topAnchor),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        // Install the home page as the root of the navigation stack.
        let home = HomeViewController()
        home.navigationController = self
        installRoot(home)
        
        // Single, centralized observer for remote trust revocation.
        // AppNavigationController is always alive for the lifetime of the popover,
        // so this fires exactly once per TRUST_REVOKED event — no duplicate alerts.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showTrustRevokedAlert),
            name: AppSessionManager.trustRevokedNotification,
            object: nil
        )
    }

    // -------------------------------------------------------------------------
    // Trust Revoked Alert (called by centralized notification observer)
    // -------------------------------------------------------------------------

    @objc private func showTrustRevokedAlert() {
        // Pop back to Home first so the user sees the correct (unpaired) state.
        while stack.count > 1 { pop() }
        
        // Small delay so the pop animation finishes before the alert appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let window = self?.view.window else {
                // Popover not visible — show as a standalone panel.
                let alert = NSAlert()
                alert.messageText = "Device Unpaired"
                alert.informativeText = "The paired Android device has removed the trust relationship.\n\nPair a new device to continue using MacEcho."
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
            let alert = NSAlert()
            alert.messageText = "Device Unpaired"
            alert.informativeText = "The paired Android device has removed the trust relationship.\n\nPair a new device to continue using MacEcho."
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: window)
        }
    }

    // -------------------------------------------------------------------------
    // Navigation API
    // -------------------------------------------------------------------------

    /// Pushes `vc` onto the stack, sliding it in from the right.
    func push(_ vc: NSViewController) {
        guard let current = stack.last else { return }
        (vc as? Navigable)?.navigationController = self

        addChild(vc)
        let w = container.bounds.width
        let h = container.bounds.height
        vc.view.frame = NSRect(x: w, y: 0, width: w, height: h)
        container.addSubview(vc.view)
        stack.append(vc)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.slideDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            current.view.animator().frame = NSRect(x: -w, y: 0, width: w, height: h)
            vc.view.animator().frame      = NSRect(x:  0, y: 0, width: w, height: h)
        }
    }

    /// Pops the top page from the stack, sliding it out to the right.
    func pop() {
        guard stack.count > 1 else { return }
        let outgoing = stack.removeLast()
        guard let incoming = stack.last else { return }

        let w = container.bounds.width
        let h = container.bounds.height

        // If the incoming view was somehow removed from the container,
        // re-insert it at the expected left-offscreen position.
        if incoming.view.superview == nil {
            incoming.view.frame = NSRect(x: -w, y: 0, width: w, height: h)
            container.addSubview(incoming.view)
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.slideDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            outgoing.view.animator().frame = NSRect(x:  w, y: 0, width: w, height: h)
            incoming.view.animator().frame = NSRect(x:  0, y: 0, width: w, height: h)
        }

        // Remove the outgoing view after the animation completes.
        // Using Task + sleep avoids the Swift 6 actor-isolation issue that
        // arises from using NSAnimationContext's completionHandler directly.
        Task { @MainActor [weak outgoing] in
            try? await Task.sleep(nanoseconds: 270_000_000) // ≥ slideDuration
            outgoing?.view.removeFromSuperview()
            outgoing?.removeFromParent()
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /// Installs `vc` as the initial (root) page with no animation.
    private func installRoot(_ vc: NSViewController) {
        addChild(vc)
        vc.view.frame = container.bounds
        vc.view.autoresizingMask = [.width, .height]
        container.addSubview(vc.view)
        stack.append(vc)
    }
}
