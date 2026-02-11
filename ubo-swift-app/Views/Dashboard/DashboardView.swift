//
//  DashboardView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct DashboardView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // System Stats Section
                    systemStatsSection

                    // Quick Actions Section
                    QuickActionsView()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .refreshable {
                // Navigate home to refresh the home view data
                try? await viewModel.client.goHome()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.disconnect()
                        }
                    } label: {
                        Image(systemName: "wifi.slash")
                    }
                }
            }
        }
    }

    private var systemStatsSection: some View {
        VStack(spacing: 16) {
            Text("System Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            HStack(spacing: 20) {
                // CPU and RAM come as 0-100, normalize to 0-1 for Gauge
                GaugeCard(
                    title: "CPU",
                    value: Double(viewModel.cpuPercent) / 100.0,
                    icon: "cpu",
                    color: cpuColor
                )

                GaugeCard(
                    title: "RAM",
                    value: Double(viewModel.ramPercent) / 100.0,
                    icon: "memorychip",
                    color: ramColor
                )

                // Temperature gauge (normalized to 0-100°C range)
                TemperatureCard(
                    temperature: viewModel.temperature,
                    color: tempColor
                )
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

struct GaugeCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Gauge(value: value) {
                Image(systemName: icon)
                    .font(.caption)
            } currentValueLabel: {
                Text("\(Int(value * 100))%")
                    .font(.caption2)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
}

struct TemperatureCard: View {
    let temperature: Float?
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            // Normalize temperature to 0-1 range (assuming 0-100°C range)
            Gauge(value: Double(temperature ?? 0) / 100.0) {
                Image(systemName: "thermometer")
                    .font(.caption)
            } currentValueLabel: {
                if let temp = temperature {
                    Text(String(format: "%.0f°", temp))
                        .font(.caption2)
                } else {
                    Text("--")
                        .font(.caption2)
                }
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)

            Text("Temp")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
}

#Preview {
    DashboardView()
        .environment(DeviceViewModel())
}
