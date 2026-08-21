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
                    ForEach(Self.chunkEntities(device.entities)) { chunk in
                        switch chunk {
                        case .gaugeRun(let entities):
                            gaugeRow(entities)
                        case .plain(let entity):
                            entityRow(entity)
                        }
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

    private static func isGaugeEligible(_ entity: SensorEntityReading) -> Bool {
        let spec = WatchSensorDisplay.spec(forKey: entity.key, deviceClass: entity.deviceClass)
        return spec.range != nil && entity.value != nil
    }

    private enum EntityChunk: Identifiable {
        case gaugeRun([SensorEntityReading])
        case plain(SensorEntityReading)

        var id: String {
            switch self {
            case .gaugeRun(let entities): return "gauge-" + entities.map(\.id).joined(separator: "-")
            case .plain(let entity): return "plain-" + entity.id
            }
        }
    }

    /// Groups consecutive gauge-eligible entities into runs of up to 3
    /// (mirrors the System page's CPU/RAM/Storage row), interspersed with
    /// the non-gauge entities rendered individually in their original
    /// order — e.g. ENS160's eCO2/TVOC/Air Quality Index become one 3-up
    /// gauge row instead of falling back to plain label/value rows,
    /// matching the Web UI's card layout.
    private static func chunkEntities(_ entities: [SensorEntityReading]) -> [EntityChunk] {
        var chunks: [EntityChunk] = []
        var i = 0
        while i < entities.count {
            if isGaugeEligible(entities[i]) {
                var run: [SensorEntityReading] = []
                while i < entities.count, run.count < 3, isGaugeEligible(entities[i]) {
                    run.append(entities[i])
                    i += 1
                }
                chunks.append(.gaugeRun(run))
            } else {
                chunks.append(.plain(entities[i]))
                i += 1
            }
        }
        return chunks
    }

    @ViewBuilder
    private func gaugeRow(_ entities: [SensorEntityReading]) -> some View {
        HStack(spacing: 6) {
            ForEach(entities) { entity in
                let spec = WatchSensorDisplay.spec(forKey: entity.key, deviceClass: entity.deviceClass)
                if let range = spec.range, let value = entity.value {
                    WatchCompactGauge(
                        fraction: WatchSensorDisplay.rangeFraction(value, range: range),
                        valueText: WatchSensorDisplay.reading(entity.displayValue ?? entity.value, precision: entity.precision),
                        label: entity.name ?? entity.key,
                        color: .blue,
                        // Server-driven — never hardcode a unit here.
                        unit: entity.displayUnit ?? entity.unit
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func entityRow(_ entity: SensorEntityReading) -> some View {
        let spec = WatchSensorDisplay.spec(forKey: entity.key, deviceClass: entity.deviceClass)
        let valueText = WatchSensorDisplay.reading(entity.displayValue ?? entity.value, precision: entity.precision)

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
