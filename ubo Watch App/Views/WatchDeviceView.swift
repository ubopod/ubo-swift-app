//
//  WatchDeviceView.swift
//  ubo Watch App
//
//  Native watchOS interface for the Ubo Pod
//

import SwiftUI
import UboSwift

struct WatchDeviceView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and nav buttons
            HStack {
                if showBackButton {
                    Button {
                        Task { try? await viewModel.client.goBack() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text(navigationTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                Button {
                    Task { try? await viewModel.client.goHome() }
                } label: {
                    Image(systemName: "house")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Content
            Group {
                switch viewModel.currentView {
                case .home(let data):
                    WatchHomeView(data: data)
                case .menu(let data):
                    WatchMenuView(data: data)
                case .notification(let data):
                    WatchNotificationView(data: data)
                case .application(let data):
                    WatchApplicationView(data: data)
                case .none:
                    loadingView
                }
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.currentView {
        case .home:
            return "Device"
        case .menu(let data):
            return data.title.isEmpty ? "Menu" : String(data.title.prefix(10))
        case .notification:
            return "Alert"
        case .application(let data):
            return String(data.applicationId.prefix(10))
        case .none:
            return "Device"
        }
    }

    private var showBackButton: Bool {
        switch viewModel.currentView {
        case .home:
            return false
        default:
            return true
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Home View

struct WatchHomeView: View {
    let data: HomeViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        List {
            ForEach(data.menuItems, id: \.key) { item in
                Button {
                    Task {
                        // Use key for selection if icon is empty
                        if item.icon.isEmpty {
                            try? await viewModel.client.selectMenuItem(label: displayLabel(for: item))
                        } else {
                            try? await viewModel.client.selectMenuItem(icon: item.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: displayIcon(for: item))
                            .font(.caption)
                            .foregroundStyle(Color(hex: item.color) ?? .accentColor)
                            .frame(width: 20)

                        Text(displayLabel(for: item))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .listStyle(.carousel)
    }

    private func displayLabel(for item: MenuItemData) -> String {
        if !item.label.isEmpty {
            return item.label
        }
        return item.key.prefix(1).uppercased() + item.key.dropFirst()
    }

    private func displayIcon(for item: MenuItemData) -> String {
        let iconSource = item.icon.isEmpty ? item.key : item.icon
        return mapIcon(iconSource)
    }

    private func mapIcon(_ icon: String) -> String {
        switch icon.lowercased() {
        // Key-based mappings
        case "main": return "list.bullet"
        case "notifications": return "bell"
        case "power": return "power"
        // Icon-based mappings
        case "settings", "gear", "󰒓": return "gear"
        case "wifi", "󰖩": return "wifi"
        case "bluetooth", "󰂯": return "bluetooth"
        case "apps", "󰀻": return "square.grid.2x2"
        case "󰐥": return "power"
        case "info", "󰋼": return "info.circle"
        case "update", "󰚰": return "arrow.down.circle"
        case "docker", "󰡨": return "shippingbox"
        case "home", "󰋜": return "house"
        case "lightbulb", "󰌵": return "lightbulb"
        case "camera", "󰄀": return "camera"
        case "microphone", "󰍬": return "mic"
        case "speaker", "󰓃": return "speaker.wave.2"
        case "network", "󰛳": return "network"
        case "ssh", "󰣀": return "terminal"
        case "vpn", "󰖂": return "lock.shield"
        case "bell", "󰂞": return "bell"
        default: return "circle.fill"
        }
    }
}

// MARK: - Menu View

struct WatchMenuView: View {
    let data: MenuViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        List {
            // Heading if present
            if let heading = data.heading, !heading.isEmpty {
                Text(heading)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            // Menu items
            ForEach(data.items.compactMap { $0 }, id: \.key) { item in
                Button {
                    Task {
                        try? await viewModel.client.selectMenuItem(label: item.label)
                    }
                } label: {
                    WatchMenuItemRow(item: item)
                }
            }

            // Pagination controls
            if data.totalPages > 1 {
                HStack {
                    Button {
                        Task { try? await viewModel.client.scrollUp() }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(data.pageIndex == 0)

                    Spacer()

                    Text("\(data.pageIndex + 1)/\(data.totalPages)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        Task { try? await viewModel.client.scrollDown() }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(data.pageIndex >= data.totalPages - 1)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.carousel)
    }
}

struct WatchMenuItemRow: View {
    let item: MenuItemData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mapIcon(item.icon))
                .font(.caption)
                .foregroundStyle(Color(hex: item.color) ?? .accentColor)
                .frame(width: 20)

            Text(item.label)
                .font(.caption)
                .lineLimit(2)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }

    private func mapIcon(_ icon: String) -> String {
        switch icon.lowercased() {
        case "settings", "gear", "󰒓": return "gear"
        case "wifi", "󰖩": return "wifi"
        case "bluetooth", "󰂯": return "bluetooth"
        case "apps", "󰀻": return "square.grid.2x2"
        case "power", "󰐥": return "power"
        case "info", "󰋼": return "info.circle"
        case "update", "󰚰": return "arrow.down.circle"
        case "docker", "󰡨": return "shippingbox"
        case "home", "󰋜": return "house"
        case "check", "checkmark", "󰄬": return "checkmark"
        case "cancel", "close", "󰅖": return "xmark"
        case "back", "󰁍": return "chevron.left"
        case "forward", "󰁔": return "chevron.right"
        case "toggle_on", "󰔡": return "checkmark.circle.fill"
        case "toggle_off", "󰨙": return "circle"
        default: return "circle.fill"
        }
    }
}

// MARK: - Notification View

struct WatchNotificationView: View {
    let data: NotificationViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: mapNotificationIcon(data.icon))
                    .font(.title2)
                    .foregroundStyle(Color(hex: data.color) ?? .accentColor)

                // Title
                Text(data.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                // Content
                Text(data.content)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Action buttons
                if !data.items.isEmpty {
                    ForEach(data.items.compactMap { $0 }, id: \.key) { item in
                        Button {
                            Task {
                                try? await viewModel.client.selectMenuItem(label: item.label)
                            }
                        } label: {
                            Text(item.label)
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Dismiss button
                Button("Dismiss") {
                    Task { try? await viewModel.client.goBack() }
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private func mapNotificationIcon(_ icon: String) -> String {
        switch icon.lowercased() {
        case "info": return "info.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "error": return "xmark.circle.fill"
        case "success": return "checkmark.circle.fill"
        case "update": return "arrow.down.circle.fill"
        default: return "bell.fill"
        }
    }
}

// MARK: - Application View

struct WatchApplicationView: View {
    let data: ApplicationViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "app.fill")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(data.applicationId)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("App running")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            // Navigation controls
            HStack(spacing: 16) {
                Button {
                    Task { try? await viewModel.client.goBack() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.quaternary))
                }
                .buttonStyle(.plain)

                Button {
                    Task { try? await viewModel.client.goHome() }
                } label: {
                    Image(systemName: "house.fill")
                        .font(.caption)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

#Preview {
    WatchDeviceView()
        .environment(DeviceViewModel())
}
