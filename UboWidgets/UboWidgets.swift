//
//  UboWidgets.swift
//  UboWidgets
//
//  System status widget for Ubo device
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct SystemStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> SystemStatusEntry {
        SystemStatusEntry(date: Date(), stats: SharedSystemStats(cpuPercent: 25, ramPercent: 45, temperature: 42, isConnected: true, deviceHost: "ubo.local"))
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemStatusEntry) -> Void) {
        let stats = SharedSystemStats.load() ?? SharedSystemStats()
        completion(SystemStatusEntry(date: Date(), stats: stats))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemStatusEntry>) -> Void) {
        let stats = SharedSystemStats.load() ?? SharedSystemStats()
        let entry = SystemStatusEntry(date: Date(), stats: stats)

        // Update every 5 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct SystemStatusEntry: TimelineEntry {
    let date: Date
    let stats: SharedSystemStats
}

// MARK: - Widget Views

struct SystemStatusWidgetEntryView: View {
    var entry: SystemStatusProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(stats: entry.stats)
        case .systemMedium:
            MediumWidgetView(stats: entry.stats)
        case .systemLarge:
            LargeWidgetView(stats: entry.stats)
        case .accessoryCircular:
            AccessoryCircularView(stats: entry.stats)
        case .accessoryRectangular:
            AccessoryRectangularView(stats: entry.stats)
        case .accessoryInline:
            AccessoryInlineView(stats: entry.stats)
        default:
            SmallWidgetView(stats: entry.stats)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let stats: SharedSystemStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                    .font(.caption)
                Text("Ubo")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(stats.isConnected && !stats.isStale ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                StatRow(icon: "cpu", label: "CPU", value: stats.cpuPercent, color: cpuColor)
                StatRow(icon: "memorychip", label: "RAM", value: stats.ramPercent, color: ramColor)
                if let temp = stats.temperature {
                    TempRow(temperature: temp, color: tempColor)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var cpuColor: Color {
        if stats.cpuPercent > 80 { return .red }
        if stats.cpuPercent > 50 { return .orange }
        return .green
    }

    private var ramColor: Color {
        if stats.ramPercent > 80 { return .red }
        if stats.ramPercent > 50 { return .orange }
        return .green
    }

    private var tempColor: Color {
        guard let temp = stats.temperature else { return .gray }
        if temp > 70 { return .red }
        if temp > 50 { return .orange }
        return .green
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: Float
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 14)

            Text("\(Int(value))%")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

struct TempRow: View {
    let temperature: Float
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "thermometer")
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 14)

            Text(String(format: "%.0f°C", temperature))
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let stats: SharedSystemStats

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Gauges
            HStack(spacing: 12) {
                GaugeView(value: Double(stats.cpuPercent) / 100, label: "CPU", icon: "cpu", color: cpuColor)
                GaugeView(value: Double(stats.ramPercent) / 100, label: "RAM", icon: "memorychip", color: ramColor)
                if let temp = stats.temperature {
                    GaugeView(value: Double(temp) / 100, label: "Temp", icon: "thermometer", color: tempColor, displayValue: String(format: "%.0f°", temp))
                }
            }

            // Right side - Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Ubo Pod")
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(stats.isConnected && !stats.isStale ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                }

                if !stats.deviceHost.isEmpty {
                    Text(stats.deviceHost)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Updated \(stats.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var cpuColor: Color {
        if stats.cpuPercent > 80 { return .red }
        if stats.cpuPercent > 50 { return .orange }
        return .green
    }

    private var ramColor: Color {
        if stats.ramPercent > 80 { return .red }
        if stats.ramPercent > 50 { return .orange }
        return .green
    }

    private var tempColor: Color {
        guard let temp = stats.temperature else { return .gray }
        if temp > 70 { return .red }
        if temp > 50 { return .orange }
        return .green
    }
}

struct GaugeView: View {
    let value: Double
    let label: String
    let icon: String
    let color: Color
    var displayValue: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            Gauge(value: value) {
                Image(systemName: icon)
                    .font(.caption2)
            } currentValueLabel: {
                Text(displayValue ?? "\(Int(value * 100))%")
                    .font(.system(size: 10))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let stats: SharedSystemStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .font(.title3)
                Text("Ubo Pod")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(stats.isConnected && !stats.isStale ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(stats.isConnected && !stats.isStale ? "Connected" : "Offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !stats.deviceHost.isEmpty {
                Text(stats.deviceHost)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Gauges
            HStack(spacing: 20) {
                LargeGaugeView(value: Double(stats.cpuPercent) / 100, label: "CPU", icon: "cpu", color: cpuColor)
                LargeGaugeView(value: Double(stats.ramPercent) / 100, label: "RAM", icon: "memorychip", color: ramColor)
                if let temp = stats.temperature {
                    LargeGaugeView(value: Double(temp) / 100, label: "Temperature", icon: "thermometer", color: tempColor, displayValue: String(format: "%.1f°C", temp))
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            // Footer
            HStack {
                Text("Last updated: \(stats.lastUpdated, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var cpuColor: Color {
        if stats.cpuPercent > 80 { return .red }
        if stats.cpuPercent > 50 { return .orange }
        return .green
    }

    private var ramColor: Color {
        if stats.ramPercent > 80 { return .red }
        if stats.ramPercent > 50 { return .orange }
        return .green
    }

    private var tempColor: Color {
        guard let temp = stats.temperature else { return .gray }
        if temp > 70 { return .red }
        if temp > 50 { return .orange }
        return .green
    }
}

struct LargeGaugeView: View {
    let value: Double
    let label: String
    let icon: String
    let color: Color
    var displayValue: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Gauge(value: value) {
                Image(systemName: icon)
            } currentValueLabel: {
                Text(displayValue ?? "\(Int(value * 100))%")
                    .font(.caption)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)
            .scaleEffect(1.2)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Lock Screen Widgets

struct AccessoryCircularView: View {
    let stats: SharedSystemStats

    var body: some View {
        Gauge(value: Double(stats.cpuPercent) / 100) {
            Image(systemName: "cpu")
        } currentValueLabel: {
            Text("\(Int(stats.cpuPercent))")
                .font(.caption2)
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct AccessoryRectangularView: View {
    let stats: SharedSystemStats

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Label("CPU", systemImage: "cpu")
                    .font(.caption2)
                Text("\(Int(stats.cpuPercent))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Label("RAM", systemImage: "memorychip")
                    .font(.caption2)
                Text("\(Int(stats.ramPercent))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            if let temp = stats.temperature {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Label("Temp", systemImage: "thermometer")
                        .font(.caption2)
                    Text(String(format: "%.0f°", temp))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct AccessoryInlineView: View {
    let stats: SharedSystemStats

    var body: some View {
        if let temp = stats.temperature {
            Text("CPU \(Int(stats.cpuPercent))% | RAM \(Int(stats.ramPercent))% | \(Int(temp))°C")
        } else {
            Text("CPU \(Int(stats.cpuPercent))% | RAM \(Int(stats.ramPercent))%")
        }
    }
}

// MARK: - Widget Configuration

struct UboWidgets: Widget {
    let kind: String = "UboSystemStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemStatusProvider()) { entry in
            SystemStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ubo System Status")
        .description("Monitor your Ubo device's CPU, RAM, and temperature.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    UboWidgets()
} timeline: {
    SystemStatusEntry(date: Date(), stats: SharedSystemStats(cpuPercent: 45, ramPercent: 62, temperature: 48, isConnected: true, deviceHost: "ubo.local"))
}

#Preview("Medium", as: .systemMedium) {
    UboWidgets()
} timeline: {
    SystemStatusEntry(date: Date(), stats: SharedSystemStats(cpuPercent: 45, ramPercent: 62, temperature: 48, isConnected: true, deviceHost: "ubo.local"))
}

#Preview("Large", as: .systemLarge) {
    UboWidgets()
} timeline: {
    SystemStatusEntry(date: Date(), stats: SharedSystemStats(cpuPercent: 45, ramPercent: 62, temperature: 48, isConnected: true, deviceHost: "ubo.local"))
}
