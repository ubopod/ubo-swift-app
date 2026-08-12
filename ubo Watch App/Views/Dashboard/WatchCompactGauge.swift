//
//  WatchCompactGauge.swift
//  ubo Watch App
//
//  Small circular gauge shared by the Dashboard pages (System page's
//  CPU/RAM/Storage, and per-entity gauges on sensor pages).
//

import SwiftUI

struct WatchCompactGauge: View {
    /// 0-1 fill fraction.
    let fraction: Double
    let valueText: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Gauge(value: fraction) {
                EmptyView()
            } currentValueLabel: {
                Text(valueText)
                    .font(.system(size: 10))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)
            .scaleEffect(0.8)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}
