//
//  DeviceViewModel.swift
//
//  The single app-facing store shared by every target (iOS/macOS/tvOS app,
//  watchOS app). Owns the `UboClient`, mirrors its Combine publishers into
//  `@Observable` state, and hosts the capture/playback services on the
//  platforms that have the hardware. Platform differences live in `#if os`
//  branches here — never in per-target copies.
//

import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif
import UboSwift
import GRPCNIOTransportHTTP2
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
public final class DeviceViewModel {
    public let client = UboClient()
    // Local capture (camera viewfinder, mic streaming, device-audio playback)
    // exists only on the platforms with the hardware + capture APIs. tvOS has
    // no camera/mic and routes the assistant to the Pi's own mics instead.
    #if os(iOS) || os(macOS)
    public let cameraManager = CameraManager()
    #endif
    #if os(iOS) || os(macOS) || os(watchOS)
    public let micCapture = MicCaptureService()
    public let audioPlayback = AudioPlaybackService()
    #endif

    /// Whether an assistant listening session this client controls is live.
    /// Backs the mic icon — a stored property so `@Observable` re-renders it.
    /// The single gate for every mic entry point (push-to-talk button,
    /// assistant toggle, keyboard shortcut), so they can't desync.
    private(set) var assistantListening = false

    // Observable state - updated from client
    public private(set) var isConnecting: Bool = false
    public private(set) var isConnected: Bool = false
    public private(set) var currentView: ViewData?
    public private(set) var statusBar: StatusBarData?
    public private(set) var lastError: UboError?
    public private(set) var activeInputs: [WebUIInputDescription] = []
    public private(set) var stack: [UboStackItem] = []

    // System stats - continuously updated from stats subscription
    public private(set) var cachedCpuPercent: Float = 0
    public private(set) var cachedRamPercent: Float = 0
    public private(set) var cachedTemperature: Float?
    public private(set) var cachedTemperatureUnit: String?
    public private(set) var cachedPlaybackVolume: Float?
    public private(set) var cachedIsPlaybackMute: Bool?
    public private(set) var cachedIsCaptureMute: Bool?

    /// Full stats snapshot (disk, network, uptime, weather, date, Docker
    /// apps, sensor devices) for the Dashboard tile grid. The flattened
    /// `cached*`/`cpuPercent`/`ramPercent`/`temperature` properties above
    /// stay in place for other call sites (status bars, widgets) that only
    /// need those three scalars.
    public private(set) var cachedStats: SystemStats?

    private var cancellables = Set<AnyCancellable>()
    #if os(iOS) || os(macOS)
    private var cameraObservationTask: Task<Void, Never>?
    private var cameraDetectAdvertiseCancellable: AnyCancellable?
    #endif

    #if os(iOS) || os(macOS)
    /// Stable id under which this device advertises itself as a camera
    /// source to the Pi. Generated once on first launch and persisted; the
    /// Pi uses it to route `CameraStartViewfinderEvent`s and to drop
    /// frames from sources it didn't pick.
    private var cameraSourceId: String {
        if let existing = UserDefaults.standard.string(forKey: "cameraSourceId") {
            return existing
        }
        let new = "remote:\(UUID().uuidString)"
        UserDefaults.standard.set(new, forKey: "cameraSourceId")
        return new
    }

    /// Human-readable label shown in the Pi's camera picker.
    private var cameraSourceLabel: String {
        #if canImport(UIKit)
        let name = UIDevice.current.name
        return name.isEmpty ? "iPhone" : name
        #else
        return "Mac"
        #endif
    }
    #endif

