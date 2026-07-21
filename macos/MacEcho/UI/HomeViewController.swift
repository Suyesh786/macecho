// HomeViewController.swift — Phase 12.1
//
// The home page of the MacEcho menu bar popover.
// Replaces the Phase 5 PopoverViewController with the polished card layout
// matching the Phase 12.1 design reference.
//
// Layout (top → bottom, total 468 pt):
//   Header (72 pt)       — icon badge + "MacEcho" + status dot
//   Separator (1 pt)
//   Pair New Device card (76 pt)
//   Ring Phone card      (76 pt)
//   Trusted Devices card (76 pt)
//   Separator (1 pt)
//   Permissions card     (76 pt)
//   Separator (1 pt)
//   About MacEcho row    (44 pt)
//   Quit MacEcho row     (44 pt)
//   ──────────────────────────────
//   Total: 467 pt (≈ 468 pt popover)
//
// Must NOT contain:
//   - Pairing logic           → Phase 12.2
//   - Trust / authentication  → Phase 12.2 / 13
//   - Network communication   → Phase 15
//   - Business logic of any kind

import AppKit

@MainActor
final class HomeViewController: NSViewController, Navigable {

    // -------------------------------------------------------------------------
    // Navigable
    // -------------------------------------------------------------------------

    weak var navigationController: AppNavigationController?

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// Pairing state that drives the header status indicator.
    /// Phase 12.1 defaults to .unpaired.
    /// Phase 12.2 wires this to real session state.
    private var pairingState: PairingState = .unpaired {
        didSet { updateStatusIndicator() }
    }

    // Status indicator subview references for live updates
    private weak var statusDot: NSView?
    private weak var statusLabel: NSTextField?

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    // -------------------------------------------------------------------------
    // Interface Construction
    // -------------------------------------------------------------------------

