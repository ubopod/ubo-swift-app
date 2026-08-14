//
//  TodaySection.swift
//  ubo-swift-app
//
//  Weather + date + time merged into one card. Previously three separate
//  grid tiles — but SwiftUI's LazyVGrid locks every row's height to its
//  tallest cell, so a short "Time" tile next to a tall "Weather" tile
//  left a large empty gap beneath the short one. Merging into a single
//  card removes the row-height mismatch entirely: the card lays out its
//  own content, not a page-level grid.
//

import SwiftUI
import UboSwift

struct TodaySection: View {
    let weather: WeatherCondition?
    let locationCity: String?
    let locationCountry: String?
    /// "YYYY-MM-DD"
    let date: String
    /// "HH:MM", 24h.
    let clock: String

    private var place: String? {
        let parts = [locationCity, locationCountry].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var formattedDate: String? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let resolved = Calendar.current.date(from: components) else { return nil }
        return resolved.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var body: some View {
        DashboardCard(title: "Today", icon: "calendar") {
            HStack(alignment: .top, spacing: 16) {
                weatherColumn
                    .frame(maxWidth: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if let formattedDate {
                        Label(formattedDate, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !clock.isEmpty {
                        Text(clock)
                            .font(.title2.weight(.semibold).monospacedDigit())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var weatherColumn: some View {
        if let weather {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: WeatherIcon.symbolName(for: weather.symbolCode))
                        .font(.system(size: 28))
                        .symbolRenderingMode(.multicolor)
                    Text("\(Int(weather.temperatureDisplayValue.rounded()))\(weather.temperatureDisplayUnit)")
                        .font(.title2.weight(.semibold))
                }
                Text(WeatherIcon.phrase(for: weather.symbolCode))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let place {
                    Text(place)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            Text(locationCity == nil ? "Location not detected yet" : "Fetching forecast…")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
