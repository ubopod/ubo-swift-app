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
    public private(set) var cachedPlaybackVolume: Float?
    public private(set) var cachedIsPlaybackMute: Bool?
    public private(set) var cachedIsCaptureMute: Bool?

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

        // Subscribe to system stats for continuous CPU/RAM/temperature updates
        client.$systemStats
            .sink { [weak self] stats in
                if let stats = stats {
                    self?.cachedCpuPercent = stats.cpuPercent
                    self?.cachedRamPercent = stats.ramPercent
                    self?.cachedTemperature = stats.temperature
                    self?.cachedPlaybackVolume = stats.playbackVolume
                    self?.cachedIsPlaybackMute = stats.isPlaybackMute
                    self?.cachedIsCaptureMute = stats.isCaptureMute
                    self?.updateWidgetData()
                }
            }
            .store(in: &cancellables)
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
        get { UserDefaults.standard.integer(forKey: "devicePort").nonZero ?? UboConstants.defaultPort }
        set { UserDefaults.standard.set(newValue, forKey: "devicePort") }
    }

    public var savedUseTLS: Bool {
        get { UserDefaults.standard.bool(forKey: "deviceUseTLS") }
        set { UserDefaults.standard.set(newValue, forKey: "deviceUseTLS") }
    }

    public var hasSavedConnection: Bool {
        !savedHost.isEmpty
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
        savedHost = host
        savedPort = port
        savedUseTLS = useTLS
        try await client.connect(
            host: host,
            port: port,
            security: useTLS ? .tls(.defaults) : .plaintext,
            subscribeToDisplay: false
        )
        client.startViewSubscription()
        client.startStatsSubscription()
        client.startInputsSubscription()
        client.startStackSubscription()
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
    }

    public func connectWithSavedSettings() async throws {
        guard !savedHost.isEmpty else { return }
        try await connect(host: savedHost, port: savedPort, useTLS: savedUseTLS)
    }

    public func disconnect() async {
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
    public func toggleMicCapture() async {
        if assistantListening {
            await stopAssistantSession()
        } else {
            // Same id on the session and every sample, so the core listens to
            // this app's mic and drops the device's built-in mic.
            let source = audioSourceId
            UboLog.audio.info("toggleMicCapture: starting (audioSource=\(source))")
            do {
                try await client.startAssistantListening(audioSource: source)
                UboLog.audio.info("startAssistantListening dispatched ok")
                assistantListening = true
            } catch {
                UboLog.audio.error("startAssistantListening FAILED: \(error.localizedDescription)")
                lastError = (error as? UboError) ?? .dispatchFailed(error)
                return
            }
            do {
                try await micCapture.start(audioSource: source)
            } catch {
                UboLog.audio.error("micCapture.start FAILED: \(error.localizedDescription)")
                lastError = (error as? UboError) ?? .dispatchFailed(error)
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
