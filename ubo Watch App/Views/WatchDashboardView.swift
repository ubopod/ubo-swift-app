//
//  WatchDashboardView.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//
//  Paginated to fit the watch's small screen instead of one long scroll:
//  System (CPU/RAM/Storage/temp/uptime) → Weather/Date/Time → Apps →
//  one page per connected sensor device. The sensor page count is dynamic
//  — it tracks `stats.sensorDevices` directly, so adding/removing a
//  sensor changes the page count without restarting the app. Swipe
//  horizontally between pages; the outer tab bar (Dashboard/Device/
//  Actions) still pages vertically, so the two gestures don't collide.
//

import UboAppKit
import SwiftUI
import UboSwift

struct WatchDashboardView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        Group {
            if let stats = viewModel.stats {
                TabView {
                    WatchSystemPage(stats: stats)

                    WatchWeatherDateTimePage(stats: stats)

                    if !stats.dockerApps.isEmpty {
                        WatchAppsPage(apps: stats.dockerApps)
                    }

                    ForEach(stats.sensorDevices) { device in
                        WatchSensorPage(device: device)
                    }
                }
                .tabViewStyle(.page)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for readings…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    WatchDashboardView()
        .environment(DeviceViewModel())
}
