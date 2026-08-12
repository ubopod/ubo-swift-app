//
//  SensorDisplay.swift
//  ubo-swift-app
//
//  How to render a sensor reading, keyed by the Home Assistant
//  `device_class` the sensor registry assigns it. Mirrors the Web UI's
//  `sensor-display.ts`. A range is deliberately absent for anything with
//  no natural bounds (a VOC index, a gas resistance in ohms, a
//  time-of-flight distance) — those render as plain stats, since a meter
//  implies a limit and inventing one would be a lie.
//

import Foundation

struct SensorDisplaySpec {
    /// SF Symbol name.
    let icon: String
    /// Meter bounds. `nil` where no meaningful range exists.
    let range: ClosedRange<Float>?
}

enum SensorDisplay {
    private static let byDeviceClass: [String: SensorDisplaySpec] = [
        "temperature": SensorDisplaySpec(icon: "thermometer", range: -10...50),
        "humidity": SensorDisplaySpec(icon: "humidity.fill", range: 0...100),
        "pressure": SensorDisplaySpec(icon: "gauge.with.dots.needle.33percent", range: 950...1050),
        "illuminance": SensorDisplaySpec(icon: "sun.max.fill", range: 0...1000),
        "carbon_dioxide": SensorDisplaySpec(icon: "aqi.medium", range: 400...2000),
        "volatile_organic_compounds_parts": SensorDisplaySpec(icon: "aqi.low", range: 0...1000),
        "aqi": SensorDisplaySpec(icon: "aqi.high", range: 1...5),
        "pm1": SensorDisplaySpec(icon: "smoke.fill", range: 0...100),
        "pm25": SensorDisplaySpec(icon: "smoke.fill", range: 0...100),
        "pm10": SensorDisplaySpec(icon: "smoke.fill", range: 0...100),
        "distance": SensorDisplaySpec(icon: "ruler.fill", range: nil),
    ]

    /// Fallbacks for entities the registry gives no device_class, matched on
    /// the entity key instead.
    private static let byKey: [String: SensorDisplaySpec] = [
        "gas_resistance": SensorDisplaySpec(icon: "aqi.low", range: nil),
        "voc_index": SensorDisplaySpec(icon: "aqi.low", range: nil),
        "validity": SensorDisplaySpec(icon: "checkmark.circle", range: nil),
        "altitude": SensorDisplaySpec(icon: "mountain.2.fill", range: nil),
    ]

    private static let fallback = SensorDisplaySpec(icon: "gauge", range: nil)

    static func spec(forKey key: String, deviceClass: String?) -> SensorDisplaySpec {
        if let deviceClass, let spec = byDeviceClass[deviceClass] {
            return spec
        }
        return byKey[key] ?? fallback
    }

    /// Position a reading within its range, 0-1, for the meter fill.
    static func rangeFraction(_ value: Float, range: ClosedRange<Float>) -> Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return Double((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }
}
