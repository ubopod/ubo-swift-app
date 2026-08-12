//
//  WeatherIcon.swift
//  ubo-swift-app
//
//  Maps MET Norway weather symbol codes (as streamed in
//  `LocalizationState.weather.symbol_code`, e.g. "partlycloudy_day") to SF
//  Symbols and a human-readable phrase. The Web UI hand-draws these as SVG
//  (`WeatherIcon.tsx`); SF Symbols already cover this vocabulary natively,
//  so we map instead of porting the SVG path data.
//

import SwiftUI

enum WeatherIcon {
    /// Display phrases for the MET Norway symbol codes, keyed by the code
    /// with its day/night suffix stripped. Mirrors `SYMBOL_PHRASES` in
    /// `ubo_app/services/010-localization/weather.py` and the Web UI's
    /// `WeatherCard.tsx` `PHRASES` table.
    private static let phrases: [String: String] = [
        "clearsky": "Clear",
        "fair": "Fair",
        "partlycloudy": "Partly cloudy",
        "cloudy": "Cloudy",
        "fog": "Fog",
        "rain": "Rain",
        "lightrain": "Light rain",
        "heavyrain": "Heavy rain",
        "rainshowers": "Showers",
        "lightrainshowers": "Light showers",
        "heavyrainshowers": "Heavy showers",
        "drizzle": "Drizzle",
        "sleet": "Sleet",
        "lightsleet": "Light sleet",
        "heavysleet": "Heavy sleet",
        "sleetshowers": "Sleet showers",
        "lightsleetshowers": "Light sleet showers",
        "heavysleetshowers": "Heavy sleet showers",
        "snow": "Snow",
        "lightsnow": "Light snow",
        "heavysnow": "Heavy snow",
        "snowshowers": "Snow showers",
        "lightsnowshowers": "Light snow showers",
        "heavysnowshowers": "Heavy snow showers",
        "rainandthunder": "Rain and thunder",
        "rainshowersandthunder": "Showers and thunder",
        "thunderstorm": "Thunderstorm",
        "heavyrainandthunder": "Heavy rain and thunder",
        "snowandthunder": "Snow and thunder",
        "sleetandthunder": "Sleet and thunder",
    ]

    private static func base(_ symbolCode: String) -> (base: String, isNight: Bool) {
        for suffix in ["_day", "_night", "_polartwilight"] {
            if symbolCode.hasSuffix(suffix) {
                return (String(symbolCode.dropLast(suffix.count)), suffix == "_night")
            }
        }
        return (symbolCode, false)
    }

    /// Human-readable description, e.g. "Partly cloudy". Unknown codes still
    /// read as something instead of a raw token.
    static func phrase(for symbolCode: String) -> String {
        let (key, _) = base(symbolCode)
        if let phrase = phrases[key] { return phrase }
        let spaced = key.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    /// SF Symbol name for the given symbol code.
    static func symbolName(for symbolCode: String) -> String {
        let (key, isNight) = base(symbolCode)
        switch key {
        case "clearsky": return isNight ? "moon.stars.fill" : "sun.max.fill"
        case "fair": return isNight ? "moon.fill" : "sun.min.fill"
        case "partlycloudy": return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case "cloudy": return "cloud.fill"
        case "fog": return "cloud.fog.fill"
        case "rain", "lightrain", "heavyrain", "drizzle":
            return "cloud.rain.fill"
        case "rainshowers", "lightrainshowers", "heavyrainshowers":
            return isNight ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill"
        case "sleet", "lightsleet", "heavysleet", "sleetshowers", "lightsleetshowers", "heavysleetshowers":
            return "cloud.sleet.fill"
        case "snow", "lightsnow", "heavysnow":
            return "cloud.snow.fill"
        case "snowshowers", "lightsnowshowers", "heavysnowshowers":
            return "cloud.snow.fill"
        case "rainandthunder", "rainshowersandthunder", "thunderstorm", "heavyrainandthunder":
            return "cloud.bolt.rain.fill"
        case "snowandthunder", "sleetandthunder":
            return "cloud.bolt.fill"
        default:
            return "questionmark.circle"
        }
    }
}
