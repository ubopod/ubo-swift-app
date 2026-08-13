//
//  TileShellView.swift
//  ubo-swift-app
//
//  The focus-driven "10-foot / desktop" shell used on Apple TV and macOS,
//  mirroring the Web UI: a status bar, a title/back row + on-screen keypad,
//  and a focusable tile grid for menus. Directional input moves a local
//  focus ring (SwiftUI's focus engine); only the resulting actions cross
//  gRPC to the core — focus state is never sent back.
//

#if os(tvOS) || os(macOS)
import UboAppKit
import SwiftUI
import UboSwift

/// Focus targets for the desktop/TV shell: the control-bar buttons and each
/// menu tile (by key). A single `@State` value is the source of truth so the
/// highlight renders identically whether arrows (macOS) or the Siri Remote
/// (tvOS) moved it — mirroring the Web UI's local `focusIndex`.
enum ShellFocus: Hashable {
    case back, home, mic
    case tile(String)
}

struct TileShellView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    /// Inputs the user already resolved on this client, filtered out of the
    /// form presentation while the server's state update is in flight.
    @State private var dismissedInputIds: Set<String> = []

    /// The currently highlighted element. Driven entirely by our own key /
    /// move handlers — macOS `Button`s aren't focusable by default, so we
    /// never rely on per-element `@FocusState`.
    @State private var focused: ShellFocus?

    /// Keeps the shell as the key window's first responder so `.onKeyPress` /
    /// `.onMoveCommand` fire.
    @FocusState private var shellFocused: Bool

    /// True while the `v` push-to-talk key is held, to ignore key auto-repeat.
    @State private var pushToTalkActive = false

    private enum Dir { case up, down, left, right }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.currentView?.showStatusBar ?? false {
                StatusBarOverlay(
                    bar: viewModel.statusBar,
                    cpuPercent: viewModel.cpuPercent,
                    ramPercent: viewModel.ramPercent,
                    temperature: viewModel.temperature
                )
            }

            ShellControlBar(title: title, showsBack: showsBack, focused: focused)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($shellFocused)
        #if os(macOS)
        // Esc and forward-Delete reach `.onKeyPress`; plain Backspace is
        // swallowed by AppKit (deleteBackward:) before it gets here, so it's
        // handled by an NSEvent monitor below.
        .onKeyPress(keys: [.escape, .deleteForward]) { _ in
            goBack()
            return .handled
        }
        // Hold "v" to talk to the assistant; release to stop (push-to-talk).
        .onKeyPress(keys: ["v", "V"], phases: [.down, .up]) { press in
            handlePushToTalk(press.phase)
            return .handled
        }
        .onKeyPress { handleKey($0) }
        .modifier(BackspaceBackHandler(onBack: goBack))
        #elseif os(tvOS)
        .onMoveCommand { handleMove($0) }
        .onExitCommand { dispatch { try await viewModel.client.goBack() } }
        .onTapGesture { activate() }
        #endif
        .onAppear {
            shellFocused = true
            ensureFocus()
        }
        .onChange(of: tileKeys) { _, _ in ensureFocus() }
        .modifier(InputFormPresenter(dismissedInputIds: $dismissedInputIds))
        #if os(macOS)
        // The Pi can ask a connected client to act as a camera; macOS streams
        // its webcam through the same CameraManager the iPhone uses.
        .sheet(isPresented: Binding(
            get: { viewModel.cameraManager.isActive },
            set: { if !$0 { viewModel.cameraManager.stopCamera() } }
        )) {
            CameraOverlayView(
                cameraManager: viewModel.cameraManager,
                pattern: viewModel.client.cameraPattern,
                onDismiss: { viewModel.cameraManager.stopCamera() }
            )
            .frame(minWidth: 480, minHeight: 520)
        }
        #endif
    }

    @ViewBuilder private var content: some View {
        switch viewModel.currentView {
        case .home(let data):
            TileGridView(items: data.menuItems, focused: focused, onSelect: activateItem)
        case .menu(let data):
            TileGridView(
                items: data.items.compactMap { $0 },
                heading: data.heading,
                subHeading: data.subHeading,
                focused: focused,
                onSelect: activateItem
            )
        default:
            StandardViewContent(view: viewModel.currentView)
        }
    }

    private var title: String {
        viewModel.currentView.uboTitle
    }

    private var showsBack: Bool {
        viewModel.currentView.uboShowsBack
    }

    // MARK: - Focusable model

    private var tileItems: [MenuItemData] {
        switch viewModel.currentView {
        case .home(let d): return d.menuItems
        case .menu(let d): return d.items.compactMap { $0 }
        default: return []
        }
    }

    private var tileKeys: [String] { tileItems.map(\.key) }

    private var columnCount: Int {
        switch tileItems.count {
        case 0, 1: return 1
        case 2, 3, 4: return 2
        default: return 3
        }
    }

    private var controlOrder: [ShellFocus] {
        (showsBack ? [.back] : []) + [.home, .mic]
    }

    private func defaultFocus() -> ShellFocus? {
        // No `.home` fallback: when the grid is momentarily empty (before menu
        // data arrives) this returns nil, and `onChange(tileKeys)` re-anchors
        // to the first tile once it loads — otherwise focus sticks on the bar.
        tileItems.first.map { .tile($0.key) }
    }

    /// Re-anchor focus when the view changes or the current target vanished.
    private func ensureFocus() {
        switch focused {
        case .tile(let key) where tileKeys.contains(key):
            break
        case .back, .home, .mic:
            break
        default:
            focused = defaultFocus()
        }
    }

    private func move(_ dir: Dir) {
        guard let current = focused else { focused = defaultFocus(); return }
        switch current {
        case .tile(let key):
            guard let idx = tileItems.firstIndex(where: { $0.key == key }) else {
                focused = defaultFocus(); return
            }
            let cols = columnCount
            switch dir {
            case .left:  if idx > 0 { focused = .tile(tileItems[idx - 1].key) }
            case .right: if idx < tileItems.count - 1 { focused = .tile(tileItems[idx + 1].key) }
            case .up:
                if idx - cols >= 0 { focused = .tile(tileItems[idx - cols].key) }
                else { focused = .home }                       // step up into the bar
            case .down:
                if idx + cols < tileItems.count { focused = .tile(tileItems[idx + cols].key) }
            }
        case .back, .home, .mic:
            guard let ci = controlOrder.firstIndex(of: current) else { focused = defaultFocus(); return }
            switch dir {
            case .left:  if ci > 0 { focused = controlOrder[ci - 1] }
            case .right: if ci < controlOrder.count - 1 { focused = controlOrder[ci + 1] }
            case .down:  focused = tileItems.first.map { .tile($0.key) } ?? current
            case .up:    break
            }
        }
    }

    private func activate() {
        guard let current = focused else { return }
        switch current {
        case .tile(let key):
            if let item = tileItems.first(where: { $0.key == key }) { activateItem(item) }
        case .back: dispatch { try await viewModel.client.goBack() }
        case .home: dispatch { try await viewModel.client.goHome() }
        case .mic:  Task { await viewModel.toggleAssistantListening() }
        }
    }

    private func activateItem(_ item: MenuItemData) {
        let label = item.label.isEmpty
            ? item.key.prefix(1).uppercased() + item.key.dropFirst()
            : item.label
        dispatch {
            if item.actionId?.isEmpty == false {
                try await viewModel.selectMenuItem(item)
            } else if item.icon.isEmpty {
                try await viewModel.client.selectMenuItem(label: label)
            } else {
                try await viewModel.client.selectMenuItem(icon: item.icon)
            }
        }
    }

    private func goBack() { dispatch { try await viewModel.client.goBack() } }

    /// Fire-and-forget dispatch helper so call sites stay one line.
    private func dispatch(_ work: @escaping @Sendable () async throws -> Void) {
        viewModel.perform("shell action", work)
    }

    #if os(macOS)
    /// Push-to-talk: start the assistant on key-down, stop on key-up. The flag
    /// ignores key auto-repeat so a held key doesn't toggle repeatedly.
    private func handlePushToTalk(_ phase: KeyPress.Phases) {
        if phase.contains(.down) {
            if !pushToTalkActive {
                pushToTalkActive = true
                if !viewModel.isAssistantListening {
                    Task { await viewModel.toggleAssistantListening() }
                }
            }
        } else if phase.contains(.up) {
            if pushToTalkActive {
                pushToTalkActive = false
                if viewModel.isAssistantListening {
                    Task { await viewModel.toggleAssistantListening() }
                }
            }
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow:  move(.left);  return .handled
        case .rightArrow: move(.right); return .handled
        case .upArrow:    move(.up);    return .handled
        case .downArrow:  move(.down);  return .handled
        case .return, .space: activate(); return .handled
        default:
            switch press.characters {
            case "h", "H": dispatch { try await viewModel.client.goHome() }; return .handled
            case "m", "M": dispatch { try await viewModel.client.toggleMute(device: .input) }; return .handled
            default: return .ignored
            }
        }
    }
    #endif

    #if os(tvOS)
    private func handleMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up: move(.up)
        case .down: move(.down)
        case .left: move(.left)
        case .right: move(.right)
        @unknown default: break
        }
    }
    #endif
}

