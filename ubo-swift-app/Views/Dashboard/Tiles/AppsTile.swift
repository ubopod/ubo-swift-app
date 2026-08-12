//
//  AppsTile.swift
//  ubo-swift-app
//
//  One row per installed Docker app, mirroring the Web UI's `AppsCard`.
//  Health outranks lifecycle status — the same precedence
//  `_update_app_badge` applies on the device
//  (`ubo_app/services/080-docker/menus.py`) — so a crash-looping app under
//  `restart_policy: always` still shows red even while it cycles back to
//  RUNNING every few seconds.
//

import SwiftUI
import UboSwift

private struct AppPresentation {
    let symbol: String
    let color: Color
    let text: String
}

private func present(_ app: DockerAppStatus) -> AppPresentation {
    switch app.health {
    case .crashLooping:
        return AppPresentation(symbol: "exclamationmark.triangle.fill", color: DashboardColor.critical, text: "Crash looping")
    case .recovered:
        return AppPresentation(symbol: "exclamationmark.triangle.fill", color: DashboardColor.warning, text: "Restarted")
    case .ok, .unspecified:
        break
    }
    switch app.status {
    case .running:
        return AppPresentation(symbol: "circle.fill", color: DashboardColor.good, text: "Running")
    case .starting:
        return AppPresentation(symbol: "circle.fill", color: DashboardColor.warning, text: "Starting")
    case .fetching:
        return AppPresentation(symbol: "circle.fill", color: DashboardColor.warning, text: "Fetching")
    case .processing:
        return AppPresentation(symbol: "circle.fill", color: DashboardColor.warning, text: "Working")
    case .error:
        return AppPresentation(symbol: "exclamationmark.triangle.fill", color: DashboardColor.critical, text: "Errored")
    case .available, .created:
        return AppPresentation(symbol: "circle", color: DashboardColor.idle, text: "Stopped")
    case .notAvailable, .unspecified:
        return AppPresentation(symbol: "questionmark.circle", color: DashboardColor.idle, text: "Unknown")
    }
}

struct AppsTile: View {
    let apps: [DockerAppStatus]

    private var sorted: [DockerAppStatus] {
        apps.sorted { ($0.label.isEmpty ? $0.id : $0.label) < ($1.label.isEmpty ? $1.id : $1.label) }
    }

    var body: some View {
        DashboardCard(title: "Apps", icon: "shippingbox.fill") {
            VStack(spacing: 8) {
                ForEach(sorted) { app in
                    let presentation = present(app)
                    HStack(spacing: 8) {
                        Image(systemName: presentation.symbol)
                            .foregroundStyle(presentation.color)
                            .font(.caption)
                        Text(app.label.isEmpty ? app.id : app.label)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(presentation.text)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(presentation.color)
                    }
                }
            }
        }
    }
}
