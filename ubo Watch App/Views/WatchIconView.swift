//
//  WatchIconView.swift
//  ubo Watch App
//
//  watchOS counterpart of `IconView`. Same logic — render Nerd Font
//  glyphs (Unicode Private Use Area) via the bundled `ArimoNerdFont`
//  and fall back to SF Symbols for semantic keys.
//

import SwiftUI

public enum UboIconFont {
    public static let family = "ArimoNerdFont"
}

public struct IconView: View {
    public let icon: String
    public let size: CGFloat
    public let color: Color

    public init(icon: String, size: CGFloat = 12, color: Color = .primary) {
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
            Image(systemName: WatchSymbolMapper.systemName(for: icon))
                .font(.system(size: size))
                .foregroundStyle(color)
        } else {
            EmptyView()
        }
    }

    private func isPrivateUseGlyph(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first else { return false }
        let v = first.value
        return (0xE000...0xF8FF).contains(v)
            || (0xF0000...0xFFFFD).contains(v)
            || (0x100000...0x10FFFD).contains(v)
    }
}
