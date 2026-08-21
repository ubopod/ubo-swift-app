//
//  WatchSystemPage.swift
//  ubo Watch App
//
//  Page 1 of the watch Dashboard: CPU/RAM/Storage as compact gauges, CPU
//  temperature as a plain number+icon (a gauge adds nothing at this size),
//  and uptime as text. Load average is intentionally omitted on watch —
//  not a glanceable number at this scale.
//

import UboAppKit
import SwiftUI
import UboSwift

struct WatchSystemPage: View {
    let stats: SystemStats

    var body: some View {
        // Neither `ScrollView` nor `List` hands boundary overscroll off to
        // the enclosing `TabView(.verticalPage)` on watchOS once content
        // actually overflows — confirmed by reproducing swipe-down doing
        // nothing once scrolled to the bottom of an overflowing page, with
        // both container types. Whichever one has real scrollable content
        // just owns the entire vertical touch axis, permanently, making
        // the outer Device/Actions tabs unreachable by swipe.
        // `scrollDisabled` frees touch for the outer Pager; the Digital
        // Crown still scrolls this page's content natively without it (no
        // separate wiring needed for that half) — but anything requiring
        // touch to reach (like the disconnect button this page used to
        // have) is effectively unreachable, which is why Disconnect now
        // lives in the Actions tab's plain scrolling list instead.
        List {
            VStack(spacing: 10) {
                Text("System")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    WatchCompactGauge(
                        fraction: Double(stats.cpuPercent / 100),
                        valueText: "\(Int(stats.cpuPercent.rounded()))",
                        label: "CPU",
                        color: WatchFormat.loadSeverity(stats.cpuPercent)
                    )
                    WatchCompactGauge(
                        fraction: Double(stats.ramPercent / 100),
                        valueText: "\(Int(stats.ramPercent.rounded()))",
                        label: "RAM",
                        color: WatchFormat.loadSeverity(stats.ramPercent)
                    )
                    if let diskPercent = stats.diskPercent, let diskTotal = stats.diskTotalBytes, diskTotal > 0 {
                        WatchCompactGauge(
                            fraction: Double(diskPercent / 100),
                            valueText: "\(Int(diskPercent.rounded()))",
                            label: "Storage",
                            color: WatchFormat.loadSeverity(diskPercent)
                        )
                    }
                }

                if let temperature = stats.temperatureDisplayValue ?? stats.temperature {
                    Label(
                        "\(String(format: "%.1f", temperature))\(stats.temperatureDisplayUnit ?? "°C")",
                        systemImage: "thermometer"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if let bootTime = stats.bootTime, bootTime > 0 {
                    Label(WatchFormat.uptime(bootTime: bootTime), systemImage: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .listRowBackground(Color.clear)
        }
        .listStyle(.carousel)
        .scrollDisabled(true)
    }
}
