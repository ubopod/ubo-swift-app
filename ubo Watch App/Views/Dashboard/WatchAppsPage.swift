//
//  WatchAppsPage.swift
//  ubo Watch App
//
//  Page 3 of the watch Dashboard: one compact row per installed Docker
//  app, same status/health precedence as the phone's AppsTile (health
//  outranks lifecycle status so a crash-looping app under
//  `restart_policy: always` still reads red).
//

import SwiftUI
import UboSwift

private struct WatchAppPresentation {
    let symbol: String
    let color: Color
    let text: String
}

private func present(_ app: DockerAppStatus) -> WatchAppPresentation {
    switch app.health {
    case .crashLooping:
        return WatchAppPresentation(symbol: "exclamationmark.triangle.fill", color: .red, text: "Crash looping")
    case .recovered:
        return WatchAppPresentation(symbol: "exclamationmark.triangle.fill", color: .orange, text: "Restarted")
    case .ok, .unspecified:
        break
    }
    switch app.status {
    case .running: return WatchAppPresentation(symbol: "circle.fill", color: .green, text: "Running")
    case .starting: return WatchAppPresentation(symbol: "circle.fill", color: .orange, text: "Starting")
    case .fetching: return WatchAppPresentation(symbol: "circle.fill", color: .orange, text: "Fetching")
    case .processing: return WatchAppPresentation(symbol: "circle.fill", color: .orange, text: "Working")
    case .error: return WatchAppPresentation(symbol: "exclamationmark.triangle.fill", color: .red, text: "Errored")
    case .available, .created: return WatchAppPresentation(symbol: "circle", color: .gray, text: "Stopped")
    case .notAvailable, .unspecified: return WatchAppPresentation(symbol: "questionmark.circle", color: .gray, text: "Unknown")
    }
}

struct WatchAppsPage: View {
    let apps: [DockerAppStatus]

    private var sorted: [DockerAppStatus] {
        apps.sorted { ($0.label.isEmpty ? $0.id : $0.label) < ($1.label.isEmpty ? $1.id : $1.label) }
    }

    var body: some View {
        // scrollDisabled — see the comment on WatchSystemPage's body for
        // why: neither ScrollView nor List hands boundary overscroll off
        // to the enclosing TabView(.verticalPage) once content overflows,
        // making Device/Actions unreachable by swipe. The Crown still
        // scrolls this natively without touch.
        List {
            VStack(spacing: 8) {
                Text("Apps")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(sorted) { app in
                    let presentation = present(app)
                    HStack(spacing: 6) {
                        Image(systemName: presentation.symbol)
                            .foregroundStyle(presentation.color)
                            .font(.caption2)
                        Text(app.label.isEmpty ? app.id : app.label)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(presentation.text)
                            .font(.system(size: 9).weight(.semibold))
                            .foregroundStyle(presentation.color)
                    }
                }
            }
            .padding(.horizontal)
            .listRowBackground(Color.clear)
        }
        .listStyle(.carousel)
        .scrollDisabled(true)
    }
}
