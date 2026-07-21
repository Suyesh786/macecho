// ActionCardView.swift — Phase 12.1
//
// Reusable interactive card row used in HomeViewController.
// Features:
//   • Rounded icon badge with coloured background + SF Symbol
//   • Title (semibold) + description (secondary, max 2 lines)
//   • Optional trailing chevron
//   • Hover highlight (5 % label tint over full card width)
//   • Press alpha-dim animation (0.65 → 1.0)
//   • Pointing-hand cursor
//   • Action closure called on mouse-up inside bounds
//
// BottomRowView (defined at the bottom of this file) is a simplified variant
// for the "About MacEcho" / "Quit MacEcho" rows — no description, no chevron,
// smaller badge (32 × 32 pt, corner radius 8).

import AppKit

// MARK: - Shared badge factory

/// Creates a rounded-rectangle icon badge.
/// Declared at file scope so both ActionCardView and BottomRowView can use it.
@MainActor
private func makeIconBadge(
    symbol: String,
    badgeColor: NSColor,
    iconColor: NSColor,
    badgeSize: CGFloat,
    cornerRadius: CGFloat,
    symbolPointSize: CGFloat
) -> NSView {
    let badge = NSView()
    badge.wantsLayer = true
    badge.layer?.backgroundColor = badgeColor.cgColor
    badge.layer?.cornerRadius = cornerRadius
    badge.translatesAutoresizingMaskIntoConstraints = false

    let cfg = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .medium)
    let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg)

    let iconView = NSImageView()
    iconView.image = img
    iconView.contentTintColor = iconColor
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconView.translatesAutoresizingMaskIntoConstraints = false
    badge.addSubview(iconView)

    NSLayoutConstraint.activate([
        iconView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
        iconView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        iconView.widthAnchor.constraint(equalToConstant: symbolPointSize + 2),
        iconView.heightAnchor.constraint(equalToConstant: symbolPointSize + 2),
    ])
    return badge
}

// MARK: - ActionCardView

/// Full-width interactive card row with icon badge, title, description and chevron.
@MainActor
final class ActionCardView: NSView {

    // -------------------------------------------------------------------------
    // Public
    // -------------------------------------------------------------------------

    /// Called on the main actor when the user clicks the card.
    var action: (() -> Void)?

    // -------------------------------------------------------------------------
    // Private
    // -------------------------------------------------------------------------

    private var trackingArea: NSTrackingArea?

    // -------------------------------------------------------------------------
    // Init
    // -------------------------------------------------------------------------

    init(
        symbol: String,
        badgeColor: NSColor,
        iconColor: NSColor,
        title: String,
        description: String,
        showChevron: Bool = true
    ) {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        build(symbol: symbol, badgeColor: badgeColor, iconColor: iconColor,
              title: title, description: description, showChevron: showChevron)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // -------------------------------------------------------------------------
    // Layout
    // -------------------------------------------------------------------------

    private func build(
        symbol: String,
        badgeColor: NSColor,
        iconColor: NSColor,
        title: String,
        description: String,
        showChevron: Bool
    ) {
        // ── Badge ─────────────────────────────────────────────────────────────
        let badge = makeIconBadge(
            symbol: symbol, badgeColor: badgeColor, iconColor: iconColor,
            badgeSize: 44, cornerRadius: 10, symbolPointSize: 20
        )

        // ── Title ─────────────────────────────────────────────────────────────
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // ── Description ───────────────────────────────────────────────────────
        let descLabel = NSTextField(wrappingLabelWithString: description)
        descLabel.font = .systemFont(ofSize: 12, weight: .regular)
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 2
        // Hint so Auto Layout can calculate wrapped height without a pass.
        // 320 total − 16 left − 44 badge − 12 gap − 14 chevron − 16 right = 218 pt
        descLabel.preferredMaxLayoutWidth = 210
        descLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // ── Text vertical stack ───────────────────────────────────────────────
        let textStack = NSStackView(views: [titleLabel, descLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // ── Horizontal row ────────────────────────────────────────────────────
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.addArrangedSubview(badge)
        hStack.addArrangedSubview(textStack)

        if showChevron {
            let chevCfg = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            let chevImg = NSImage(systemSymbolName: "chevron.right",
                                  accessibilityDescription: nil)?
                .withSymbolConfiguration(chevCfg)
            let chevView = NSImageView()
            chevView.image = chevImg
            chevView.contentTintColor = .tertiaryLabelColor
            chevView.translatesAutoresizingMaskIntoConstraints = false
            chevView.widthAnchor.constraint(equalToConstant: 13).isActive = true
            chevView.heightAnchor.constraint(equalToConstant: 13).isActive = true
            hStack.addArrangedSubview(chevView)
        }

        addSubview(hStack)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 44),
            badge.heightAnchor.constraint(equalToConstant: 44),

            hStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            hStack.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13),
        ])
    }

    // -------------------------------------------------------------------------
    // Cursor
    // -------------------------------------------------------------------------

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // -------------------------------------------------------------------------
    // Hover & press
    // -------------------------------------------------------------------------

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.07
        animator().alphaValue = 0.65
        NSAnimationContext.endGrouping()
    }

    override func mouseUp(with event: NSEvent) {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.13
        animator().alphaValue = 1.0
        NSAnimationContext.endGrouping()
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            action?()
        }
    }

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - BottomRowView

/// Simplified row for "About MacEcho" and "Quit MacEcho".
/// No description text. No chevron. Smaller badge (32 × 32, radius 8).
@MainActor
final class BottomRowView: NSView {

    var action: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    init(symbol: String, badgeColor: NSColor, iconColor: NSColor, title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        build(symbol: symbol, badgeColor: badgeColor, iconColor: iconColor, title: title)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(
        symbol: String, badgeColor: NSColor, iconColor: NSColor, title: String
    ) {
        let badge = makeIconBadge(
            symbol: symbol, badgeColor: badgeColor, iconColor: iconColor,
            badgeSize: 32, cornerRadius: 8, symbolPointSize: 15
        )

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let hStack = NSStackView(views: [badge, titleLabel])
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hStack)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 32),
            badge.heightAnchor.constraint(equalToConstant: 32),

            hStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            hStack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.07
        animator().alphaValue = 0.65
        NSAnimationContext.endGrouping()
    }

    override func mouseUp(with event: NSEvent) {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.13
        animator().alphaValue = 1.0
        NSAnimationContext.endGrouping()
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            action?()
        }
    }

    override var mouseDownCanMoveWindow: Bool { false }
}
