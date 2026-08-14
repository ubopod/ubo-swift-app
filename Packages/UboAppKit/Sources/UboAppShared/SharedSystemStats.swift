//
//  SharedSystemStats.swift
//
//  Shared data model for widget and main app communication. Persisted as
//  JSON in the app-group UserDefaults suite; the widget reads it on every
//  timeline refresh.
//

import Foundation

/// Shared system stats that can be stored and read by both the main app and widgets
public struct SharedSystemStats: Codable, Sendable {
    public var cpuPercent: Float
    public var ramPercent: Float
    public var temperature: Float?
    public var temperatureUnit: String?
    public var lastUpdated: Date
    public var isConnected: Bool
    public var deviceHost: String

    public init(cpuPercent: Float = 0, ramPercent: Float = 0, temperature: Float? = nil, temperatureUnit: String? = nil, isConnected: Bool = false, deviceHost: String = "") {
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.temperature = temperature
        self.temperatureUnit = temperatureUnit
        self.lastUpdated = Date()
        self.isConnected = isConnected
        self.deviceHost = deviceHost
    }

    /// Save to shared UserDefaults
    public func save() {
        guard let defaults = UserDefaults(suiteName: UboConstants.appGroupIdentifier) else { return }
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: "systemStats")
        }
    }

    /// Load from shared UserDefaults
    public static func load() -> SharedSystemStats? {
        guard let defaults = UserDefaults(suiteName: UboConstants.appGroupIdentifier),
              let data = defaults.data(forKey: "systemStats"),
              let stats = try? JSONDecoder().decode(SharedSystemStats.self, from: data) else {
            return nil
        }
        return stats
    }

    /// Check if data is stale (older than 5 minutes)
    public var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > UboConstants.widgetStaleThreshold
    }
}
