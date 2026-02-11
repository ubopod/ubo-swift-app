//
//  WatchDashboardView.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct WatchDashboardView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Title
                Text("Dashboard")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Compact Gauges - values come as 0-100, normalize to 0-1
                HStack(spacing: 8) {
                    CompactGauge(
                        value: Double(viewModel.cpuPercent) / 100.0,
                        label: "CPU",
                        color: cpuColor
                    )

                    CompactGauge(
                        value: Double(viewModel.ramPercent) / 100.0,
                        label: "RAM",
                        color: ramColor
                    )

                    CompactTemperatureGauge(
                        temperature: viewModel.temperature,
                        color: tempColor
                    )
                }

                // Status Bar Info
                if let statusBar = viewModel.statusBar {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(statusBar.clock)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                // Quick Disconnect
                Button {
                    Task { await viewModel.disconnect() }
                } label: {
                    Label("Disconnect", systemImage: "wifi.slash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal)
        }
    }

    private var cpuColor: Color {
        let cpu = viewModel.cpuPercent  // 0-100
        if cpu > 80 { return .red }
        if cpu > 50 { return .orange }
        return .green
    }

    private var ramColor: Color {
        let ram = viewModel.ramPercent  // 0-100
        if ram > 80 { return .red }
        if ram > 50 { return .orange }
        return .green
    }

    private var tempColor: Color {
        guard let temp = viewModel.temperature else { return .gray }
        if temp > 70 { return .red }
        if temp > 50 { return .orange }
        return .green
    }
}

struct CompactGauge: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Gauge(value: value) {
                EmptyView()
            } currentValueLabel: {
                Text("\(Int(value * 100))")
                    .font(.system(size: 10))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)
            .scaleEffect(0.8)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

struct CompactTemperatureGauge: View {
    let temperature: Float?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Gauge(value: Double(temperature ?? 0) / 100.0) {
                EmptyView()
            } currentValueLabel: {
                if let temp = temperature {
                    Text(String(format: "%.0f°", temp))
                        .font(.system(size: 10))
                } else {
                    Text("--")
                        .font(.system(size: 10))
                }
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)
            .scaleEffect(0.8)

            Text("Temp")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchDashboardView()
        .environment(DeviceViewModel())
}
