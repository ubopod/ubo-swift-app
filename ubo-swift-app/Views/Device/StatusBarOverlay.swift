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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                    Text("\(Int(cpuPercent))%")
                        .lineLimit(1)
                        .fixedSize()
                }
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                    Text("\(Int(ramPercent))%")
                        .lineLimit(1)
                        .fixedSize()
                }
                if let temp = temperature {
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.medium")
                        Text("\(Int(temp))°C")
                            .lineLimit(1)
                            .fixedSize()
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

                Spacer()

                if let bar, !bar.clock.isEmpty {
                    Text(bar.clock)
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                        .fixedSize()
                }
            }

            // Background-task progress lives on its own row so it can't
            // squeeze the metric chips into wrapping. Hidden when the
            // device has nothing in flight.
            if let bar, !bar.progressNotifications.isEmpty {
                HStack(spacing: 8) {
                    ForEach(bar.progressNotifications, id: \.id) { pn in
                        ProgressBarChip(
                            progress: pn.progress,
                            color: Color(hex: pn.color) ?? .accentColor
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial)
    }
}

/// Tiny linear progress chip mirroring the Web UI's `<LinearProgress>`.
/// `nil` → animated indeterminate; `0...1` → determinate fill.
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
        .frame(width: 60)
    }
}
