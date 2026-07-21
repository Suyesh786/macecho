// TrustedDevicesViewController.swift — Phase 12.1
//
// Trusted Devices page — shows an empty state in Phase 12.1.
// The card layout is designed to accommodate a future device list
// when real pairing data exists (Phase 12.2+).
//
// Per 06_UI_GUIDELINES.md §Empty States:
//   "Empty screens should always explain why they are empty."
//   "Empty screens should guide users toward the next logical action."
//
// Must NOT contain:
//   - Pairing logic        → Phase 12.2
//   - Trust management     → Phase 12.2 / 13
//   - Keychain access      → Phase 9 (already complete)

import AppKit

@MainActor
final class TrustedDevicesViewController: NSViewController, Navigable {

    weak var navigationController: AppNavigationController?

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
    // Interface
    // -------------------------------------------------------------------------

    private func buildInterface() {
        let header = makePageHeader(title: "Trusted Devices")
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let sep = makeSeparator()
        sep.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sep)

        // ── Empty state ────────────────────────────────────────────────────
        let iconCfg = NSImage.SymbolConfiguration(pointSize: 48, weight: .thin)
        let emptyIcon = NSImageView()
        emptyIcon.image = NSImage(systemSymbolName: "laptopcomputer.and.iphone",
                                  accessibilityDescription: nil)?
            .withSymbolConfiguration(iconCfg)
        emptyIcon.contentTintColor = NSColor.tertiaryLabelColor
        emptyIcon.imageScaling = .scaleProportionallyUpOrDown
        emptyIcon.translatesAutoresizingMaskIntoConstraints = false

        let emptyTitle = NSTextField(labelWithString: "No Trusted Devices")
        emptyTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        emptyTitle.textColor = .labelColor
        emptyTitle.alignment = .center
        emptyTitle.translatesAutoresizingMaskIntoConstraints = false

        let emptySubtitle = NSTextField(wrappingLabelWithString:
            "Pair a device to see it here.")
        emptySubtitle.font = .systemFont(ofSize: 13, weight: .regular)
        emptySubtitle.textColor = .secondaryLabelColor
        emptySubtitle.alignment = .center
        emptySubtitle.translatesAutoresizingMaskIntoConstraints = false

        let pairBtn = NSButton(title: "Pair New Device", target: self,
                               action: #selector(openPairDevice))
        pairBtn.bezelStyle = .rounded
        pairBtn.font = .systemFont(ofSize: 13, weight: .regular)
        pairBtn.translatesAutoresizingMaskIntoConstraints = false

        [emptyIcon, emptyTitle, emptySubtitle, pairBtn].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 48),

            sep.topAnchor.constraint(equalTo: header.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),

            emptyIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            emptyIcon.widthAnchor.constraint(equalToConstant: 56),
            emptyIcon.heightAnchor.constraint(equalToConstant: 56),

            emptyTitle.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 14),
            emptyTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            emptySubtitle.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 6),
            emptySubtitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptySubtitle.widthAnchor.constraint(lessThanOrEqualToConstant: 220),

            pairBtn.topAnchor.constraint(equalTo: emptySubtitle.bottomAnchor, constant: 18),
            pairBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    @objc private func openPairDevice() {
        navigationController?.pop()
        // Phase 12.2: navigate directly to PairDeviceViewController
    }

    @objc private func goBack() {
        navigationController?.pop()
    }

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
            let col = NSImage.SymbolConfiguration(paletteColors: [.systemBlue])
            chevronImg = chevronImg?.withSymbolConfiguration(col)
        }

        let backBtn = NSButton(title: "", target: self, action: #selector(goBack))
        backBtn.isBordered = false
        backBtn.image = chevronImg
        backBtn.imagePosition = .imageLeading
        let backAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        ]
        backBtn.attributedTitle = NSAttributedString(string: " Back", attributes: backAttr)
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
