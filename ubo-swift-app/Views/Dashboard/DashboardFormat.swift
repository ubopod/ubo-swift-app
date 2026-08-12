//
//  DashboardFormat.swift
//  ubo-swift-app
//
//  Formatting/color helpers ported from the Web UI's `format.ts`/`colors.ts`
//  (ubo_app/services/090-web-ui/web-app/src/components/dashboard/).
//

import Foundation
import SwiftUI
import UboAppKit

enum DashboardFormat {
    private static let byteUnits = ["B", "KB", "MB", "GB", "TB"]

    /// Humanize a byte count, e.g. 1536 -> "1.5 KB".
    static func bytes(_ count: Int64) -> String {
        var value = Double(max(0, count))
        var unit = 0
        while value >= 1024, unit < byteUnits.count - 1 {
            value /= 1024
            unit += 1
        }
        // Sub-10 values keep a decimal so "1.5 GB" doesn't collapse to "2 GB".
        let digits = value < 10 && unit > 0 ? 1 : 0
        return String(format: "%.\(digits)f %@", value, byteUnits[unit])
    }

    /// Humanize a transfer rate in bytes/second.
    static func rate(_ bytesPerSecond: Float) -> String {
        "\(bytes(Int64(bytesPerSecond)))/s"
    }

    /// Render an uptime from the device's boot time (epoch seconds). Clamped
    /// to zero rather than rendering a negative span if the client clock is
    /// behind the device's.
    static func uptime(bootTime: Float) -> String {
        guard bootTime > 0 else { return "—" }
        let seconds = max(0, Date().timeIntervalSince1970 - Double(bootTime))
        let days = Int(seconds / 86400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    /// Format a sensor reading at the precision its registry entry asks for.
    static func reading(_ value: Float?, precision: Int64?) -> String {
        guard let value else { return "—" }
        if let precision {
            return String(format: "%.\(max(0, Int(precision)))f", value)
        }
        // No suggested precision: keep one decimal for small magnitudes, none
        // for counts like CO2 ppm or illuminance lux.
        return abs(value) < 100 ? String(format: "%.1f", value) : String(Int(value.rounded()))
    }
}

extension Array {
    /// Split into consecutive groups of at most `size` elements each. Used
    /// to lay out fixed-count rows (e.g. 4 compact sensor tiles per row)
    /// without pulling in a grid component that would reintroduce the
    /// dead-space bug a mismatched-height grid caused.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

/// Status palette — fixed, never themed, and deliberately distinct from any
/// series color so a status hue never impersonates a category. Mirrors the
/// Web UI's `colors.ts`.
enum DashboardColor {
    static let good = Color(hex: "#0ca30c") ?? .green
    static let warning = Color(hex: "#fab219") ?? .yellow
    static let serious = Color(hex: "#ec835a") ?? .orange
    static let critical = Color(hex: "#d03b3b") ?? .red

    /// The neutral accent for ratios that carry no severity meaning.
    static let neutralAccent = Color(hex: "#2a78d6") ?? .blue

    /// Sensor-gauge ring color — yellow reads with much higher contrast
    /// than `neutralAccent`'s blue against the dashboard's dark cards.
    static let gaugeAccent = Color(hex: "#ffc107") ?? .yellow

    /// An app that's installed but not running — deliberately outside the
    /// severity scale, a fixed hue so a stopped app reads the same in both
    /// themes.
    static let idle = Color(hex: "#8a8f98") ?? .gray

    /// Pick a meter fill for a load-style percentage, where more is worse.
    /// Applies to CPU, RAM and disk — sensor readings don't use this, since
    /// e.g. high humidity is not a fault.
    static func loadSeverity(_ percent: Float) -> Color {
        if percent >= 90 { return critical }
        if percent >= 80 { return serious }
        if percent >= 60 { return warning }
        return good
    }
}
