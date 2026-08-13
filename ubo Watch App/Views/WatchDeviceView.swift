//
//  WatchDeviceView.swift
//  ubo Watch App
//
//  Native watchOS interface for the Ubo Pod
//

import UboAppKit
import SwiftUI
import UboSwift

struct WatchDeviceView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    /// IDs of input demands the user already resolved on this client.
    /// Filters them out of the sheet binding so the form doesn't
    /// re-present while the server's state update is in flight.
    @State private var dismissedInputIds: Set<String> = []

    private var showsStatusBar: Bool {
        viewModel.currentView?.showStatusBar ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsStatusBar {
                WatchStatusBarOverlay(
                    bar: viewModel.statusBar,
                    cpuPercent: viewModel.cpuPercent,
                    ramPercent: viewModel.ramPercent,
                    temperature: viewModel.temperature
                )
            }
            // Header with title and nav buttons
            HStack {
                if showBackButton {
                    Button {
                        viewModel.perform("goBack") { try await viewModel.client.goBack() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                let titleSplit = splitLeadingGlyph(navigationTitle)
                HStack(spacing: 3) {
                    if let glyph = titleSplit.icon {
                        IconView(icon: glyph, size: 11)
                    }
                    markupText(titleSplit.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    viewModel.perform("goHome") { try await viewModel.client.goHome() }
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
                case .instruction(let data):
                    WatchInstructionView(data: data)
                case .prompt(let data):
                    WatchPromptView(data: data)
                case .render(let data):
                    WatchRenderView(data: data)
                case .chat(let data):
                    WatchChatView(data: data)
                case .none:
                    loadingView
                }
            }
        }
        .sheet(item: Binding<WebUIInputDescription?>(
            get: {
                viewModel.activeInputs.first { !dismissedInputIds.contains($0.id) }
            },
            set: { _ in /* dismissal driven by onClose + server state */ }
        )) { description in
            WatchInputFormView(description: description) {
                dismissedInputIds.insert(description.id)
            }
            .environment(viewModel)
        }
        .onChange(of: viewModel.activeInputs.map(\.id)) { _, ids in
            dismissedInputIds.formIntersection(ids)
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
        case .instruction(let data):
            return data.title.isEmpty ? "Wait" : String(data.title.prefix(10))
        case .prompt(let data):
            return data.title.isEmpty ? "Prompt" : String(data.title.prefix(10))
        case .render(let data):
            return data.title.isEmpty ? "Render" : String(data.title.prefix(10))
        case .chat:
            return "Chat"
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
                        do {
                            if item.actionId?.isEmpty == false {
                                try await viewModel.selectMenuItem(item)
                            } else if item.icon.isEmpty {
                                // Use key for selection if icon is empty
                                try await viewModel.client.selectMenuItem(label: displayLabel(for: item))
                            } else {
                                try await viewModel.client.selectMenuItem(icon: item.icon)
                            }
                        } catch { viewModel.report("selectMenuItem", error) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        IconView(
                            icon: item.icon.isEmpty ? item.key : item.icon,
                            size: 14,
                            color: uboIconColor(forHex: item.color, fallback: .accentColor)
                        )
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
        return UboSymbolMapper.systemName(for: iconSource)
    }

    
}

// MARK: - Menu View

struct WatchMenuView: View {
    let data: MenuViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        List {
            // Heading + sub-heading (HeadedMenu). Web UI renders both above
            // its tile grid; we keep the same stack on the watch, sized
            // for the smaller screen.
            if (data.heading?.isEmpty == false) || (data.subHeading?.isEmpty == false) {
                VStack(alignment: .leading, spacing: 1) {
                    if let heading = data.heading, !heading.isEmpty {
                        markupText(heading)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let subHeading = data.subHeading, !subHeading.isEmpty {
                        markupText(subHeading)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Menu items — render the full list. page_index /
            // total_pages are GUI-client concerns; the watch
            // scrolls natively.
            ForEach(data.items.compactMap { $0 }, id: \.key) { item in
                Button {
                    Task {
                        do { try await viewModel.selectMenuItem(item) } catch { viewModel.report("selectMenuItem", error) }
                    }
                } label: {
                    WatchMenuItemRow(item: item)
                }
            }
        }
        .listStyle(.carousel)
    }
}

struct WatchMenuItemRow: View {
    let item: MenuItemData

    var body: some View {
        HStack(spacing: 8) {
            IconView(
                icon: item.icon,
                size: 14,
                color: uboIconColor(forHex: item.color, fallback: .accentColor)
            )
            .frame(width: 20)

            markupText(item.label)
                .font(.caption)
                .lineLimit(2)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
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
                markupText(data.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                // Content
                markupText(data.content)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Split items the way the Web UI does — dismiss / extra_info
                // shouldn't show up as full-width buttons.
                let partitioned = partitionNotificationItems(data.items)

                if let extra = partitioned.extraInfo {
                    Button {
                        Task {
                            do { try await viewModel.selectMenuItem(extra) } catch { viewModel.report("selectMenuItem", error) }
                        }
                    } label: {
                        Label("Read Aloud", systemImage: "speaker.wave.2.circle.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }

                if !partitioned.mainActions.isEmpty {
                    ForEach(partitioned.mainActions, id: \.key) { item in
                        Button {
                            Task {
                                do { try await viewModel.selectMenuItem(item) } catch { viewModel.report("selectMenuItem", error) }
                            }
                        } label: {
                            markupText(item.label)
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Dismiss footer — only shown when the device offered one or
                // when there's nothing else to interact with.
                if partitioned.hasDismiss || partitioned.mainActions.isEmpty {
                    Button("Dismiss") {
                        viewModel.perform("goBack") { try await viewModel.client.goBack() }
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
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
                    viewModel.perform("goBack") { try await viewModel.client.goBack() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.quaternary))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.perform("goHome") { try await viewModel.client.goHome() }
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
