//
//  MenuBrowserView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct MenuBrowserView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Group {
                if let notification = viewModel.notification {
                    notificationView(notification)
                } else {
                    menuListView
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Task {
                            try? await viewModel.client.goBack()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            try? await viewModel.client.goHome()
                        }
                    } label: {
                        Image(systemName: "house")
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        if viewModel.notification != nil {
            return "Notification"
        }
        return viewModel.menuTitle
    }

    private var menuListView: some View {
        List {
            ForEach(viewModel.menuItems, id: \.key) { item in
                MenuItemRow(item: item) {
                    Task {
                        try? await viewModel.client.selectMenuItem(label: item.label)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .refreshable {
            // Request a display redraw to refresh the menu
            try? await viewModel.client.requestDisplayRedraw()
        }
    }

    private func notificationView(_ notification: NotificationViewData) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Icon and Title
                VStack(spacing: 12) {
                    Image(systemName: mapNotificationIcon(notification.icon))
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: notification.color) ?? .accentColor)

                    markupText(notification.title)
                        .font(.title2.bold())

                    markupText(notification.content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Items partitioned the way the Web UI does — dismiss /
                // extra_info are special, the rest are action buttons.
                let partitioned = partitionNotificationItems(notification.items)

                // Extra information (paired with the optional "read aloud"
                // accent button when the device sent an `extra_info` item).
                if !notification.extraInformation.isEmpty {
                    GroupBox {
                        HStack(alignment: .top, spacing: 8) {
                            markupText(notification.extraInformation)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let action = partitioned.extraInfo {
                                Button {
                                    Task {
                                        try? await viewModel.client.selectMenuItem(label: action.label)
                                    }
                                } label: {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Action buttons (dismiss / extra_info already filtered out).
                if !partitioned.mainActions.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(partitioned.mainActions, id: \.key) { item in
                            Button {
                                Task {
                                    try? await viewModel.client.selectMenuItem(label: item.label)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: mapMenuIcon(item.icon))
                                    markupText(item.label)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.regularMaterial)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Dismiss footer — always offered when a corresponding
                // `dismiss` item was sent, or when there are no main actions
                // (so the user always has a way out).
                if partitioned.hasDismiss || partitioned.mainActions.isEmpty {
                    Button("Dismiss") {
                        Task {
                            try? await viewModel.client.goBack()
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
            }
        }
    }

    private func mapNotificationIcon(_ icon: String) -> String {
        switch icon.lowercased() {
        case "info": return "info.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "error": return "xmark.circle.fill"
        case "success": return "checkmark.circle.fill"
        case "update": return "arrow.down.circle.fill"
        case "wifi": return "wifi"
        case "bluetooth": return "bluetooth"
        default: return "bell.fill"
        }
    }

    private func mapMenuIcon(_ icon: String) -> String {
        switch icon.lowercased() {
        case "settings", "gear": return "gear"
        case "wifi": return "wifi"
        case "bluetooth": return "bluetooth"
        case "apps": return "square.grid.2x2"
        case "power": return "power"
        case "info": return "info.circle"
        case "update": return "arrow.down.circle"
        case "back": return "chevron.left"
        case "home": return "house"
        case "checkmark": return "checkmark.circle"
        case "cancel", "close": return "xmark.circle"
        default: return "circle.fill"
        }
    }
}

#Preview {
    MenuBrowserView()
        .environment(DeviceViewModel())
}