/// Presents the first unresolved input form. On macOS this is a native sheet
/// (keyboard entry); on tvOS the QR hand-off (Phase 5) replaces it.
private struct InputFormPresenter: ViewModifier {
    @Environment(DeviceViewModel.self) private var viewModel
    @Binding var dismissedInputIds: Set<String>

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .sheet(item: Binding<WebUIInputDescription?>(
                get: { viewModel.activeInputs.first { !dismissedInputIds.contains($0.id) } },
                set: { _ in }
            )) { description in
                InputFormView(description: description) {
                    dismissedInputIds.insert(description.id)
                }
                .environment(viewModel)
                .frame(minWidth: 420, minHeight: 320)
            }
            .onChange(of: viewModel.activeInputs.map(\.id)) { _, ids in
                dismissedInputIds.formIntersection(ids)
            }
        #else
        // tvOS has no keyboard: hand the demand to a phone via a QR deeplink.
        content
            .sheet(item: Binding<WebUIInputDescription?>(
                get: { viewModel.activeInputs.first { !dismissedInputIds.contains($0.id) } },
                set: { _ in }
            )) { description in
                TVInputQRView(description: description) {
                    dismissedInputIds.insert(description.id)
                }
                .environment(viewModel)
            }
            .onChange(of: viewModel.activeInputs.map(\.id)) { _, ids in
                dismissedInputIds.formIntersection(ids)
            }
        #endif
    }
}

