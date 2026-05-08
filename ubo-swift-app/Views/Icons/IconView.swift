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

/// Resolve a `MenuItemData.color`-style hex string to a SwiftUI
/// `Color`, treating the GUI client's default white as "use the
/// system primary color so it stays visible in both light and dark
/// modes". Empty / unparseable strings also fall through to
/// `.primary`.
public func uboIconColor(forHex hex: String, fallback: Color = .primary) -> Color {
    let normalised = hex.lowercased()
    if normalised.isEmpty || normalised == "#ffffff" || normalised == "#fff" {
        return fallback
    }
    return Color(hex: hex) ?? fallback
}

/// True when `s` starts with a Unicode Private-Use codepoint, i.e.
/// when it should be rendered by the bundled Nerd Font instead of
/// looked up as an SF Symbol.
public func isUboNerdGlyph(_ s: String) -> Bool {
    guard let first = s.unicodeScalars.first else { return false }
    let v = first.value
    return (0xE000...0xF8FF).contains(v)
        || (0xF0000...0xFFFFD).contains(v)
        || (0x100000...0x10FFFD).contains(v)
}

/// Split a label that may begin with a Nerd Font glyph (as the GUI
/// client does for titles like `\u{F035C}Main`) into the leading
/// icon and the remaining label. Returns `(nil, original)` when
/// there's no leading glyph.
public func splitLeadingGlyph(_ s: String) -> (icon: String?, label: String) {
    guard let first = s.unicodeScalars.first, isUboNerdGlyph(String(first)) else {
        return (nil, s)
    }
    let glyph = String(first)
    let remainder = String(s.unicodeScalars.dropFirst())
    return (glyph, remainder)
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
        if isUboNerdGlyph(icon) {
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
}
