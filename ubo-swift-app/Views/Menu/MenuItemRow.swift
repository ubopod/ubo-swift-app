//
//  MenuItemRow.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import UboAppKit
import SwiftUI
import UboSwift

struct MenuItemRow: View {
    let item: MenuItemData
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon — Nerd Font glyph if private-use codepoint, SF Symbol otherwise.
                IconView(icon: item.icon, size: 20, color: iconColor)
                    .frame(width: 32, height: 32)
                    .background {
                        if let bgColor = item.backgroundColor.flatMap({ Color(hex: $0) }) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(bgColor.opacity(0.2))
                        }
                    }

                // Label
                markupText(item.label)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        // Items default to white on the GUI client (dark display);
        // route through `uboIconColor` so they stay visible in iOS
        // light mode too.
        uboIconColor(forHex: item.color, fallback: .accentColor)
    }

}

#Preview {
    List {
        MenuItemRow(
            item: MenuItemData(
                key: "settings",
                label: "Settings",
                icon: "gear",
                color: "#007AFF",
                backgroundColor: nil,
                isShort: false,
                actionId: nil
            )
        ) {
            print("Tapped settings")
        }

        MenuItemRow(
            item: MenuItemData(
                key: "wifi",
                label: "Wi-Fi",
                icon: "wifi",
                color: "#34C759",
                backgroundColor: "#34C759",
                isShort: false,
                actionId: nil
            )
        ) {
            print("Tapped wifi")
        }
    }
}
