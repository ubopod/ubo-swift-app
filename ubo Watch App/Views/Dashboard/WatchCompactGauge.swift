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
    /// Server-driven — never hardcode a unit here, since it's server-driven
    /// (°C vs °F, ppm, µg/m³, lx, ...). Nil/blank omits the sub-label
    /// entirely, matching System page's %-embedded-in-valueText gauges,
    /// which don't need one.
    var unit: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            Gauge(value: fraction) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text(valueText)
                        .font(.system(size: unit?.isEmpty == false ? 9 : 10))
                    if let unit, !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                    }
                }
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
