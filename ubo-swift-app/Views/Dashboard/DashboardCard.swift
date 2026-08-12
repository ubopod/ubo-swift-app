//
//  DashboardCard.swift
//  ubo-swift-app
//
//  Shared card chrome for every Dashboard tile, mirroring the Web UI's
//  `DashboardCard`/`Stat` (ubo_app/services/090-web-ui/web-app/src/
//  components/dashboard/DashboardCard.tsx).
//
//  `icon` here is always an SF Symbol name chosen by this app (never a
//  Nerd-Font glyph sent by the device), so it renders via `Image(systemName:)`
//  directly — NOT `IconView`, which is reserved for icons streamed from
//  the core (menu items, Docker apps) and falls back to a plain circle
//  for any string it doesn't recognize as a glyph or semantic key.
//

import SwiftUI

/// The rounded card every Dashboard tile renders inside, with a titled
/// header row (icon + title) and free-form content below.
struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content()
                .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
}

/// A labelled value row, for readings with no meaningful range to meter
/// against. Mirrors the Web UI's `Stat`.
struct DashboardStat: View {
    let label: String
    let value: String
    var unit: String?
    var icon: String?
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            (Text(value).fontWeight(.semibold) + Text(unit.map { " \($0)" } ?? "").font(.caption2))
                .font(.caption)
                .foregroundStyle(valueColor)
        }
    }
}
