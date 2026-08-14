//
//  WatchWeatherDateTimePage.swift
//  ubo Watch App
//
//  Page 2 of the watch Dashboard: weather, date, clock.
//

import SwiftUI
import UboSwift

struct WatchWeatherDateTimePage: View {
    let stats: SystemStats

    private var place: String? {
        let parts = [stats.locationCity, stats.locationCountry].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var formattedDate: String? {
        let parts = stats.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let resolved = Calendar.current.date(from: components) else { return nil }
        return resolved.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let weather = stats.weather {
                    HStack(spacing: 6) {
                        Image(systemName: WatchWeatherIcon.symbolName(for: weather.symbolCode))
                            .font(.title3)
                            .symbolRenderingMode(.multicolor)
                        Text("\(Int(weather.temperatureDisplayValue.rounded()))\(weather.temperatureDisplayUnit)")
                            .font(.title3.weight(.semibold))
                    }
                    Text(WatchWeatherIcon.phrase(for: weather.symbolCode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let place {
                        Text(place)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Fetching forecast…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let formattedDate {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !stats.clock.isEmpty {
                    Text(stats.clock)
                        .font(.title2.weight(.semibold).monospacedDigit())
                }
            }
            .padding(.horizontal)
        }
    }
}
