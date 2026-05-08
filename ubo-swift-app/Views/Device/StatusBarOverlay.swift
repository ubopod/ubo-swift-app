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
