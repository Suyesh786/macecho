import AppKit

/// PopoverViewController — Phase 5
///
/// PRESENTATIONAL ONLY. Renders the macOS main interface scaffold as described
/// in 06_UI_GUIDELINES.md §macOS Main Interface.
///
/// Documented items displayed (per UI guidelines):
///   • Device status        — static placeholder label
///   • Connected device     — static placeholder label
///   • Generate QR          — inert button (Phase 12)
///   • Ring phone           — inert button (Phase 21)
///   • Unpair device        — inert button (Phase 13)
///   • Launch at login      — inert button (future phase)
///   • About                — inert button (future phase)
///   • Quit                 — WIRED: terminates the application
///
/// Permitted responsibilities:
///   - Render static UI
///   - Wire the Quit action
///
/// Must NOT contain:
///   - Backend communication          → Phase 7
///   - WebSocket logic                → Phase 7
///   - QR generation                  → Phase 12
///   - Pairing / unpairing logic      → Phase 12 / Phase 13
///   - Authentication                 → Phase 13
///   - Connection status observation  → Phase 15
///   - Notification display           → Phase 17
///   - Ring phone logic               → Phase 21
///   - Persistence / UserDefaults     → future phase
///   - Keychain usage                 → Phase 8
///   - Business logic of any kind
///
/// All status values are static placeholders in Phase 5.
/// They will be replaced with live data in later phases.
final class PopoverViewController: NSViewController {

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    override func loadView() {
        // Build the view programmatically — no XIB or storyboard dependency.
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 340))
        view = root
        buildInterface(in: root)
    }

    // -------------------------------------------------------------------------
    // Interface Construction
    // -------------------------------------------------------------------------

    private func buildInterface(in root: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        // ── Status section ────────────────────────────────────────────────────

        stack.addArrangedSubview(makeSectionHeader("Status"))
        stack.addArrangedSubview(makeStatusRow(label: "Device Status", value: "—"))
        stack.addArrangedSubview(makeStatusRow(label: "Connected Device", value: "—"))
        stack.addArrangedSubview(makeDivider())

        // ── Actions section ───────────────────────────────────────────────────

        stack.addArrangedSubview(makeSectionHeader("Actions"))

        // Generate QR — inert in Phase 5 (Phase 12)
        stack.addArrangedSubview(makeMenuRow(title: "Generate QR", action: nil))

        // Ring Phone — inert in Phase 5 (Phase 21)
        stack.addArrangedSubview(makeMenuRow(title: "Ring Phone", action: nil))

        // Unpair Device — inert in Phase 5 (Phase 13)
        stack.addArrangedSubview(makeMenuRow(title: "Unpair Device", action: nil))

        stack.addArrangedSubview(makeDivider())

        // ── Preferences section ───────────────────────────────────────────────

        // Launch at Login — inert in Phase 5 (future phase)
        stack.addArrangedSubview(makeMenuRow(title: "Launch at Login", action: nil))

        // About — inert in Phase 5 (future phase)
        stack.addArrangedSubview(makeMenuRow(title: "About MacEcho", action: nil))

        stack.addArrangedSubview(makeDivider())

        // ── Quit ─ the only wired action in Phase 5 ───────────────────────────
        stack.addArrangedSubview(makeMenuRow(title: "Quit", action: #selector(quitApplication)))
    }

    // -------------------------------------------------------------------------
    // View Factories
    // -------------------------------------------------------------------------

    private func makeSectionHeader(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            container.widthAnchor.constraint(equalToConstant: 260),
        ])
        return container
    }

    private func makeStatusRow(label: String, value: String) -> NSView {
        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 13)
        labelField.translatesAutoresizingMaskIntoConstraints = false

        let valueField = NSTextField(labelWithString: value)
        valueField.font = .systemFont(ofSize: 13)
        valueField.textColor = .secondaryLabelColor
        valueField.alignment = .right
        valueField.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelField)
        container.addSubview(valueField)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 260),
            container.heightAnchor.constraint(equalToConstant: 28),
            labelField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            labelField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            valueField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelField.trailingAnchor.constraint(lessThanOrEqualTo: valueField.leadingAnchor, constant: -8),
        ])
        return container
    }

    private func makeMenuRow(title: String, action: Selector?) -> NSView {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .recessed
        button.isBordered = false
        button.alignment = .left
        button.font = .systemFont(ofSize: 13)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Inert items have no action — make this visually clear without disabling
        // (disabled items appear greyed-out, which could be mistaken for a bug;
        //  for now they appear as normal text. A visual treatment for
        //  "coming soon" items can be added in a later UI phase.)

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 260),
            container.heightAnchor.constraint(equalToConstant: 28),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    private func makeDivider() -> NSView {
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 260),
            divider.heightAnchor.constraint(equalToConstant: 1),
        ])
        return divider
    }

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    /// Quit — the only wired action in Phase 5.
    /// All other actions belong to later phases.
    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
