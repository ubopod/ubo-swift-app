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
class DeviceViewModel {
    let client = UboClient()
    // Local capture (camera viewfinder, mic streaming, device-audio playback)
    // exists only on the platforms with the hardware + capture APIs. tvOS has
    // no camera/mic and routes the assistant to the Pi's own mics instead.
    #if os(iOS) || os(macOS)
    let cameraManager = CameraManager()
    let micCapture = MicCaptureService()
    let audioPlayback = AudioPlaybackService()
    #endif

    /// Whether an assistant listening session this client controls is live.
    /// Backs the mic icon — a stored property so `@Observable` re-renders it.
    private(set) var assistantListening = false

    // Observable state - updated from client
    private(set) var isConnecting: Bool = false
    private(set) var isConnected: Bool = false
    private(set) var currentView: ViewData?
    private(set) var statusBar: StatusBarData?
    private(set) var lastError: UboError?
    private(set) var activeInputs: [WebUIInputDescription] = []
    private(set) var stack: [UboStackItem] = []

    // System stats - continuously updated from stats subscription
    private(set) var cachedCpuPercent: Float = 0
    private(set) var cachedRamPercent: Float = 0
    private(set) var cachedTemperature: Float?
    private(set) var cachedPlaybackVolume: Float?
    private(set) var cachedIsPlaybackMute: Bool?
    private(set) var cachedIsCaptureMute: Bool?

    private var cancellables = Set<AnyCancellable>()
    #if os(iOS) || os(macOS)
    private var cameraObservationTask: Task<Void, Never>?
    private var cameraDetectAdvertiseCancellable: AnyCancellable?
    #endif

    #if os(iOS) || os(macOS)
    /// Stable id under which this iPhone advertises itself as a camera
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

    /// Stable id identifying this app as a microphone source. Sent on
    /// `startAssistantListening` and on every streamed sample so the core
    /// binds the listening session to this app's mic and ignores the
    /// device's built-in mic (mirrors the Web UI's `web-ui:` audio source).
    /// Generated once on first launch and persisted.
    private var audioSourceId: String {
        if let existing = UserDefaults.standard.string(forKey: "audioSourceId") {
            return existing
        }
        let new = "ios:\(UUID().uuidString)"
        UserDefaults.standard.set(new, forKey: "audioSourceId")
        return new
    }

    /// Human-readable label shown in the Pi's camera picker.
    private var cameraSourceLabel: String {
        #if canImport(UIKit)
        let name = UIDevice.current.name
        return name.isEmpty ? "iPhone" : name
        #else
        return "iPhone"
        #endif
    }
    #endif

    init() {
        // Observe client's published properties
        client.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isConnecting = state.isConnecting
                self?.isConnected = state.isConnected
                self?.updateWidgetData()
            }
            .store(in: &cancellables)

        client.$currentView
            .receive(on: DispatchQueue.main)
            .sink { [weak self] view in
                self?.currentView = view
            }
            .store(in: &cancellables)

