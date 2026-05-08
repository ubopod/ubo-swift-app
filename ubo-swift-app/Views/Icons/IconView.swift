//
//  IconView.swift
//  ubo-swift-app
//
//  Renders icon strings used across the Ubo client surface area. The
//  GUI client and Web UI both feed icons as Nerd Font codepoints from
//  the Unicode Private Use Area (e.g. `\u{F0DA1}` is wifi). When the
//  payload is one of those glyphs we render the bundled
//  `ArimoNerdFont` directly; otherwise the icon is a semantic key
//  (e.g. `"wifi"`, `"settings"`, `"main"`) chosen by Apple-side code,
//  in which case we fall back to an SF Symbol via `SymbolMapper`.
//

import SwiftUI

/// Name the bundled Nerd Font is registered as via
/// `INFOPLIST_KEY_UIAppFonts`. The string must match either the
/// PostScript name (`ArimoNF-Regular`) or the family name embedded
/// in the TTF — *not* the filename. Defined once here so future
/// font swaps only need to update one place.
public enum UboIconFont {
    public static let family = "Arimo Nerd Font"
}

public struct IconView: View {
    public let icon: String
    public let size: CGFloat
    public let color: Color

    public init(icon: String, size: CGFloat = 16, color: Color = .primary) {
        self.icon = icon
        self.size = size
        self.color = color
    }

    public var body: some View {
        if isPrivateUseGlyph(icon) {
            Text(icon)
                .font(.custom(UboIconFont.family, size: size))
                .foregroundStyle(color)
        } else if !icon.isEmpty {
            Image(systemName: SymbolMapper.systemName(for: icon))
                .font(.system(size: size))
                .foregroundStyle(color)
        } else {
            EmptyView()
        }
    }

    /// Nerd Font glyphs occupy the Unicode Private Use Area. Single-
    /// character icon strings whose first scalar is in the BMP PUA
    /// (`U+E000..U+F8FF`) or one of the supplementary PUA planes are
    /// rendered with the bundled font.
    private func isPrivateUseGlyph(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first else { return false }
        let v = first.value
        return (0xE000...0xF8FF).contains(v)
            || (0xF0000...0xFFFFD).contains(v)
            || (0x100000...0x10FFFD).contains(v)
    }
}
