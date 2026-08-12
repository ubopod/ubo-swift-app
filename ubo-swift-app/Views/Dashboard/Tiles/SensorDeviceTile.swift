//
//  SensorDeviceTile.swift
//  ubo-swift-app
//
//  One tile per connected sensor device, mirroring the Web UI's
//  `SensorCards.tsx`. Entities with a natural range (per `SensorDisplay`)
//  render as a row of mini gauges (chunked 3-per-row so it doesn't
//  overflow the card on narrow screens); the rest render as plain stats.
//

import SwiftUI
import UboSwift

struct SensorDeviceTile: View {
    let device: SensorDeviceState

    private var metered: [SensorEntityReading] {
        device.entities.filter { SensorDisplay.spec(forKey: $0.key, deviceClass: $0.deviceClass).range != nil && $0.value != nil }
    }

    private var plain: [SensorEntityReading] {
        device.entities.filter { entity in !metered.contains { $0.id == entity.id } }
    }

    var body: some View {
        DashboardCard(title: device.label, icon: "sensor.fill") {
            switch device.status {
            case .active:
                VStack(spacing: 10) {
                    ForEach(Array(metered.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 14) {
                            ForEach(row) { entity in
                                gauge(entity)
                            }
                            if row.count < 3 { Spacer(minLength: 0) }
                        }
                    }
                    ForEach(plain) { entity in
                        statRow(entity)
                    }
                }
            case .error:
                Text("Sensor error").font(.caption).foregroundStyle(DashboardColor.critical)
            case .unsupported:
                Text("Unsupported sensor").font(.caption).foregroundStyle(.secondary)
            case .ambiguous:
                Text("Ambiguous reading").font(.caption).foregroundStyle(.secondary)
            case .unspecified:
                Text("—").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func gauge(_ entity: SensorEntityReading) -> some View {
        let spec = SensorDisplay.spec(forKey: entity.key, deviceClass: entity.deviceClass)
        let valueText = DashboardFormat.reading(entity.value, precision: entity.precision)
        VStack(spacing: 4) {
            if let range = spec.range, let value = entity.value {
                DashboardGauge(
                    fraction: SensorDisplay.rangeFraction(value, range: range),
                    valueText: valueText,
                    unit: entity.unit,
                    icon: spec.icon,
                    color: DashboardColor.gaugeAccent
                )
                .frame(width: 56, height: 56)
            }
            Text(entity.name ?? entity.key)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func statRow(_ entity: SensorEntityReading) -> some View {
        let spec = SensorDisplay.spec(forKey: entity.key, deviceClass: entity.deviceClass)
        let valueText = DashboardFormat.reading(entity.value, precision: entity.precision)
        return DashboardStat(label: entity.name ?? entity.key, value: valueText, unit: entity.unit, icon: spec.icon)
    }
}
