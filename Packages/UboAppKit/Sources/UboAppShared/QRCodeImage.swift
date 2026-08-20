import SwiftUI
import QRCode

/// Shared across every app target (iOS, watchOS) so the phone and watch
/// apps render an identical, actually-scannable QR bitmap instead of each
/// maintaining its own copy. Uses the QRCode package rather than raw
/// CoreImage because CoreImage's CIFilter QR generator isn't part of the
/// watchOS SDK — QRCode already handles that by falling back to a
/// pure-Swift generator on watchOS.
public enum QRCodeImage {
    public static func generate(from string: String) -> Image? {
        guard !string.isEmpty else { return nil }
        guard let doc = try? QRCode.Document(utf8String: string) else { return nil }
        doc.errorCorrection = .medium
        guard let cgImage = try? doc.cgImage(dimension: 400) else { return nil }
        return Image(decorative: cgImage, scale: 1)
    }
}
