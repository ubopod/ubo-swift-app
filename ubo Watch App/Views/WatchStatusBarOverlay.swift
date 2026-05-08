//
//  WatchStatusBarOverlay.swift
//  ubo Watch App
//
//  Compact CPU/RAM/clock chip shown atop `WatchDeviceView`. Mirrors the
//  GUI client's status bar for parity context.
//

import SwiftUI
import UboSwift

struct WatchStatusBarOverlay: View {
    let bar: StatusBarData?
    let cpuPercent: Float
    let ramPercent: Float
    let temperature: Float?

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                Text("\(Int(cpuPercent))%")
            }
            HStack(spacing: 2) {
                Image(systemName: "memorychip")
                Text("\(Int(ramPercent))%")
            }
            if let temp = temperature {
                HStack(spacing: 2) {
                    Image(systemName: "thermometer.medium")
                    Text("\(Int(temp))°")
                }
            }

            if let bar = bar, !bar.icons.isEmpty {
                ForEach(Array(bar.icons.enumerated()), id: \.offset) { (_, icon) in
                    IconView(
                        icon: icon.symbol,
                        size: 9,
                        color: Color(hex: icon.color) ?? .secondary
                    )
                }
            }

            if let bar, !bar.progressNotifications.isEmpty {
                ForEach(bar.progressNotifications, id: \.id) { pn in
                    WatchProgressBarChip(
                        progress: pn.progress,
                        color: Color(hex: pn.color) ?? .accentColor
                    )
                }
            }

            Spacer()

            if let bar, !bar.clock.isEmpty {
                Text(bar.clock)
                    .font(.system(size: 9, design: .monospaced))
            }
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}

/// Compact linear progress chip mirroring the Web UI's `<LinearProgress>`
/// — narrower than the iPhone counterpart so it fits the watch bezel.
private struct WatchProgressBarChip: View {
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
        .frame(width: 24)
    }
}
