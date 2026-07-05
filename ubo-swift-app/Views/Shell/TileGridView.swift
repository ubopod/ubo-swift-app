//
//  TileGridView.swift
//  ubo-swift-app
//
//  The Web-UI-style tile grid for menu/home views, rendered as a pure function
//  of `focused`: each MenuItemData is a colored card, highlighted when it is
//  the shell's focused element. All key/remote handling lives in
//  `TileShellView`; a tile's only job is to draw itself and call `onSelect`
//  when clicked (mouse / Siri-Remote select).
//
//  Like the Web UI, the whole menu is shown at once (the core sends the full
//  item list for a menu; its `total_pages` only describes the device's 3-slot
//  screen), so there is no pager — the grid simply scrolls.
//

#if os(tvOS) || os(macOS)
import UboAppKit
import SwiftUI
import UboSwift

struct TileGridView: View {
    let items: [MenuItemData]
    var heading: String?
    var subHeading: String?
    let focused: ShellFocus?
    let onSelect: (MenuItemData) -> Void

    private var columnCount: Int {
        switch items.count {
        case 0, 1: return 1
        case 2, 3, 4: return 2
        default: return 3
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 24), count: columnCount)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let heading, !heading.isEmpty {
                        markupText(heading)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    if let subHeading, !subHeading.isEmpty {
                        markupText(subHeading)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }

                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(items, id: \.key) { item in
                            TileView(item: item, isFocused: focused == .tile(item.key)) {
                                onSelect(item)
                            }
                            .id(item.key)
                        }
                    }
                }
                .padding(24)
            }
            .onChange(of: focused) { _, value in
                if case .tile(let key)? = value {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(key, anchor: .center)
                    }
                }
            }
        }
    }
}

/// A single menu tile: icon + label on a colored card, highlighted when focused.
private struct TileView: View {
    let item: MenuItemData
    let isFocused: Bool
    let action: () -> Void

    private var displayLabel: String {
        item.label.isEmpty
            ? item.key.prefix(1).uppercased() + item.key.dropFirst()
            : item.label
    }

    private var displayIcon: String {
        item.icon.isEmpty ? item.key : item.icon
    }

    private var background: Color {
        guard let hex = item.backgroundColor, !hex.isEmpty else { return .accentColor }
        let lower = hex.lowercased()
        if lower == "#ffffff" || lower == "#fff" { return .accentColor }
        return Color(hex: hex) ?? .accentColor
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                IconView(icon: displayIcon, size: 44, color: .white)
                markupText(displayLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 18).fill(background))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.white, lineWidth: isFocused ? 4 : 0)
            )
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .shadow(color: .black.opacity(isFocused ? 0.4 : 0.15),
                    radius: isFocused ? 14 : 3, y: isFocused ? 8 : 2)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        // The shell container owns focus and renders the highlight manually;
        // keep the native focus engine (tvOS) from also grabbing these tiles.
        .focusable(false)
    }
}
#endif