    private func buildInterface() {
        // Each element is pinned in a vertical chain using a rolling anchor.
        var topAnchor = view.topAnchor

        func pin(_ v: NSView, height: CGFloat) {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: topAnchor),
                v.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                v.heightAnchor.constraint(equalToConstant: height),
            ])
            topAnchor = v.bottomAnchor
        }

        // ── Header ─────────────────────────────────────────────────────────
        pin(makeHeader(), height: 72)

        // ── Separator 1 ────────────────────────────────────────────────────
        pin(makeSeparator(), height: 1)

        // ── Primary action cards ────────────────────────────────────────────
        pin(card(
            symbol: "qrcode",
            badgeColor: NSColor(red: 0.86, green: 0.90, blue: 1.00, alpha: 1),
            iconColor:  NSColor(red: 0.24, green: 0.35, blue: 0.90, alpha: 1),
            title: "Pair New Device",
            description: "Generate a QR code to pair a new device",
            action: { [weak self] in self?.navigationController?.push(PairDeviceViewController()) }
        ), height: 76)

        pin(card(
            symbol: "bell.fill",
            badgeColor: NSColor(red: 0.91, green: 0.88, blue: 1.00, alpha: 1),
            iconColor:  NSColor(red: 0.41, green: 0.31, blue: 0.82, alpha: 1),
            title: "Ring Phone",
            description: "Make your connected phone ring",
            action: { [weak self] in self?.navigationController?.push(RingPhoneViewController()) }
        ), height: 76)

        pin(card(
            symbol: "laptopcomputer.and.iphone",
            badgeColor: NSColor(red: 0.87, green: 0.96, blue: 0.87, alpha: 1),
            iconColor:  NSColor(red: 0.16, green: 0.62, blue: 0.30, alpha: 1),
            title: "Trusted Devices",
            description: "View and manage your trusted devices",
            action: { [weak self] in self?.navigationController?.push(TrustedDevicesViewController()) }
        ), height: 76)

        // ── Separator 2 ────────────────────────────────────────────────────
        pin(makeSeparator(), height: 1)

        // ── Permissions card ────────────────────────────────────────────────
        pin(card(
            symbol: "checkmark.shield.fill",
            badgeColor: NSColor(red: 1.00, green: 0.94, blue: 0.84, alpha: 1),
            iconColor:  NSColor(red: 0.79, green: 0.53, blue: 0.04, alpha: 1),
            title: "Permissions",
            description: "Manage system permissions and access",
            action: { [weak self] in self?.navigationController?.push(PermissionsViewController()) }
        ), height: 76)

        // ── Separator 3 ────────────────────────────────────────────────────
        pin(makeSeparator(), height: 1)

        // ── About row ───────────────────────────────────────────────────────
        let aboutRow = BottomRowView(
            symbol: "info.circle.fill",
            badgeColor: NSColor(red: 0.91, green: 0.91, blue: 0.93, alpha: 1),
            iconColor:  NSColor(red: 0.42, green: 0.42, blue: 0.46, alpha: 1),
            title: "About MacEcho"
        )
        aboutRow.action = { NSApp.orderFrontStandardAboutPanel(nil) }
        pin(aboutRow, height: 44)

        // ── Quit row ────────────────────────────────────────────────────────
        let quitRow = BottomRowView(
            symbol: "rectangle.portrait.and.arrow.right.fill",
            badgeColor: NSColor(red: 1.00, green: 0.88, blue: 0.88, alpha: 1),
            iconColor:  NSColor(red: 0.83, green: 0.18, blue: 0.18, alpha: 1),
            title: "Quit MacEcho"
        )
        quitRow.action = { NSApplication.shared.terminate(nil) }
        pin(quitRow, height: 44)
    }

    // -------------------------------------------------------------------------
    // Header
    // -------------------------------------------------------------------------

    private func makeHeader() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // App icon badge: 40 × 40, systemBlue, antenna symbol
        let iconBadge = NSView()
        iconBadge.wantsLayer = true
        iconBadge.layer?.backgroundColor = NSColor.systemBlue.cgColor
        iconBadge.layer?.cornerRadius = 10
        iconBadge.translatesAutoresizingMaskIntoConstraints = false

        let antennaCfg = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let antennaImg = NSImage(
            systemSymbolName: "antenna.radiowaves.left.and.right",
            accessibilityDescription: "MacEcho"
        )?.withSymbolConfiguration(antennaCfg)
        let antennaView = NSImageView()
        antennaView.image = antennaImg
        antennaView.contentTintColor = .white
        antennaView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(antennaView)

        // "MacEcho" title
        let titleLabel = NSTextField(labelWithString: "MacEcho")
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status dot: 8 × 8 circle
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = pairingState.dotColor.cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        statusDot = dot

        // Status label
        let statLabel = NSTextField(labelWithString: pairingState.label)
        statLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statLabel.textColor = .secondaryLabelColor
        statLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel = statLabel

        // Status group (dot + label)
        let statusGroup = NSStackView(views: [dot, statLabel])
        statusGroup.orientation = .horizontal
        statusGroup.alignment = .centerY
        statusGroup.spacing = 5
        statusGroup.translatesAutoresizingMaskIntoConstraints = false

        [iconBadge, titleLabel, statusGroup].forEach { container.addSubview($0) }

        NSLayoutConstraint.activate([
            // Icon badge
            iconBadge.widthAnchor.constraint(equalToConstant: 40),
            iconBadge.heightAnchor.constraint(equalToConstant: 40),
            iconBadge.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconBadge.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            // Antenna icon inside badge
            antennaView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            antennaView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            antennaView.widthAnchor.constraint(equalToConstant: 22),
            antennaView.heightAnchor.constraint(equalToConstant: 22),

            // App title
            titleLabel.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusGroup.leadingAnchor, constant: -8),

            // Status group (right-aligned)
            statusGroup.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            statusGroup.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            // Status dot fixed size
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
        ])

        return container
    }

    // -------------------------------------------------------------------------
    // Factories
    // -------------------------------------------------------------------------

    private func card(
        symbol: String, badgeColor: NSColor, iconColor: NSColor,
        title: String, description: String, action: @escaping () -> Void
    ) -> ActionCardView {
        let v = ActionCardView(
            symbol: symbol, badgeColor: badgeColor, iconColor: iconColor,
            title: title, description: description
        )
        v.action = action
        return v
    }

    private func makeSeparator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    // -------------------------------------------------------------------------
    // Status update
    // -------------------------------------------------------------------------

    private func updateStatusIndicator() {
        statusDot?.layer?.backgroundColor = pairingState.dotColor.cgColor
        statusLabel?.stringValue = pairingState.label
    }
}
