//
//  SharedSystemStats.swift
//  ubo-swift-app
//
//  Shared data model for widget and main app communication
//

import Foundation

/// App Group identifier for sharing data between app and widget
let appGroupIdentifier = "group.com.ubo.swift-app"

/// Shared system stats that can be stored and read by both the main app and widgets
struct SharedSystemStats: Codable {
    var cpuPercent: Float
    var ramPercent: Float
    var temperature: Float?
    var lastUpdated: Date
    var isConnected: Bool
    var deviceHost: String

    init(cpuPercent: Float = 0, ramPercent: Float = 0, temperature: Float? = nil, isConnected: Bool = false, deviceHost: String = "") {
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.temperature = temperature
        self.lastUpdated = Date()
        self.isConnected = isConnected
        self.deviceHost = deviceHost
    }

    /// Save to shared UserDefaults
    func save() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: "systemStats")
        }
    }

    /// Load from shared UserDefaults
    static func load() -> SharedSystemStats? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: "systemStats"),
              let stats = try? JSONDecoder().decode(SharedSystemStats.self, from: data) else {
            return nil
        }
        return stats
    }

    /// Check if data is stale (older than 5 minutes)
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 300
    }
}
