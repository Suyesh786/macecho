// PermissionsViewController.swift — Phase 12.1
//
// Permissions page — displays required system permissions with their
// current grant status. Each row shows the permission name, a status
// badge, and an "Open Settings" link.
//
// Per 06_UI_GUIDELINES.md §Android Permission Experience (applied to macOS):
//   "Before requesting permission, the application should explain:
//    why the permission is required, what functionality depends on it,
//    and whether it can be granted later."
//
// Permissions shown in Phase 12.1 (statically — real checks are Phase 13+):
//   • Local Network     — required for LAN discovery fallback
//   • Notifications     — required to display Android notifications
//   • Accessibility     — required for future input features (Phase 20+)
//   • Launch at Login   — allows background operation on startup
//
// Must NOT contain:
//   - Real permission checks   → Phase 13+
//   - Permission request APIs  → Phase 13+
//   - Business logic

import AppKit

@MainActor
final class PermissionsViewController: NSViewController, Navigable {

    weak var navigationController: AppNavigationController?

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    // -------------------------------------------------------------------------
    // Interface
    // -------------------------------------------------------------------------

    private struct PermissionItem {
        let symbol: String
        let badgeColor: NSColor
        let iconColor: NSColor
        let name: String
        let purpose: String
        // Phase 12.1: static placeholder. Phase 13+ checks real grant status.
        let granted: Bool
    }

    private func buildInterface() {
        let header = makePageHeader(title: "Permissions")
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let sep = makeSeparator()
        sep.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sep)

        let permissions: [PermissionItem] = [
            PermissionItem(
                symbol: "network",
                badgeColor: NSColor(red: 0.86, green: 0.92, blue: 1.00, alpha: 1),
                iconColor:  NSColor(red: 0.18, green: 0.46, blue: 0.90, alpha: 1),
                name: "Local Network",
                purpose: "Device discovery on your network",
                granted: false
            ),
            PermissionItem(
                symbol: "bell.badge.fill",
                badgeColor: NSColor(red: 1.00, green: 0.90, blue: 0.86, alpha: 1),
                iconColor:  NSColor(red: 0.90, green: 0.35, blue: 0.18, alpha: 1),
                name: "Notifications",
                purpose: "Show Android notifications on macOS",
                granted: false
            ),
            PermissionItem(
                symbol: "accessibility",
                badgeColor: NSColor(red: 0.91, green: 0.88, blue: 1.00, alpha: 1),
                iconColor:  NSColor(red: 0.42, green: 0.32, blue: 0.82, alpha: 1),
                name: "Accessibility",
                purpose: "Required for future input features",
                granted: false
            ),
            PermissionItem(
                symbol: "clock.arrow.circlepath",
                badgeColor: NSColor(red: 0.87, green: 0.96, blue: 0.87, alpha: 1),
                iconColor:  NSColor(red: 0.16, green: 0.62, blue: 0.30, alpha: 1),
                name: "Launch at Login",
                purpose: "Keep MacEcho running automatically",
                granted: false
            ),
        ]

        var prevAnchor = sep.bottomAnchor
        for item in permissions {
            let row = makePermissionRow(item)
            row.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: prevAnchor),
                row.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                row.heightAnchor.constraint(equalToConstant: 64),
            ])
            prevAnchor = row.bottomAnchor

            // Separator between rows
            let rowSep = makeSeparator()
            rowSep.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(rowSep)
            NSLayoutConstraint.activate([
                rowSep.topAnchor.constraint(equalTo: prevAnchor),
                rowSep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                rowSep.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                rowSep.heightAnchor.constraint(equalToConstant: 1),
            ])
            prevAnchor = rowSep.bottomAnchor
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 48),

            sep.topAnchor.constraint(equalTo: header.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    // -------------------------------------------------------------------------
    // Permission row factory
    // -------------------------------------------------------------------------

    private func makePermissionRow(_ item: PermissionItem) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        // Badge
        let badgeCfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let badgeImg = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(badgeCfg)
        let badgeIconView = NSImageView()
        badgeIconView.image = badgeImg
        badgeIconView.contentTintColor = item.iconColor

        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = item.badgeColor.cgColor
        badge.layer?.cornerRadius = 9
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeIconView.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeIconView)

        // Name label
        let nameLabel = NSTextField(labelWithString: item.name)
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor

        // Purpose label
        let purposeLabel = NSTextField(labelWithString: item.purpose)
        purposeLabel.font = .systemFont(ofSize: 11, weight: .regular)
        purposeLabel.textColor = .secondaryLabelColor

        // Text stack
        let textStack = NSStackView(views: [nameLabel, purposeLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Status badge
        let statusBadge = NSView()
        statusBadge.wantsLayer = true
        statusBadge.layer?.cornerRadius = 5

        let statusLabel = NSTextField(labelWithString: item.granted ? "Granted" : "Not Granted")
        statusLabel.font = .systemFont(ofSize: 10, weight: .semibold)

        if item.granted {
            statusBadge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.15).cgColor
            statusLabel.textColor = NSColor.systemGreen
        } else {
            statusBadge.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.15).cgColor
            statusLabel.textColor = NSColor.systemOrange
        }

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.addSubview(statusLabel)

        // Right side stack (status badge + settings button)
        let settingsBtn = NSButton(title: "Open Settings", target: self,
                                   action: #selector(openSystemSettings))
        settingsBtn.bezelStyle = .inline
        settingsBtn.font = .systemFont(ofSize: 10, weight: .regular)
        settingsBtn.isBordered = false
        let settingsAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
        ]
        settingsBtn.attributedTitle = NSAttributedString(string: "Open Settings",
                                                          attributes: settingsAttr)

        let rightStack = NSStackView(views: [statusBadge, settingsBtn])
        rightStack.orientation = .vertical
        rightStack.alignment = .trailing
        rightStack.spacing = 3
        rightStack.setContentHuggingPriority(.required, for: .horizontal)
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        // Horizontal row
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 10
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.addArrangedSubview(badge)
        hStack.addArrangedSubview(textStack)
        hStack.addArrangedSubview(rightStack)

        container.addSubview(hStack)

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 36),
            badge.heightAnchor.constraint(equalToConstant: 36),
            badgeIconView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeIconView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badgeIconView.widthAnchor.constraint(equalToConstant: 18),
            badgeIconView.heightAnchor.constraint(equalToConstant: 18),

            statusLabel.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 5),
            statusLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -5),
            statusLabel.topAnchor.constraint(equalTo: statusBadge.topAnchor, constant: 2),
            statusLabel.bottomAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: -2),

            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            hStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    @objc private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func goBack() { navigationController?.pop() }

    // -------------------------------------------------------------------------
    // Shared helpers
    // -------------------------------------------------------------------------

    private func makePageHeader(title: String) -> NSView {
        let container = NSView()
        let backCfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        var chevronImg = NSImage(systemSymbolName: "chevron.left",
                                 accessibilityDescription: "Back")?
            .withSymbolConfiguration(backCfg)
        if #available(macOS 12, *) {
            chevronImg = chevronImg?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(paletteColors: [.systemBlue]))
        }
        let backBtn = NSButton(title: "", target: self, action: #selector(goBack))
        backBtn.isBordered = false
        backBtn.image = chevronImg
        backBtn.imagePosition = .imageLeading
        backBtn.attributedTitle = NSAttributedString(string: " Back", attributes: [
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        ])
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(backBtn)
        container.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            backBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    private func makeSeparator() -> NSView {
        let box = NSBox(); box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }
}
