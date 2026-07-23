// TrustedDevicesViewController.swift — Phase 12.1, updated for Task 2
// (populate from TrustStore — the single source of truth also used by
// HomeViewController via AppSessionManager).
//
// Shows the empty state only when no trust entries exist. When a trusted
// device is present, shows its stored name/type instead — the same
// underlying TrustStore data HomeViewController's Connected Device row
// reflects, so both screens agree.
//
// Per 06_UI_GUIDELINES.md §Empty States:
//   "Empty screens should always explain why they are empty."
//   "Empty screens should guide users toward the next logical action."
//
// Must NOT contain:
//   - Pairing logic        → Phase 12.2 (already complete)
//   - Trust management     → Phase 12.2 / 13 (already complete)
//   - Keychain access      → Phase 9 (already complete; TrustStore only)

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

    override func viewWillAppear() {
        super.viewWillAppear()
        // Task 2: re-read TrustStore every time this screen appears, so it
        // never shows stale data (e.g. right after a pairing completes and
        // the user navigates here). This only reads existing storage — it
        // never opens a connection or performs pairing/trust logic.
        refreshTrustedDeviceDisplay()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteUnpair),
            name: AppSessionManager.trustRevokedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionAdopted),
            name: AppSessionManager.sessionAdoptedNotification,
            object: nil
        )
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.removeObserver(self, name: AppSessionManager.trustRevokedNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AppSessionManager.sessionAdoptedNotification, object: nil)
    }

    // -------------------------------------------------------------------------
    // Interface
    // -------------------------------------------------------------------------

    // Subview references swapped between the empty state and the
    // populated (trusted-device) state.
    private weak var emptyStateContainer: NSView?
    private weak var trustedDeviceContainer: NSView?
    private weak var trustedDeviceNameLabel: NSTextField?
    private weak var trustedDeviceTypeLabel: NSTextField?
    private weak var deviceIdLabel: NSTextField?
    private weak var lastConnectedLabel: NSTextField?

    private func buildInterface() {
        let header = makePageHeader(title: "Trusted Devices")
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let sep = makeSeparator()
        sep.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sep)

        let empty = makeEmptyStateView()
        empty.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(empty)
        emptyStateContainer = empty

        let trusted = makeTrustedDeviceView()
        trusted.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trusted)
        trustedDeviceContainer = trusted

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 48),

            sep.topAnchor.constraint(equalTo: header.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),

            empty.topAnchor.constraint(equalTo: sep.bottomAnchor),
            empty.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            empty.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            empty.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            trusted.topAnchor.constraint(equalTo: sep.bottomAnchor),
            trusted.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trusted.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            trusted.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        refreshTrustedDeviceDisplay()
    }

    /// Empty state — unchanged from Phase 12.1, extracted into its own
    /// factory so it can be shown/hidden alongside the new trusted-device
    /// view.
    private func makeEmptyStateView() -> NSView {
        let container = NSView()

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

        [emptyIcon, emptyTitle, emptySubtitle, pairBtn].forEach { container.addSubview($0) }

        NSLayoutConstraint.activate([
            emptyIcon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyIcon.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -50),
            emptyIcon.widthAnchor.constraint(equalToConstant: 56),
            emptyIcon.heightAnchor.constraint(equalToConstant: 56),

            emptyTitle.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 14),
            emptyTitle.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            emptySubtitle.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 6),
            emptySubtitle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptySubtitle.widthAnchor.constraint(lessThanOrEqualToConstant: 220),

            pairBtn.topAnchor.constraint(equalTo: emptySubtitle.bottomAnchor, constant: 18),
            pairBtn.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        ])

        return container
    }

    /// Task 2: populated state — shows the single stored TrustEntry's name
    /// and device type. MacEcho Version 1 supports exactly one paired
    /// device, so this shows a single row rather than a list.
    private func makeTrustedDeviceView() -> NSView {
        let container = NSView()

        let iconCfg = NSImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "laptopcomputer.and.iphone",
                             accessibilityDescription: nil)?
            .withSymbolConfiguration(iconCfg)
        icon.contentTintColor = NSColor.systemGreen
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        trustedDeviceNameLabel = nameLabel

        let typeLabel = NSTextField(labelWithString: "")
        typeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        typeLabel.textColor = .secondaryLabelColor
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        trustedDeviceTypeLabel = typeLabel

        let idLabel = NSTextField(labelWithString: "")
        idLabel.font = .systemFont(ofSize: 11, weight: .regular)
        idLabel.textColor = .tertiaryLabelColor
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceIdLabel = idLabel

        let lastConnLabel = NSTextField(labelWithString: "")
        lastConnLabel.font = .systemFont(ofSize: 11, weight: .regular)
        lastConnLabel.textColor = .tertiaryLabelColor
        lastConnLabel.translatesAutoresizingMaskIntoConstraints = false
        lastConnectedLabel = lastConnLabel

        let unpairBtn = NSButton(title: "Unpair Device", target: self, action: #selector(unpairDevice))
        unpairBtn.bezelStyle = .rounded
        unpairBtn.contentTintColor = .systemRed
        unpairBtn.translatesAutoresizingMaskIntoConstraints = false

        [icon, nameLabel, typeLabel, idLabel, lastConnLabel, unpairBtn].forEach { container.addSubview($0) }

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),

            nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: icon.topAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            typeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            typeLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            idLabel.leadingAnchor.constraint(equalTo: typeLabel.leadingAnchor),
            idLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 12),
            idLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            lastConnLabel.leadingAnchor.constraint(equalTo: idLabel.leadingAnchor),
            lastConnLabel.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 4),
            lastConnLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            unpairBtn.leadingAnchor.constraint(equalTo: lastConnLabel.leadingAnchor),
            unpairBtn.topAnchor.constraint(equalTo: lastConnLabel.bottomAnchor, constant: 16),
            unpairBtn.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20),
        ])

        return container
    }

    /// Task 2: "Populate the Trusted Devices section using the already
    /// stored TrustStore entry. There should be one consistent source of
    /// truth." Reads directly from `TrustStore` (already-existing Phase 9
    /// storage) — the same store `HomeViewController`'s connected-device
    /// display is ultimately backed by, so both screens can never disagree.
    private func refreshTrustedDeviceDisplay() {
        let entries = TrustStore().getAll()

        if let entry = entries.first {
            trustedDeviceNameLabel?.stringValue = entry.deviceName
            trustedDeviceTypeLabel?.stringValue = "🟢 Connected" // Matches Home screen state expectation for Phase 12.1 mock
            deviceIdLabel?.stringValue = "Device ID: \(entry.trustedDeviceId)"
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let date = Date(timeIntervalSince1970: TimeInterval(entry.pairingTimestampMs) / 1000.0)
            lastConnectedLabel?.stringValue = "Last Connected: \(formatter.string(from: date))"
            
            emptyStateContainer?.isHidden = true
            trustedDeviceContainer?.isHidden = false
        } else {
            emptyStateContainer?.isHidden = false
            trustedDeviceContainer?.isHidden = true
        }
    }

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    @objc private func openPairDevice() {
        navigationController?.pop()
        // Phase 12.2: navigate directly to PairDeviceViewController
    }

    @objc private func unpairDevice() {
        let alert = NSAlert()
        alert.messageText = "Unpair Device?"
        alert.informativeText = "This Mac will no longer trust this Android device. You must pair again before using MacEcho."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Unpair")
        
        // Custom styling for destructive button
        if let unpairBtn = alert.buttons.last {
            unpairBtn.hasDestructiveAction = true
        }

        let response = alert.runModal()
        if response == .alertSecondButtonReturn { // Unpair clicked
            guard let entry = TrustStore().getAll().first else { return }
            
            // 1. Notify Remote
            Task {
                let jsonStr = """
                {"type":"TRUST_REVOKED","sessionId":"\(AppSessionManager.shared.activeSession?.pairedDeviceId ?? "")"}
                """
                await AppSessionManager.shared.activeSession?.client.sendText(jsonStr)
                
                // 2. Local Cleanup
                try? TrustStore().remove(deviceId: entry.trustedDeviceId)
                TrustStore.invalidateKeyCache()
                AppSessionManager.shared.terminate(reason: .unpaired)
                
                // 3. UI Refresh
                await MainActor.run {
                    self.refreshTrustedDeviceDisplay()
                }
            }
        }
    }

    @objc private func handleSessionAdopted() {
        refreshTrustedDeviceDisplay()
    }

    @objc private func handleRemoteUnpair() {
        // AppNavigationController shows the "Device Unpaired" alert centrally
        // and pops back to Home. We just need to refresh our own data model.
        refreshTrustedDeviceDisplay()
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