        client.$statusBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bar in
                self?.statusBar = bar
            }
            .store(in: &cancellables)

        client.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.lastError = error
            }
            .store(in: &cancellables)

        client.$activeInputs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inputs in
                self?.activeInputs = inputs
            }
            .store(in: &cancellables)

        client.$stack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stack in
                self?.stack = stack
            }
            .store(in: &cancellables)

        // Subscribe to system stats for continuous CPU/RAM/temperature updates
        client.$systemStats
            .receive(on: DispatchQueue.main)
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

    /// Last time widget data was updated
    private var lastWidgetUpdate: Date = .distantPast

    /// Update shared data for widgets (throttled to every 5 seconds)
    private func updateWidgetData() {
        let now = Date()
        guard now.timeIntervalSince(lastWidgetUpdate) >= 5 else { return }
        lastWidgetUpdate = now

        let sharedStats = SharedSystemStats(
            cpuPercent: cachedCpuPercent,
            ramPercent: cachedRamPercent,
            temperature: cachedTemperature,
            isConnected: isConnected,
            deviceHost: savedHost
        )
        sharedStats.save()
        print("[Widget] Saved stats: CPU=\(cachedCpuPercent)%, RAM=\(cachedRamPercent)%, Connected=\(isConnected)")

        // Reload widget timelines
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // Persisted settings
    var savedHost: String {
        get { UserDefaults.standard.string(forKey: "deviceHost") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "deviceHost") }
    }

    var savedPort: Int {
        get { UserDefaults.standard.integer(forKey: "devicePort").nonZero ?? 50051 }
        set { UserDefaults.standard.set(newValue, forKey: "devicePort") }
    }

    var savedUseTLS: Bool {
        get { UserDefaults.standard.bool(forKey: "deviceUseTLS") }
        set { UserDefaults.standard.set(newValue, forKey: "deviceUseTLS") }
    }

    var hasSavedConnection: Bool {
        !savedHost.isEmpty
    }

    // System stats helpers - use cached values so stats persist when navigating menus
    var cpuPercent: Float {
        cachedCpuPercent
    }

    var ramPercent: Float {
        cachedRamPercent
    }

    var temperature: Float? {
        cachedTemperature
    }

    // Menu view data helpers
    var menuTitle: String {
        if case .menu(let data) = currentView {
            return data.title
        }
        return "Menu"
    }

    var menuItems: [MenuItemData] {
        if case .menu(let data) = currentView {
            return data.items.compactMap { $0 }
        } else if case .home(let data) = currentView {
            return data.menuItems
        }
        return []
    }

    // Notification view data helpers
    var notification: NotificationViewData? {
        if case .notification(let data) = currentView {
            return data
        }
        return nil
    }

    func connect(host: String, port: Int = 50051, useTLS: Bool = false) async throws {
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
        micCapture.configure(client: client)
        audioPlayback.configure(client: client)
        audioPlayback.start()
        #endif
    }

    func connectWithSavedSettings() async throws {
        guard !savedHost.isEmpty else { return }
        try await connect(host: savedHost, port: savedPort, useTLS: savedUseTLS)
    }

    func disconnect() async {
        #if os(iOS) || os(macOS)
        cameraObservationTask?.cancel()
        cameraObservationTask = nil
        cameraDetectAdvertiseCancellable?.cancel()
        cameraDetectAdvertiseCancellable = nil
        cameraManager.stopCamera()
        micCapture.stop()
        audioPlayback.stop()
        #endif
        await client.disconnect()
    }

    /// Whether an assistant listening session this client controls is active.
    /// On iOS/macOS that means this client's mic is streaming; on tvOS it
    /// means the Pi's own mics are listening on this client's behalf.
    var isAssistantListening: Bool { assistantListening }

    /// Unified mic toggle used by the shared TV/desktop shell. iOS/macOS
    /// stream the local mic; tvOS dispatches a device-routed session with an
    /// empty `audio_source`, so the Pi's built-in mics do the listening.
    func toggleAssistantListening() async {
        #if os(iOS) || os(macOS)
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
            }
        }
        #endif
    }

    #if os(iOS) || os(macOS)
    /// Toggle "press to talk" mic capture. Streams PCM16 frames to the
    /// device's assistant pipeline.
    func toggleMicCapture() async {
        if assistantListening {
            UboLog.audio.info("toggleMicCapture: stopping")
            micCapture.stop()
            do { try await client.stopAssistantListening() }
            catch { UboLog.audio.error("stopAssistantListening failed: \(error.localizedDescription)") }
            assistantListening = false
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
                return
            }
            do {
                try await micCapture.start(audioSource: source)
            } catch {
                UboLog.audio.error("micCapture.start FAILED: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Camera Source Registration

    /// Subscribe to the device's `CameraDetectAdvertiseEvent` stream and
    /// (re-)register this iPhone as a camera source on every yield. The
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
                Task { try? await client.registerAsCameraSource(id: id, label: label) }
            }
    }

    // MARK: - Camera Observation

    private func startCameraObservation() {
        cameraObservationTask?.cancel()
        cameraObservationTask = Task { [weak self] in
            guard let self else { return }
            var wasActive = false

            // Observe client.isCameraViewfinderActive changes
            for await isActive in self.client.$isCameraViewfinderActive.values {
                guard !Task.isCancelled else { break }
                if isActive && !wasActive {
                    self.cameraManager.startCamera()
                } else if !isActive && wasActive {
                    self.cameraManager.stopCamera()
                }
                wasActive = isActive
            }
        }
    }
    #endif
}
