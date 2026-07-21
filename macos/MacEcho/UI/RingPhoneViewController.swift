// RingPhoneViewController.swift — Phase 12.1
//
// Ring Phone page — shown when there is no paired device.
// The ring button is disabled with a clear explanation.
//
// Phase 12.2: when a paired session exists, the button becomes active and
// sends a RING_REQUEST packet through the relay backend.
//
// Must NOT contain:
//   - Network communication   → Phase 12.2
//   - Packet sending          → Phase 12.2
//   - Session references      → Phase 12.2

import AppKit

@MainActor
final class RingPhoneViewController: NSViewController, Navigable {

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

    private func buildInterface() {
        let header = makePageHeader(title: "Ring Phone")
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let sep = makeSeparator()
        sep.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sep)

        // ── Bell icon ──────────────────────────────────────────────────────
        let bellCfg = NSImage.SymbolConfiguration(pointSize: 52, weight: .thin)
        let bellIcon = NSImageView()
        bellIcon.image = NSImage(systemSymbolName: "bell.slash.fill",
                                 accessibilityDescription: nil)?
            .withSymbolConfiguration(bellCfg)
        bellIcon.contentTintColor = .tertiaryLabelColor
        bellIcon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bellIcon)

        // ── Disabled ring button ───────────────────────────────────────────
        let ringBtn = NSButton(title: "Ring Phone", target: nil, action: nil)
        ringBtn.bezelStyle = .rounded
        ringBtn.font = .systemFont(ofSize: 15, weight: .semibold)
        ringBtn.isEnabled = false   // Phase 12.2: enabled when paired
        ringBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ringBtn)

        // ── Explanation label ──────────────────────────────────────────────
        let noDeviceLabel = NSTextField(wrappingLabelWithString:
            "No device is currently paired.\nPair a device first to ring it.")
        noDeviceLabel.font = .systemFont(ofSize: 13, weight: .regular)
        noDeviceLabel.textColor = .secondaryLabelColor
        noDeviceLabel.alignment = .center
        noDeviceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(noDeviceLabel)

        // ── Pair Device shortcut ───────────────────────────────────────────
        let pairBtn = NSButton(title: "Pair a Device →", target: self,
                               action: #selector(goToPairDevice))
        pairBtn.bezelStyle = .inline
        pairBtn.isBordered = false
        pairBtn.attributedTitle = NSAttributedString(string: "Pair a Device →", attributes: [
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        ])
        pairBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pairBtn)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 48),

            sep.topAnchor.constraint(equalTo: header.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),

            bellIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bellIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            bellIcon.widthAnchor.constraint(equalToConstant: 60),
            bellIcon.heightAnchor.constraint(equalToConstant: 60),

            ringBtn.topAnchor.constraint(equalTo: bellIcon.bottomAnchor, constant: 20),
            ringBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ringBtn.widthAnchor.constraint(equalToConstant: 160),

            noDeviceLabel.topAnchor.constraint(equalTo: ringBtn.bottomAnchor, constant: 14),
            noDeviceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noDeviceLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 230),

            pairBtn.topAnchor.constraint(equalTo: noDeviceLabel.bottomAnchor, constant: 10),
            pairBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    @objc private func goToPairDevice() {
        // Pop back to home, then push Pair Device
        navigationController?.pop()
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