#if os(tvOS)
/// The on-TV text-input hand-off: a QR encoding `ubo://input?…` (this TV's
/// connection + the pending input id) plus a focusable Cancel. Scanning it
/// with the iPhone opens the form there; submitting clears `active_inputs`
/// for every client, so this sheet dismisses itself.
private struct TVInputQRView: View {
    @Environment(DeviceViewModel.self) private var viewModel
    let description: WebUIInputDescription
    let onCancel: () -> Void

    @FocusState private var cancelFocused: Bool

    private var deeplink: URL? {
        UboDeeplink.inputURL(
            host: viewModel.savedHost,
            port: viewModel.savedPort,
            useTLS: viewModel.savedUseTLS,
            inputId: description.id
        )
    }

    var body: some View {
        VStack(spacing: 28) {
            if let title = description.title, !title.isEmpty {
                Text(title).font(.largeTitle.bold())
            }
            if let prompt = description.prompt, !prompt.isEmpty {
                Text(prompt)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let deeplink, let qr = QRCodeImage.generate(from: deeplink.absoluteString) {
                qr
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 320, height: 320)
                    .padding(24)
                    .background(.white)
                    .cornerRadius(16)
                Text("Scan with your iPhone to type")
                    .font(.headline)
            } else {
                Text("Open the Ubo app on your iPhone to enter this input.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Button("Cancel", role: .cancel) {
                viewModel.perform("cancelInput") { try await viewModel.client.cancelInput(id: description.id) }
                onCancel()
            }
            .focused($cancelFocused)
        }
        .padding(60)
        .onAppear { cancelFocused = true }
    }
}
#endif

#if os(macOS)
import AppKit

/// Plain Backspace (keyCode 51) never reaches SwiftUI's `.onKeyPress` in a
/// non-text context — AppKit consumes it as `deleteBackward:`. A local
/// NSEvent monitor intercepts it first and maps it to "back", while leaving
/// it alone whenever a text field is editing (so typing still deletes).
private struct BackspaceBackHandler: ViewModifier {
    let onBack: () -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 51,
                       !(NSApp.keyWindow?.firstResponder is NSTextView) {
                        onBack()
                        return nil  // consume — don't beep
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}
#endif
#endif
