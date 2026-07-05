//
//  UboSymbolMapper.swift
//
//  Fallback mapping from core-supplied icon strings (Nerd Font PUA glyphs
//  or plain names) to SF Symbols, for contexts where the Nerd Font isn't
//  rendered (prompts, instructions, render views). The single source of
//  truth for every target — don't fork per-platform copies.
//

/// Map a core icon string to an SF Symbol name, defaulting to "circle".
public enum UboSymbolMapper {
    public static func systemName(for icon: String) -> String {
        switch icon.lowercased() {
        case "info", "󰋼": return "info.circle"
        case "warning", "alert", "󰀦": return "exclamationmark.triangle"
        case "error", "fail", "failure": return "xmark.circle"
        case "success", "ok", "check", "checkmark", "󰄬": return "checkmark.circle"
        case "wifi", "󰖩": return "wifi"
        case "bluetooth", "󰂯": return "bluetooth"
        case "ssh", "󰣀": return "terminal"
        case "vpn", "󰖂": return "lock.shield"
        case "docker", "󰡨": return "shippingbox"
        case "settings", "gear", "󰒓": return "gear"
        case "power", "󰐥": return "power"
        case "main": return "list.bullet"
        case "notifications", "󰂚": return "bell"
        case "apps", "󰀻": return "square.grid.2x2"
        case "update", "󰚰": return "arrow.down.circle"
        case "home", "󰋜": return "house"
        case "cancel", "close", "󰅖": return "xmark"
        case "back", "󰁍": return "chevron.left"
        case "forward", "󰁔": return "chevron.right"
        case "toggle_on", "󰔡": return "checkmark.circle.fill"
        case "toggle_off", "󰨙": return "circle"
        default: return "circle"
        }
    }
}
