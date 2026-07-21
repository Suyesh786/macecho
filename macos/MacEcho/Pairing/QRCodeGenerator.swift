// QRCodeGenerator.swift — Phase 12.1
//
// Stateless utility that produces a crisp, pixel-perfect QR code NSImage
// from any string payload, using CoreImage exclusively.
// Zero external dependencies.
//
// Must NOT contain:
//   - Pairing logic       → Phase 12.2
//   - Network calls       → Phase 12.2
//   - Trust operations    → Phase 12.2

import AppKit
import CoreImage

/// Converts a string payload into a crisp QR code NSImage using CoreImage.
/// `CIQRCodeGenerator` is available on macOS 10.10+ and requires no
/// external libraries.
enum QRCodeGenerator {

    // Reuse CIContext across calls — creation is expensive.
    // CIContext is Sendable (confirmed by Swift 6 type checker); no actor annotation needed.
    private static let ciContext = CIContext(
        options: [.useSoftwareRenderer: false]
    )

    /// Generates a square QR code image at the requested point size.
    ///
    /// - Parameters:
    ///   - string:          Content to encode (JSON string from PairingSessionToken).
    ///   - size:            Desired square size in points. Rendered at 2× for Retina.
    ///   - correctionLevel: QR error correction level ("L", "M", "Q", "H").
    ///                      "M" (15 % recovery) is appropriate for screen display.
    /// - Returns: A black-on-white NSImage, or nil if generation fails.
    static func generate(
        from string: String,
        size: CGFloat,
        correctionLevel: String = "M"
    ) -> NSImage? {
        guard
            let data = string.data(using: .utf8),
            let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel, forKey: "inputCorrectionLevel")

        guard let raw = filter.outputImage else { return nil }

        // The raw filter output is tiny (~33×33 px for typical payloads).
        // Scale up using nearest-neighbour to keep module edges perfectly sharp.
        // Render at 2× physical pixels to look crisp on Retina displays.
        let retinaSize = size * 2.0
        let scaleX = retinaSize / raw.extent.width
        let scaleY = retinaSize / raw.extent.height
        let scaled = raw.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }

        let result = NSImage(size: NSSize(width: size, height: size))
        result.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return result
    }
}
