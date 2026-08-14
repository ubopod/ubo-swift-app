//
//  SystemSection.swift
//  ubo-swift-app
//
//  CPU + RAM + Storage + Network + Uptime merged into one card, for the
//  same reason as TodaySection: a page-level grid of separately-sized
//  system tiles produces large dead gaps when row heights don't match.
//

import SwiftUI

struct SystemSection: View {
    let cpuPercent: Float
    let ramPercent: Float
    let temperature: Float?
    let temperatureUnit: String?
    let diskPercent: Float?
    let diskUsedBytes: Int64?
    let diskTotalBytes: Int64?
    let networkUploadBps: Float?
    let networkDownloadBps: Float?
    let bootTime: Float?
    let loadAverage1: Float?
    let loadAverage5: Float?
    let loadAverage15: Float?

    var body: some View {
        DashboardCard(title: "System", icon: "cpu") {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        DashboardGauge(
                            fraction: Double(cpuPercent / 100),
                            valueText: "\(Int(cpuPercent.rounded()))",
                            unit: "%",
                            icon: "cpu",
                            color: DashboardColor.loadSeverity(cpuPercent)
                        )
                        .frame(width: 64, height: 64)
                        Text("CPU").font(.caption2).foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        DashboardGauge(
                            fraction: Double(ramPercent / 100),
                            valueText: "\(Int(ramPercent.rounded()))",
                            unit: "%",
                            icon: "memorychip",
                            color: DashboardColor.loadSeverity(ramPercent)
                        )
                        .frame(width: 64, height: 64)
                        Text("RAM").font(.caption2).foregroundStyle(.secondary)
                    }

                    if let diskTotal = diskTotalBytes, diskTotal > 0 {
                        VStack(spacing: 4) {
                            DashboardGauge(
                                fraction: Double((diskPercent ?? 0) / 100),
                                valueText: "\(Int((diskPercent ?? 0).rounded()))",
                                unit: "%",
                                icon: "internaldrive",
                                color: DashboardColor.loadSeverity(diskPercent ?? 0)
                            )
                            .frame(width: 64, height: 64)
                            Text("Storage").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack(spacing: 8) {
                    if let temperature {
                        DashboardStat(label: "Temperature", value: String(format: "%.1f", temperature), unit: temperatureUnit ?? "°C", icon: "thermometer")
                    }
                    if let diskUsedBytes, let diskTotalBytes, diskTotalBytes > 0 {
                        DashboardStat(
                            label: "Storage used",
                            value: "\(DashboardFormat.bytes(diskUsedBytes)) / \(DashboardFormat.bytes(diskTotalBytes))"
                        )
                    }
                    DashboardStat(
                        label: "Upload",
                        value: DashboardFormat.rate(networkUploadBps ?? 0),
                        icon: "arrow.up",
                        valueColor: DashboardColor.good
                    )
                    DashboardStat(
                        label: "Download",
                        value: DashboardFormat.rate(networkDownloadBps ?? 0),
                        icon: "arrow.down",
                        valueColor: DashboardColor.neutralAccent
                    )
                    if let bootTime, bootTime > 0 {
                        DashboardStat(label: "Uptime", value: DashboardFormat.uptime(bootTime: bootTime), icon: "clock.arrow.circlepath")
                        if let l1 = loadAverage1, let l5 = loadAverage5, let l15 = loadAverage15 {
                            DashboardStat(label: "Load avg", value: String(format: "%.2f  %.2f  %.2f", l1, l5, l15))
                        }
                    }
                }
            }
        }
    }
}
