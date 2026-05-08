//
//  MenuItemRow.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

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

    private func mapIcon(_ icon: String) -> String {
        // Map common Ubo icons to SF Symbols
        switch icon.lowercased() {
        case "settings", "gear", "cog": return "gear"
        case "wifi": return "wifi"
        case "bluetooth": return "bluetooth"
        case "apps", "applications": return "square.grid.2x2"
        case "power", "shutdown": return "power"
        case "reboot", "restart": return "arrow.triangle.2.circlepath"
        case "info", "about": return "info.circle"
        case "update", "download": return "arrow.down.circle"
        case "back": return "chevron.left"
        case "home": return "house"
        case "checkmark", "check", "done": return "checkmark.circle.fill"
        case "cancel", "close", "x": return "xmark.circle"
        case "add", "plus": return "plus.circle"
        case "remove", "minus", "delete": return "minus.circle"
        case "edit", "pencil": return "pencil"
        case "camera": return "camera"
        case "microphone", "mic": return "mic"
        case "speaker", "volume": return "speaker.wave.2"
        case "mute": return "speaker.slash"
        case "play": return "play.fill"
        case "pause": return "pause.fill"
        case "stop": return "stop.fill"
        case "network", "ethernet": return "network"
        case "vpn", "security": return "lock.shield"
        case "ssh", "terminal": return "terminal"
        case "docker", "container": return "shippingbox"
        case "folder", "directory": return "folder"
        case "file", "document": return "doc"
        case "user", "account": return "person"
        case "users", "accounts": return "person.2"
        case "notification", "bell": return "bell"
        case "led", "light", "rgb": return "lightbulb"
        case "display", "screen": return "display"
        case "assistant", "ai": return "waveform"
        case "sensors": return "sensor"
        case "temperature", "thermometer": return "thermometer"
        case "clock", "time": return "clock"
        case "date", "calendar": return "calendar"
        case "battery": return "battery.100"
        case "storage", "disk": return "internaldrive"
        case "memory", "ram": return "memorychip"
        case "cpu", "processor": return "cpu"
        default:
            // Only use if it looks like a valid SF Symbol (contains a dot like "circle.fill")
            if icon.contains(".") && icon.allSatisfy({ $0.isASCII }) {
                return icon
            }
            return "circle.fill"
        }
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
