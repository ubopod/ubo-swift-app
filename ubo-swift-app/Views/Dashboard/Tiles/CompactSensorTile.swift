//
//  CompactSensorTile.swift
//  ubo-swift-app
//
//  A small square tile for a sensor device that reports exactly one
//  reading (e.g. an ambient-light or single-temperature sensor). Giving
//  each of these its own full-width `DashboardCard` wasted most of the
//  card's width on nothing; grouped instead into a row of up to four,
//  matching multi-reading devices' density. Fixed height so a row of
//  tiles always aligns — the earlier full-grid layout's dead-space bug
//  came from letting the grid guess at wildly varying tile heights.
//

import SwiftUI
import UboSwift

struct CompactSensorTile: View {
    let label: String
    let entity: SensorEntityReading

    private static let tileHeight: CGFloat = 100

    var body: some View {
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
                .frame(width: 48, height: 48)
            } else {
                Image(systemName: spec.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(valueText)
                    .font(.title3.weight(.semibold))
                if let unit = entity.unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(height: Self.tileHeight)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
}
