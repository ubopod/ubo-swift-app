//
//  WatchSensorPage.swift
//  ubo Watch App
//
//  One page per connected sensor device — the dashboard's page count
//  grows/shrinks as sensors are added or removed, since watch pages are
//  generated from `stats.sensorDevices` directly (see WatchDashboardView).
//

import SwiftUI
import UboSwift

struct WatchSensorPage: View {
    let device: SensorDeviceState

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(device.label)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)

                switch device.status {
                case .active:
                    ForEach(device.entities) { entity in
                        entityRow(entity)
                    }
                case .error:
                    Text("Sensor error").font(.caption2).foregroundStyle(.red)
                case .unsupported:
                    Text("Unsupported").font(.caption2).foregroundStyle(.secondary)
                case .ambiguous:
                    Text("Ambiguous reading").font(.caption2).foregroundStyle(.secondary)
                case .unspecified:
                    Text("—").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func entityRow(_ entity: SensorEntityReading) -> some View {
        let spec = WatchSensorDisplay.spec(forKey: entity.key, deviceClass: entity.deviceClass)
        let valueText = WatchSensorDisplay.reading(entity.value, precision: entity.precision)

        if let range = spec.range, let value = entity.value {
            HStack(spacing: 6) {
                WatchCompactGauge(
                    fraction: WatchSensorDisplay.rangeFraction(value, range: range),
                    valueText: valueText,
                    label: entity.name ?? entity.key,
                    color: .blue
                )
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: spec.icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entity.name ?? entity.key)
                    .font(.caption2)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(valueText + (entity.unit.map { " \($0)" } ?? ""))
                    .font(.caption2.weight(.semibold))
            }
        }
    }
}
