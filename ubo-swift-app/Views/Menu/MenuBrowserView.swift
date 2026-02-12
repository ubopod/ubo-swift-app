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

            if let pageInfo = viewModel.menuPageInfo, pageInfo.total > 1 {
                Section {
                    HStack {
                        Button {
                            Task { try? await viewModel.client.scrollUp() }
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(pageInfo.current == 0)

                        Spacer()

                        Text("Page \(pageInfo.current + 1) of \(pageInfo.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            Task { try? await viewModel.client.scrollDown() }
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(pageInfo.current >= pageInfo.total - 1)
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

                    Text(notification.title)
                        .font(.title2.bold())

                    Text(notification.content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Extra information
                if !notification.extraInformation.isEmpty {
                    GroupBox {
                        Text(notification.extraInformation)
                            .font(.caption)
                    }
                    .padding(.horizontal)
                }

                // Action items
                if !notification.items.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(notification.items.compactMap { $0 }, id: \.key) { item in
                            Button {
                                Task {
                                    try? await viewModel.client.selectMenuItem(label: item.label)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: mapMenuIcon(item.icon))
                                    Text(item.label)
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

                // Dismiss button
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
