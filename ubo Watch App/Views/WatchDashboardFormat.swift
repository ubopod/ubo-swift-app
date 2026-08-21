//
//  WatchDashboardFormat.swift
//  ubo Watch App
//
//  Compact formatting/icon helpers for the watch Dashboard pages. A
//  watch-local counterpart to the iOS app's `DashboardFormat.swift`/
//  `WeatherIcon.swift`/`SensorDisplay.swift` — separate per-target files
//  (like `CompactGauge` vs. `GaugeCard`) rather than a shared package,
//  matching this codebase's existing iOS/watchOS split.
//

import Foundation
import SwiftUI

enum WatchFormat {
    private static let byteUnits = ["B", "KB", "MB", "GB", "TB"]

    static func bytes(_ count: Int64) -> String {
        var value = Double(max(0, count))
        var unit = 0
        while value >= 1024, unit < byteUnits.count - 1 {
            value /= 1024
            unit += 1
        }
        let digits = value < 10 && unit > 0 ? 1 : 0
        return String(format: "%.\(digits)f %@", value, byteUnits[unit])
    }

    /// Compact uptime, e.g. "3d 4h" / "4h 12m" / "12m" — no seconds, watch
    /// glances don't need that precision.
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

    static func loadSeverity(_ percent: Float) -> Color {
        if percent >= 90 { return .red }
        if percent >= 80 { return .orange }
        if percent >= 60 { return .yellow }
        return .green
    }
}

enum WatchWeatherIcon {
    private static func base(_ symbolCode: String) -> (base: String, isNight: Bool) {
        for suffix in ["_day", "_night", "_polartwilight"] {
            if symbolCode.hasSuffix(suffix) {
                return (String(symbolCode.dropLast(suffix.count)), suffix == "_night")
            }
        }
        return (symbolCode, false)
    }

    /// Short display phrase — condensed subset of the iOS app's phrase
    /// table, enough to read at a glance on a watch face.
    static func phrase(for symbolCode: String) -> String {
        let (key, _) = base(symbolCode)
        let phrases: [String: String] = [
            "clearsky": "Clear", "fair": "Fair", "partlycloudy": "Partly cloudy",
            "cloudy": "Cloudy", "fog": "Fog", "rain": "Rain", "lightrain": "Light rain",
            "heavyrain": "Heavy rain", "rainshowers": "Showers", "drizzle": "Drizzle",
            "sleet": "Sleet", "snow": "Snow", "lightsnow": "Light snow",
            "heavysnow": "Heavy snow", "snowshowers": "Snow showers",
            "rainandthunder": "Thunder", "thunderstorm": "Thunderstorm",
        ]
        if let phrase = phrases[key] { return phrase }
        let spaced = key.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    static func symbolName(for symbolCode: String) -> String {
        let (key, isNight) = base(symbolCode)
        switch key {
        case "clearsky": return isNight ? "moon.stars.fill" : "sun.max.fill"
        case "fair": return isNight ? "moon.fill" : "sun.min.fill"
        case "partlycloudy": return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case "cloudy": return "cloud.fill"
        case "fog": return "cloud.fog.fill"
        case "rain", "lightrain", "heavyrain", "drizzle": return "cloud.rain.fill"
        case "rainshowers": return isNight ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill"
        case "sleet": return "cloud.sleet.fill"
        case "snow", "lightsnow", "heavysnow", "snowshowers": return "cloud.snow.fill"
        case "rainandthunder", "thunderstorm": return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }
}

struct WatchSensorSpec {
    let icon: String
    let range: ClosedRange<Float>?
}

enum WatchSensorDisplay {
    private static let byDeviceClass: [String: WatchSensorSpec] = [
        "temperature": WatchSensorSpec(icon: "thermometer", range: -10...50),
        "humidity": WatchSensorSpec(icon: "humidity.fill", range: 0...100),
        "pressure": WatchSensorSpec(icon: "gauge.with.dots.needle.33percent", range: 950...1050),
        "illuminance": WatchSensorSpec(icon: "sun.max.fill", range: 0...1000),
        "carbon_dioxide": WatchSensorSpec(icon: "aqi.medium", range: 400...2000),
        "aqi": WatchSensorSpec(icon: "aqi.high", range: 1...5),
        // ENS160's TVOC entity — 0-2200 ppb covers "excellent" through
        // "poor" on ENS160's own IAQ scale; everyday indoor readings stay
        // well under this, unhealthy/severe territory starts above it.
        "volatile_organic_compounds_parts": WatchSensorSpec(icon: "aqi.medium", range: 0...2200),
        // PMSA003I's particulate-matter readings (registry.default.json) —
        // typical indoor/ambient µg/m³ scale, coarse enough to fill the
        // gauge meaningfully without needing a precise AQI breakpoint
        // table for a small watch ring.
        "pm1": WatchSensorSpec(icon: "aqi.medium", range: 0...100),
        "pm25": WatchSensorSpec(icon: "aqi.medium", range: 0...100),
        "pm10": WatchSensorSpec(icon: "aqi.medium", range: 0...150),
    ]
    private static let fallback = WatchSensorSpec(icon: "gauge", range: nil)

    static func spec(forKey key: String, deviceClass: String?) -> WatchSensorSpec {
        if let deviceClass, let spec = byDeviceClass[deviceClass] {
            return spec
        }
        return fallback
    }

    static func rangeFraction(_ value: Float, range: ClosedRange<Float>) -> Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return Double((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    static func reading(_ value: Float?, precision: Int64?) -> String {
        guard let value else { return "—" }
        if let precision { return String(format: "%.\(max(0, Int(precision)))f", value) }
        return abs(value) < 100 ? String(format: "%.1f", value) : String(Int(value.rounded()))
    }
}
