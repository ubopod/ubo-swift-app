//
//  DeviceView.swift
//  ubo-swift-app
//
//  Native iOS interface for the Ubo Pod
//

import SwiftUI
import UboSwift

struct DeviceView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    private var showsStatusBar: Bool {
        viewModel.currentView?.showStatusBar ?? false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsStatusBar {
                    StatusBarOverlay(
                        bar: viewModel.statusBar,
                        cpuPercent: viewModel.cpuPercent,
                        ramPercent: viewModel.ramPercent,
                        temperature: viewModel.temperature
                    )
                }
            Group {
                switch viewModel.currentView {
                case .home(let data):
                    HomeDeviceView(data: data)
                case .menu(let data):
                    MenuDeviceView(data: data)
                case .notification(let data):
                    NotificationDeviceView(data: data)
                case .application(let data):
                    ApplicationDeviceView(data: data)
                case .instruction(let data):
                    InstructionDeviceView(data: data)
                case .prompt(let data):
                    PromptDeviceView(data: data)
                case .render(let data):
                    RenderDeviceView(data: data)
                case .none:
                    loadingView
                }
            }
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if showBackButton {
                        Button {
                            triggerHaptic()
                            Task { try? await viewModel.client.goBack() }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        triggerHaptic()
                        Task { try? await viewModel.client.goHome() }
                    } label: {
                        Image(systemName: "house")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        triggerHaptic()
                        Task { await viewModel.toggleMicCapture() }
                    } label: {
                        Image(systemName: viewModel.micCapture.isRunning ? "mic.fill" : "mic")
                            .foregroundStyle(viewModel.micCapture.isRunning ? Color.red : Color.primary)
                    }
                    .accessibilityLabel(viewModel.micCapture.isRunning ? "Stop microphone" : "Start microphone")
                }
            }
            .sheet(item: Binding(
                get: { viewModel.activeInputs.first },
                set: { _ in /* dismissal goes through provideInput / cancelInput */ }
            )) { description in
                InputFormView(description: description)
                    .environment(viewModel)
            }
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.currentView {
        case .home:
            return "Home"
        case .menu(let data):
            return data.title.isEmpty ? "Menu" : data.title
        case .notification:
            return "Notification"
        case .application(let data):
            return data.applicationId
        case .instruction(let data):
            return data.title.isEmpty ? "Instruction" : data.title
        case .prompt(let data):
            return data.title.isEmpty ? "Prompt" : data.title
        case .render(let data):
            return data.title.isEmpty ? "Render" : data.title
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
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .foregroundStyle(.secondary)
        }
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Home View

struct HomeDeviceView: View {
    let data: HomeViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Menu Items as Cards
                LazyVStack(spacing: 12) {
                    ForEach(data.menuItems, id: \.key) { item in
                        HomeMenuCard(item: item) {
                            triggerHaptic()
                            Task {
                                // Use key/label for selection if icon is empty
                                if item.icon.isEmpty {
                                    let label = item.label.isEmpty
                                        ? item.key.prefix(1).uppercased() + item.key.dropFirst()
                                        : item.label
                                    try? await viewModel.client.selectMenuItem(label: label)
                                } else {
                                    try? await viewModel.client.selectMenuItem(icon: item.icon)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .refreshable {
            try? await viewModel.client.goHome()
        }
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

struct HomeMenuCard: View {
    let item: MenuItemData
    let action: () -> Void

    @State private var isPressed = false

    // Use label if available, otherwise capitalize the key
    private var displayLabel: String {
        if !item.label.isEmpty {
            return item.label
        }
        // Capitalize first letter of key
        return item.key.prefix(1).uppercased() + item.key.dropFirst()
    }

    // Use icon if available, otherwise try to map from key
    private var displayIcon: String {
        let iconSource = item.icon.isEmpty ? item.key : item.icon
        return mapIcon(iconSource)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: displayIcon)
                    .font(.title2)
                    .foregroundStyle(Color(hex: item.color) ?? .accentColor)
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill((Color(hex: item.color) ?? .accentColor).opacity(0.15))
                    }

                // Label
                Text(displayLabel)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
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

struct MenuDeviceView: View {
    let data: MenuViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        List {
            // Heading if present
            if let heading = data.heading, !heading.isEmpty {
                Section {
                    Text(heading)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Menu items
            Section {
                ForEach(data.items.compactMap { $0 }, id: \.key) { item in
                    MenuItemRow(item: item) {
                        triggerHaptic()
                        Task {
                            try? await viewModel.client.selectMenuItem(label: item.label)
                        }
                    }
                }
            }

            // Pagination
            if data.totalPages > 1 {
                Section {
                    HStack {
                        Button {
                            triggerHaptic()
                            Task { try? await viewModel.client.scrollUp() }
                        } label: {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.title2)
                        }
                        .disabled(data.pageIndex == 0)

                        Spacer()

                        Text("Page \(data.pageIndex + 1) of \(data.totalPages)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            triggerHaptic()
                            Task { try? await viewModel.client.scrollDown() }
                        } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.title2)
                        }
                        .disabled(data.pageIndex >= data.totalPages - 1)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .refreshable {
            try? await viewModel.client.requestDisplayRedraw()
        }
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Notification View

struct NotificationDeviceView: View {
    let data: NotificationViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: mapNotificationIcon(data.icon))
                    .font(.system(size: 56))
                    .foregroundStyle(Color(hex: data.color) ?? .accentColor)
                    .padding(.top, 20)

                // Title & Content
                VStack(spacing: 8) {
                    Text(data.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(data.content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Extra information
                if !data.extraInformation.isEmpty {
                    GroupBox {
                        Text(data.extraInformation)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Action buttons
                if !data.items.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(data.items.compactMap { $0 }, id: \.key) { item in
                            Button {
                                triggerHaptic()
                                Task {
                                    try? await viewModel.client.selectMenuItem(label: item.label)
                                }
                            } label: {
                                HStack {
                                    Text(item.label)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.regularMaterial)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Dismiss
                Button("Dismiss") {
                    triggerHaptic()
                    Task { try? await viewModel.client.goBack() }
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
            .padding(.bottom, 32)
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

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Application View

struct ApplicationDeviceView: View {
    let data: ApplicationViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "app.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(data.applicationId)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Application running on device")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            // Navigation controls for apps
            HStack(spacing: 40) {
                ControlButton(icon: "chevron.left", label: "Back") {
                    Task { try? await viewModel.client.goBack() }
                }

                ControlButton(icon: "house", label: "Home") {
                    Task { try? await viewModel.client.goHome() }
                }
            }
            .padding(.bottom, 32)
        }
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            triggerHaptic()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(width: 70, height: 70)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

#Preview {
    DeviceView()
        .environment(DeviceViewModel())
}
