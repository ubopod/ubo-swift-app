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
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "cpu")
                    Text("\(Int(cpuPercent))%")
                        .lineLimit(1)
                        .fixedSize()
                }
                HStack(spacing: 2) {
                    Image(systemName: "memorychip")
                    Text("\(Int(ramPercent))%")
                        .lineLimit(1)
                        .fixedSize()
                }
                if let temp = temperature {
                    HStack(spacing: 2) {
                        Image(systemName: "thermometer.medium")
                        Text("\(Int(temp))°")
                            .lineLimit(1)
                            .fixedSize()
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

                Spacer()

                if let bar, !bar.clock.isEmpty {
                    Text(bar.clock)
                        .font(.system(size: 9, design: .monospaced))
                        .lineLimit(1)
                        .fixedSize()
                }
            }

            // Background-task progress on its own row keeps the metric
            // chips on the watch from getting squeezed off-screen.
            if let bar, !bar.progressNotifications.isEmpty {
                HStack(spacing: 4) {
                    ForEach(bar.progressNotifications, id: \.id) { pn in
                        WatchProgressBarChip(
                            progress: pn.progress,
                            color: Color(hex: pn.color) ?? .accentColor
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}

/// Compact linear progress chip mirroring the Web UI's `<LinearProgress>`.
/// `nil` → animated indeterminate; `0...1` → determinate fill.
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
        .frame(width: 36)
    }
}
