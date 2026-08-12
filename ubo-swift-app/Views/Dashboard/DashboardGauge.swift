//
//  DashboardGauge.swift
//  ubo-swift-app
//
//  Shared circular gauge for Dashboard tiles (CPU/RAM/Storage/sensor
//  readings). Uses SwiftUI's native `Gauge` instead of porting the Web
//  UI's hand-drawn SVG arc (`Gauge.tsx`) — the platform already has an
//  accessory-circular gauge style built for exactly this.
//

import SwiftUI

struct DashboardGauge: View {
    /// 0-1 fill fraction.
    let fraction: Double
    let valueText: String
    var unit: String?
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        #if os(tvOS)
        ProgressView(value: fraction) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(.secondary)
        } currentValueLabel: {
            valueLabel
        }
        .tint(color)
        #else
        Gauge(value: fraction) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(.secondary)
        } currentValueLabel: {
            valueLabel
        }
        .gaugeStyle(.accessoryCircular)
        .tint(color)
        #endif
    }

    private var valueLabel: some View {
        VStack(spacing: 0) {
            Text(valueText)
                .font(.caption2.weight(.semibold))
            if let unit {
                Text(unit)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
