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
        // scrollDisabled — see the comment on WatchSystemPage's body for
        // why: neither ScrollView nor List hands boundary overscroll off
        // to the enclosing TabView(.verticalPage) once content overflows,
        // making Device/Actions unreachable by swipe. This is the page
        // that made the bug visible in practice: a device with several
        // entities is exactly the case that reliably overflows. The Crown
        // still scrolls this natively without touch.
        List {
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
            .listRowBackground(Color.clear)
        }
        .listStyle(.carousel)
        .scrollDisabled(true)
    }

    @ViewBuilder
    private func entityRow(_ entity: SensorEntityReading) -> some View {
        let spec = WatchSensorDisplay.spec(forKey: entity.key, deviceClass: entity.deviceClass)
        let valueText = WatchSensorDisplay.reading(entity.displayValue ?? entity.value, precision: entity.precision)

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
                Text(valueText + ((entity.displayUnit ?? entity.unit).map { " \($0)" } ?? ""))
                    .font(.caption2.weight(.semibold))
            }
        }
    }
}
