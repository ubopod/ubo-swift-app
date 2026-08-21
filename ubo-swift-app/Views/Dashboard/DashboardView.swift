//
//  DashboardView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//
//  Semantic sections mirroring the Web UI dashboard
//  (ubo_app/services/090-web-ui/web-app/src/components/dashboard/
//  Dashboard.tsx): Today (weather/date/time), System (CPU/RAM/storage/
//  network/uptime), Apps, and per-device Sensors — each its own
//  full-width card in a single column, rather than a page-level grid.
//  A LazyVGrid was tried first, but SwiftUI's LazyVGrid locks every row's
//  height to its tallest cell: a short tile (e.g. a single-reading
//  sensor) next to a tall one (e.g. Weather, or a 4-entity sensor) left
//  large dead gaps beneath the short ones. Grouping into fewer, purpose-
//  built cards removes the row-height mismatch entirely, and happens to
//  match how information is easiest to scan on a phone besides.
//

import UboAppKit
import SwiftUI
import UboSwift

struct DashboardView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    private var stats: SystemStats? {
        viewModel.stats
    }

    /// Devices with more than one reading (or a non-active status message
    /// to show) keep their own full-width card.
    private func multiReadingDevices(_ stats: SystemStats) -> [SensorDeviceState] {
        stats.sensorDevices.filter { $0.status != .active || $0.entities.count != 1 }
    }

    /// Devices reporting exactly one active reading — grouped into a row
    /// of compact square tiles instead of a mostly-empty full-width card.
    private func singleReadingDevices(_ stats: SystemStats) -> [(device: SensorDeviceState, entity: SensorEntityReading)] {
        stats.sensorDevices.compactMap { device in
            guard device.status == .active, let entity = device.entities.first, device.entities.count == 1 else {
                return nil
            }
            return (device, entity)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let stats {
                    VStack(spacing: 16) {
                        TodaySection(
                            weather: stats.weather,
                            locationCity: stats.locationCity,
                            locationCountry: stats.locationCountry,
                            date: stats.date,
                            clock: stats.clock
                        )

                        SystemSection(
                            cpuPercent: stats.cpuPercent,
                            ramPercent: stats.ramPercent,
                            temperature: stats.temperatureDisplayValue ?? stats.temperature,
                            temperatureUnit: stats.temperatureDisplayUnit,
                            diskPercent: stats.diskPercent,
                            diskUsedBytes: stats.diskUsedBytes,
                            diskTotalBytes: stats.diskTotalBytes,
                            networkUploadBps: stats.networkUploadBps,
                            networkDownloadBps: stats.networkDownloadBps,
                            bootTime: stats.bootTime,
                            loadAverage1: stats.loadAverage1,
                            loadAverage5: stats.loadAverage5,
                            loadAverage15: stats.loadAverage15
                        )

                        if !stats.dockerApps.isEmpty {
                            AppsTile(apps: stats.dockerApps)
                        }

                        ForEach(multiReadingDevices(stats)) { device in
                            SensorDeviceTile(device: device)
                        }

                        let compact = singleReadingDevices(stats)
                        if !compact.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(Array(compact.chunked(into: 4).enumerated()), id: \.offset) { _, row in
                                    HStack(spacing: 12) {
                                        ForEach(row, id: \.device.id) { pair in
                                            CompactSensorTile(label: pair.entity.name ?? pair.device.label, entity: pair.entity)
                                        }
                                        if row.count < 4 { Spacer(minLength: 0) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                } else {
                    Text("Waiting for the first readings…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                }
            }
            .refreshable {
                // Navigate home to refresh the home view data
                do { try await viewModel.client.goHome() } catch { viewModel.report("goHome", error) }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.disconnect()
                        }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(DeviceViewModel())
}