    #if os(iOS) || os(macOS) || os(watchOS)
    /// Stable id identifying this app as a microphone source. Sent on
    /// `startAssistantListening` and on every streamed sample so the core
    /// binds the listening session to this app's mic and ignores the
    /// device's built-in mic (mirrors the Web UI's `web-ui:` audio source).
    /// Generated once on first launch and persisted.
    private var audioSourceId: String {
        if let existing = UserDefaults.standard.string(forKey: "audioSourceId") {
            return existing
        }
        #if os(watchOS)
        let new = "watch:\(UUID().uuidString)"
        #else
        let new = "ios:\(UUID().uuidString)"
        #endif
        UserDefaults.standard.set(new, forKey: "audioSourceId")
        return new
    }
    #endif

    public init() {
        #if os(watchOS)
        // TN3135: Network.framework/BSD sockets on watchOS only work inside
        // an active audio session — outside one, connections silently get
        // routed onto the "prefer companion" path and NECP-denied instead of
        // ever reaching a local-network permission prompt. Every network op
        // this app does (Bonjour discovery on the connect screen, the gRPC
        // connect itself) needs this active before it runs, so it's armed
        // here at view-model construction rather than after a connect
        // attempt (which is too late — the attempt that needed it already
        // failed).
        do {
            try AudioSessionCoordinator.activatePlayback()
        } catch {
            UboLog.audio.error("failed to activate audio session for networking: \(error.localizedDescription)")
        }
        #endif
        // Observe client's published properties. The client publishes on the
        // main actor and this class is @MainActor, so no queue hop is needed.
        client.$connectionState
            .sink { [weak self] state in
                self?.isConnecting = state.isConnecting
                self?.isConnected = state.isConnected
                self?.updateWidgetData()
            }
            .store(in: &cancellables)

        client.$currentView
            .sink { [weak self] view in
                self?.currentView = view
            }
            .store(in: &cancellables)

        client.$statusBar
            .sink { [weak self] bar in
                self?.statusBar = bar
            }
            .store(in: &cancellables)

        client.$lastError
            .sink { [weak self] error in
                self?.lastError = error
            }
            .store(in: &cancellables)

        client.$activeInputs
            .sink { [weak self] inputs in
                self?.activeInputs = inputs
            }
            .store(in: &cancellables)

        client.$stack
            .sink { [weak self] stack in
                self?.stack = stack
            }
            .store(in: &cancellables)

        // Reconcile the local `assistantListening` flag against
        // server-authoritative state: the core can end (silence timeout,
        // mute, stop-talking phrase) or start a session this client didn't
        // itself trigger, and the local button-press flag would otherwise
        // never learn about it. `mySourceId` is computed per-callback since
        // `audioSourceId` isn't available until platforms that generate one
        // have run their `UserDefaults` lookup, and tvOS has none.
        client.$assistantServerListening
            .sink { [weak self] state in
                guard let self, let state else { return }
                #if os(iOS) || os(macOS) || os(watchOS)
                let mySourceId = self.audioSourceId
                #else
                let mySourceId = ""
                #endif
                self.assistantListening = Self.reconciledListening(
                    serverIsListening: state.isListening,
                    serverActiveAudioSource: state.activeAudioSource,
                    mySourceId: mySourceId
                )
            }
            .store(in: &cancellables)

        // Subscribe to system stats for continuous CPU/RAM/temperature updates
        client.$systemStats
            .sink { [weak self] stats in
                if let stats = stats {
                    self?.cachedCpuPercent = stats.cpuPercent
                    self?.cachedRamPercent = stats.ramPercent
                    self?.cachedTemperature = stats.temperatureDisplayValue ?? stats.temperature
                    self?.cachedTemperatureUnit = stats.temperatureDisplayUnit
                    self?.cachedPlaybackVolume = stats.playbackVolume
                    self?.cachedIsPlaybackMute = stats.isPlaybackMute
                    self?.cachedIsCaptureMute = stats.isCaptureMute
                    self?.cachedStats = stats
                    self?.updateWidgetData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu item activation

    /// Prefix the core auto-generates for a SubMenuItem's "push this menu"
    /// action_id (`menu:select:<menuKey>`). These ids are never registered in
    /// the server's action registry — `ExecuteMenuActionAction` can't resolve
    /// them — so they must be turned into a direct `StackPushMenuAction`
    /// client-side instead. Mirrors the Web UI's identical branch in
    /// `action-dispatcher.ts`/`TileGrid.tsx`.
    private static let menuSelectPrefix = "menu:select:"

    /// Activate a selected `MenuItemData` the way the Web UI does: push
    /// directly for `menu:select:*` ids, execute-by-id otherwise (passing
    /// the item's `key` as `menuKey` so handlers that return a submenu still
    /// navigate into it), and fall back to the legacy by-label lookup only
    /// when the server sent no action_id at all. Every UI surface that
    /// renders `MenuItemData` should call this instead of hand-rolling the
    /// branch — see PromptDeviceView's Remove-does-nothing bug for what
    /// skipping the menu:select: case looks like.
    public func selectMenuItem(_ item: MenuItemData) async throws {
        if let actionId = item.actionId, !actionId.isEmpty {
            if actionId.hasPrefix(Self.menuSelectPrefix) {
                try await client.pushMenu(menuKey: String(actionId.dropFirst(Self.menuSelectPrefix.count)))
            } else {
                try await client.executeMenuAction(actionId: actionId, menuKey: item.key)
            }
        } else {
            try await client.selectMenuItem(label: item.label)
        }
    }

    // MARK: - Error surfacing

    /// Run a fire-and-forget UI action, logging failures and surfacing them
    /// via `lastError` instead of silently dropping them. Use this from
    /// views instead of `Task { try? await ... }`.
    public func perform(_ label: String, _ operation: @escaping @Sendable () async throws -> Void) {
        Task { [weak self] in
            do {
                try await operation()
            } catch {
                self?.report(label, error)
            }
        }
    }

    /// Log a failed UI action and surface it via `lastError`. For contexts
    /// that are already async (e.g. `.refreshable`) where `perform` would
    /// detach: `do { try await ... } catch { viewModel.report("x", error) }`.
    public func report(_ label: String, _ error: Error) {
        UboLog.action.error("\(label) failed: \(error.localizedDescription)")
        lastError = (error as? UboError) ?? .dispatchFailed(error)
    }

    // MARK: - Widget data

    /// Last time widget data was updated
    private var lastWidgetUpdate: Date = .distantPast

    /// Update shared data for widgets (throttled)
    private func updateWidgetData() {
        #if os(iOS) || os(macOS)
        let now = Date()
        guard now.timeIntervalSince(lastWidgetUpdate) >= UboConstants.widgetUpdateThrottle else { return }
        lastWidgetUpdate = now

        let sharedStats = SharedSystemStats(
            cpuPercent: cachedCpuPercent,
            ramPercent: cachedRamPercent,
            temperature: cachedTemperature,
            temperatureUnit: cachedTemperatureUnit,
            isConnected: isConnected,
            deviceHost: savedHost
        )
        sharedStats.save()

        // Reload widget timelines
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        #endif
    }

    // MARK: - Persisted settings

    public var savedHost: String {
        get { UserDefaults.standard.string(forKey: "deviceHost") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "deviceHost") }
    }

    public var savedPort: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "devicePort").nonZero
            #if os(watchOS)
            // A watch that connected before this feature shipped has 50053
            // (the old cross-platform default) persisted from
            // `UboConstants.defaultPort`'s previous unconditional value.
            // That port is unreachable from a physical Watch, and no
            // watchOS user could have meaningfully chosen it themselves —
            // it was never surfaced as anything but the invisible default.
            // Treat it the same as unset so those installs pick up the new
            // watchOS default (50052) instead of staying stuck.
            if stored == 50053 { return UboConstants.defaultPort }
            #endif
            return stored ?? UboConstants.defaultPort
        }
        set { UserDefaults.standard.set(newValue, forKey: "devicePort") }
    }

    public var savedUseTLS: Bool {
        get { UserDefaults.standard.bool(forKey: "deviceUseTLS") }
        set { UserDefaults.standard.set(newValue, forKey: "deviceUseTLS") }
    }

    /// Whether the app was connected the last time it was closed —
    /// `true` on a successful `connect()`, `false` on `disconnect()`.
    /// `hasSavedConnection` uses this to auto-connect on launch only if
    /// the user was actually connected last time, not just because
    /// credentials happen to be on file: leaving the app disconnected and
    /// relaunching it should land back on the connect screen, not
    /// silently reconnect underneath the user.
    private var wasConnected: Bool {
        get { UserDefaults.standard.bool(forKey: "deviceWasConnected") }
        set { UserDefaults.standard.set(newValue, forKey: "deviceWasConnected") }
    }

    public var hasSavedConnection: Bool {
        !savedHost.isEmpty && wasConnected
    }

    /// The last 3 distinct (host, port) pairs connected to, most recent
    /// first — lets a user who controls more than one pod switch between
    /// them without re-typing host/port/TLS each time.
    public var recentConnections: [RecentConnection] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "recentConnections"),
                  let decoded = try? JSONDecoder().decode([RecentConnection].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(Array(newValue.prefix(3))) else { return }
            UserDefaults.standard.set(data, forKey: "recentConnections")
        }
    }

    /// Move (or insert) `host:port` to the front of `recentConnections`,
    /// refreshing its TLS setting to whatever was just used, and trims back
    /// down to 3.
    private func recordRecentConnection(host: String, port: Int, useTLS: Bool) {
        var connections = recentConnections
        connections.removeAll { $0.host == host && $0.port == port }
        connections.insert(RecentConnection(host: host, port: port, useTLS: useTLS), at: 0)
        recentConnections = connections
    }

    // MARK: - System stats helpers (cached so stats persist across menus)

    public var cpuPercent: Float {
        cachedCpuPercent
    }

    public var ramPercent: Float {
        cachedRamPercent
    }

    public var temperature: Float? {
        cachedTemperature
    }

    public var temperatureUnit: String? {
        cachedTemperatureUnit
    }

    /// Full stats snapshot for the Dashboard tile grid. `nil` until the
    /// first `SubscribeStore` frame arrives.
    public var stats: SystemStats? {
        cachedStats
    }

    // MARK: - Menu view data helpers

    public var menuTitle: String {
        if case .menu(let data) = currentView {
            return data.title
        }
        return "Menu"
    }

    public var menuItems: [MenuItemData] {
        if case .menu(let data) = currentView {
            return data.items.compactMap { $0 }
        } else if case .home(let data) = currentView {
            return data.menuItems
        }
        return []
    }

    // Notification view data helpers
    public var notification: NotificationViewData? {
        if case .notification(let data) = currentView {
            return data
        }
        return nil
    }

    // MARK: - Connection lifecycle

    public func connect(host: String, port: Int = UboConstants.defaultPort, useTLS: Bool = false) async throws {
        #if os(watchOS)
        // The grpc-web bridge (`GRPCWebClientTransport`) has no TLS
        // listener on the Pi today — fail loudly rather than silently
        // downgrading a user's explicit "Use TLS" toggle to plaintext.
        // Checked before any persistence below, so a rejected attempt
        // doesn't poison `savedUseTLS`/recent-connections with a setting
        // that was never actually honored.
        guard !useTLS else {
            throw UboError.connectionFailed(
                NSError(
                    domain: "Ubo",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "TLS isn't available over the grpc-web bridge yet."]
                )
            )
        }
        #endif
        savedHost = host
        savedPort = port
        savedUseTLS = useTLS
        recordRecentConnection(host: host, port: port, useTLS: useTLS)
        #if os(watchOS)
        try await client.connect(host: host, port: port, security: .plaintext, subscribeToDisplay: false)
        #else
        try await client.connect(
            host: host,
            port: port,
            security: useTLS ? .tls(.defaults) : .plaintext,
            subscribeToDisplay: false
        )
        #endif
        client.startViewSubscription()
        client.startStatsSubscription()
        client.startInputsSubscription()
        client.startStackSubscription()
        client.startAssistantStateSubscription()
        #if os(iOS) || os(macOS)
        client.cameraSourceId = cameraSourceId
        client.startCameraSubscription()
        cameraManager.configure(client: client)
        startCameraObservation()
        startCameraRegistrationListener()
        #endif
        #if os(iOS) || os(macOS) || os(watchOS)
        micCapture.configure(client: client)
        audioPlayback.configure(client: client)
        audioPlayback.start()
        #endif
        wasConnected = true
    }

    public func connectWithSavedSettings() async throws {
        guard !savedHost.isEmpty else { return }
        try await connect(host: savedHost, port: savedPort, useTLS: savedUseTLS)
    }

    public func disconnect() async {
        wasConnected = false
        #if os(iOS) || os(macOS)
        cameraObservationTask?.cancel()
        cameraObservationTask = nil
        cameraDetectAdvertiseCancellable?.cancel()
        cameraDetectAdvertiseCancellable = nil
        cameraManager.stopCamera()
        #endif
        #if os(iOS) || os(macOS) || os(watchOS)
        if assistantListening {
            await stopAssistantSession()
        }
        micCapture.stop()
        audioPlayback.stop()
        #endif
        await client.disconnect()
    }

    // MARK: - Scene phase

    /// Call when the scene leaves the foreground. Stops a live mic session
    /// cleanly (the OS will suspend the audio engine anyway — better to end
    /// the core-side listening session than leave it dangling).
    public func sceneDidEnterBackground() {
        #if os(iOS) || os(macOS) || os(watchOS)
        if assistantListening {
            Task { await stopAssistantSession() }
        }
        #endif
    }

    /// Call when the scene returns to the foreground. Restarts the playback
    /// subscription if its stream died while suspended (start() is a no-op
    /// when it is still running).
    public func sceneDidBecomeActive() {
        #if os(iOS) || os(macOS) || os(watchOS)
        if isConnected {
            audioPlayback.start()
        }
        #endif
    }

    // MARK: - Assistant / mic

    /// Whether an assistant listening session this client controls is active.
    /// On capture-capable platforms that means this client's mic is
    /// streaming; on tvOS it means the Pi's own mics are listening on this
    /// client's behalf.
    public var isAssistantListening: Bool { assistantListening }

    /// Reconciles server-authoritative assistant state against this client's
    /// own source id. `state.assistant.is_listening` is global — a *different*
    /// client's session (or the Pi's own device-routed session, which sends
    /// `active_audio_source == ""`) also sets it `true`, so this must AND it
    /// with a source-id match rather than trusting `isListening` alone.
    /// Pure + static so it's unit-testable without a live `UboClient`.
    nonisolated static func reconciledListening(
        serverIsListening: Bool,
        serverActiveAudioSource: String,
        mySourceId: String
    ) -> Bool {
        serverIsListening && serverActiveAudioSource == mySourceId
    }

    /// Unified mic toggle used by every shell. Capture-capable platforms
    /// (iOS/macOS/watchOS) stream the local mic; tvOS dispatches a
    /// device-routed session with an empty `audio_source`, so the Pi's
    /// built-in mics do the listening.
    public func toggleAssistantListening() async {
        #if os(iOS) || os(macOS) || os(watchOS)
        await toggleMicCapture()
        #else
        if assistantListening {
            UboLog.audio.info("toggleAssistantListening: stopping device session")
            do { try await client.stopAssistantListening() }
            catch { UboLog.audio.error("stopAssistantListening failed: \(error.localizedDescription)") }
            assistantListening = false
        } else {
            UboLog.audio.info("toggleAssistantListening: starting device session (audioSource=<system>)")
            do {
                try await client.startAssistantListening(audioSource: "")
                assistantListening = true
            } catch {
                UboLog.audio.error("startAssistantListening failed: \(error.localizedDescription)")
                lastError = (error as? UboError) ?? .dispatchFailed(error)
            }
        }
        #endif
    }

    #if os(iOS) || os(macOS) || os(watchOS)
    /// Toggle "press to talk" mic capture. Streams PCM16 frames to the
    /// device's assistant pipeline.
    ///
    /// `triggerSource` tells the core how the session was triggered so it can
    /// pick a turn-completion policy. Left `nil` the core applies none and the
    /// pipeline falls back to a short silence window; pass
    /// `.wakePhrase(mode: .quickChat)` to have the device end the turn after
    /// its configured quick-chat silence window instead.
    public func toggleMicCapture(triggerSource: AssistantTriggerSource? = nil) async {
        if assistantListening {
            await stopAssistantSession()
        } else {
            // Same id on the session and every sample, so the core listens to
            // this app's mic and drops the device's built-in mic.
            let source = audioSourceId
            UboLog.audio.info("toggleMicCapture: starting (audioSource=\(source))")
            do {
                try await client.startAssistantListening(
                    audioSource: source,
                    source: triggerSource
                )
                UboLog.audio.info("startAssistantListening dispatched ok")
            } catch {
                UboLog.audio.error("startAssistantListening FAILED: \(error.localizedDescription)")
                lastError = (error as? UboError) ?? .dispatchFailed(error)
                return
            }
            do {
                try await micCapture.start(audioSource: source)
                // Only now — mirrors the reconciliation subscription above:
                // don't claim a live session if the mic engine never
                // actually started, or the core would think a session is
                // running while no audio is flowing.
                assistantListening = true
            } catch {
                UboLog.audio.error("micCapture.start FAILED: \(error.localizedDescription)")
                lastError = (error as? UboError) ?? .dispatchFailed(error)
                do { try await client.stopAssistantListening() }
                catch { UboLog.audio.error("stopAssistantListening (rollback) failed: \(error.localizedDescription)") }
            }
        }
    }

    private func stopAssistantSession() async {
        UboLog.audio.info("assistant session: stopping")
        micCapture.stop()
        do { try await client.stopAssistantListening() }
        catch { UboLog.audio.error("stopAssistantListening failed: \(error.localizedDescription)") }
        assistantListening = false
    }
    #endif

    #if os(iOS) || os(macOS)
    // MARK: - Camera Source Registration

    /// Subscribe to the device's `CameraDetectAdvertiseEvent` stream and
    /// (re-)register this device as a camera source on every yield. The
    /// Pi clears its pending registration buffer at the end of each
    /// detect cycle, so we have to respond on every advertise event to
    /// stay listed.
    private func startCameraRegistrationListener() {
        let id = cameraSourceId
        let label = cameraSourceLabel
        let client = self.client
        cameraDetectAdvertiseCancellable?.cancel()
        cameraDetectAdvertiseCancellable = client.cameraDetectAdvertiseSubject
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task {
                    do { try await client.registerAsCameraSource(id: id, label: label) }
                    catch { UboLog.camera.error("registerAsCameraSource failed: \(error.localizedDescription)") }
                }
            }
    }

    // MARK: - Camera Observation

    private func startCameraObservation() {
        cameraObservationTask?.cancel()
        cameraObservationTask = Task { [weak self] in
            guard let self else { return }

            // Diff against cameraManager.isActive (not a locally-tracked
            // flag): the UI can stop the camera directly (overlay dismiss),
            // which desyncs a local "last seen" flag from reality. start/stop
            // are already idempotent, so re-driving off the real state keeps
            // a repeated `true` emission able to restart a locally-stopped
            // camera.
            for await isActive in self.client.$isCameraViewfinderActive.values {
                guard !Task.isCancelled else { break }
                if isActive {
                    self.cameraManager.startCamera()
                } else {
                    self.cameraManager.stopCamera()
                }
            }
        }
    }
    #endif
}
