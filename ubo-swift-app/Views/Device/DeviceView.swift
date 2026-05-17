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

    /// IDs of input demands the user already resolved (Cancel/Submit) on
    /// this client. Filters them out of the sheet binding so the form
    /// doesn't re-present while the server's state update is in flight.
    @State private var dismissedInputIds: Set<String> = []

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
            .navigationTitle(splitLeadingGlyph(navigationTitle).label)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    let split = splitLeadingGlyph(navigationTitle)
                    HStack(spacing: 4) {
                        if let glyph = split.icon {
                            IconView(icon: glyph, size: 16)
                        }
                        markupText(split.label)
                            .font(.headline)
                    }
                }
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
            .sheet(item: Binding<WebUIInputDescription?>(
                get: {
                    viewModel.activeInputs.first { !dismissedInputIds.contains($0.id) }
                },
                set: { _ in /* dismissal driven by onClose + server state */ }
            )) { description in
                InputFormView(description: description) {
                    dismissedInputIds.insert(description.id)
                }
                .environment(viewModel)
            }
            .onChange(of: viewModel.activeInputs.map(\.id)) { _, ids in
                // Drop dismissals for inputs the server has already resolved
                // so future demands with new ids are presented again.
                dismissedInputIds.formIntersection(ids)
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

    // Pick the original glyph if any, otherwise the menu key as a
    // semantic fallback. IconView handles the Nerd-Font-vs-SF-Symbol
    // dispatch internally.
    private var displayIcon: String {
        item.icon.isEmpty ? item.key : item.icon
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                IconView(
                    icon: displayIcon,
                    size: 24,
                    color: uboIconColor(forHex: item.color, fallback: .accentColor)
                )
                .frame(width: 44, height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(uboIconColor(forHex: item.color, fallback: .accentColor).opacity(0.15))
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
            // Heading + sub-heading (HeadedMenu) — Web UI renders both in
            // its tile grid; the GUI client paints them as a stacked
            // header. We mirror the same hierarchy here.
            if (data.heading?.isEmpty == false) || (data.subHeading?.isEmpty == false) {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        if let heading = data.heading, !heading.isEmpty {
                            markupText(heading)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let subHeading = data.subHeading, !subHeading.isEmpty {
                            markupText(subHeading)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // Menu items — render the full list. The Python core's
            // page_index/total_pages are GUI-client-only concerns
            // (small fixed display); on touch devices the user
            // scrolls natively.
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
                    markupText(data.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    markupText(data.content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Web UI parity: split items into main / extra_info / dismiss.
                let partitioned = partitionNotificationItems(data.items)

                // Extra information (paired with the optional `extra_info`
                // accent button if one was sent).
                if !data.extraInformation.isEmpty {
                    GroupBox {
                        HStack(alignment: .top, spacing: 8) {
                            markupText(data.extraInformation)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let action = partitioned.extraInfo {
                                Button {
                                    triggerHaptic()
                                    Task {
                                        try? await viewModel.client.selectMenuItem(label: action.label)
                                    }
                                } label: {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .font(.title2)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Action buttons (dismiss / extra_info already filtered out).
                if !partitioned.mainActions.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(partitioned.mainActions, id: \.key) { item in
                            Button {
                                triggerHaptic()
                                Task {
                                    try? await viewModel.client.selectMenuItem(label: item.label)
                                }
                            } label: {
                                HStack {
                                    markupText(item.label)
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

                // Dismiss footer (only offered when the device sent a
                // dismiss item or there's nothing else actionable).
                if partitioned.hasDismiss || partitioned.mainActions.isEmpty {
                    Button("Dismiss") {
                        triggerHaptic()
                        Task { try? await viewModel.client.goBack() }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
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
