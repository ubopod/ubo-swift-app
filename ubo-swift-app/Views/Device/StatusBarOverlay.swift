//
//  StatusBarOverlay.swift
//  ubo-swift-app
//
//  Renders the GUI client's CPU/RAM/temperature/clock/icons status bar at
//  the top of `DeviceView`, mirroring the bar shown on the Pi screen so
//  users have parity context across clients.
//

import SwiftUI
import UboSwift

struct StatusBarOverlay: View {
    let bar: StatusBarData?
    let cpuPercent: Float
    let ramPercent: Float
    let temperature: Float?

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                Text("\(Int(cpuPercent))%")
            }
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                Text("\(Int(ramPercent))%")
            }
            if let temp = temperature {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                    Text("\(Int(temp))°C")
                }
            }

            if let bar = bar, !bar.icons.isEmpty {
                Divider().frame(height: 12)
                ForEach(Array(bar.icons.enumerated()), id: \.offset) { (_, icon) in
                    IconView(
                        icon: icon.symbol,
                        size: 12,
                        color: Color(hex: icon.color) ?? .secondary
                    )
                }
            }

            if let bar, !bar.progressNotifications.isEmpty {
                Divider().frame(height: 12)
                ForEach(bar.progressNotifications, id: \.id) { pn in
                    ProgressBarChip(
                        progress: pn.progress,
                        color: Color(hex: pn.color) ?? .accentColor
                    )
                }
            }

            Spacer()

            if let bar, !bar.clock.isEmpty {
                Text(bar.clock)
                    .font(.caption.monospacedDigit())
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial)
    }
}

/// Tiny linear progress chip mirroring the Web UI's `<LinearProgress>`
/// (40 × 4 px). When `progress` is `nil` the bar is indeterminate; when
/// it's a value in `0...1` it's determinate.
private struct ProgressBarChip: View {
    let progress: Float?
    let color: Color

    var body: some View {
        Group {
            if let progress {
                ProgressView(value: max(0, min(1, Double(progress))))
            } else {
                ProgressView()
            }
        }
        .progressViewStyle(.linear)
        .tint(color)
        .frame(width: 40)
    }
}
