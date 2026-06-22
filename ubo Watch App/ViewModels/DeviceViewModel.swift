import SwiftUI
import Combine
import UboSwift
import GRPCNIOTransportHTTP2

@MainActor
@Observable
class DeviceViewModel {
    let client = UboClient()
    let audioPlayback = AudioPlaybackService()
    let micCapture = MicCaptureService()

    // Observable state - updated from client
    private(set) var isConnecting: Bool = false
    private(set) var isConnected: Bool = false
    private(set) var currentView: ViewData?
    private(set) var statusBar: StatusBarData?
    private(set) var lastError: UboError?
    private(set) var activeInputs: [WebUIInputDescription] = []

    // System stats - continuously updated from stats subscription
    private(set) var cachedCpuPercent: Float = 0
    private(set) var cachedRamPercent: Float = 0
    private(set) var cachedTemperature: Float?
    private(set) var cachedPlaybackVolume: Float?
    private(set) var cachedIsPlaybackMute: Bool?
    private(set) var cachedIsCaptureMute: Bool?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe client's published properties
        client.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isConnecting = state.isConnecting
                self?.isConnected = state.isConnected
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
                }
            }
            .store(in: &cancellables)
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
        audioPlayback.configure(client: client)
        audioPlayback.start()
        micCapture.configure(client: client)
    }

    func connectWithSavedSettings() async throws {
        guard !savedHost.isEmpty else { return }
        try await connect(host: savedHost, port: savedPort, useTLS: savedUseTLS)
    }

    func disconnect() async {
        micCapture.stop()
        audioPlayback.stop()
        await client.disconnect()
    }

    /// Stable id identifying this Watch app as a microphone source. Sent on
    /// `startAssistantListening` and every streamed sample so the core binds
    /// the session to this app's mic and ignores the device's built-in mic
    /// (mirrors the Web UI's `web-ui:` audio source). Persisted across launches.
    private var audioSourceId: String {
        if let existing = UserDefaults.standard.string(forKey: "audioSourceId") {
            return existing
        }
        let new = "watch:\(UUID().uuidString)"
        UserDefaults.standard.set(new, forKey: "audioSourceId")
        return new
    }

    /// Toggle "press to talk" mic capture on the Watch. Streams PCM16 frames
    /// to the device's assistant pipeline; mirrors `iOS DeviceViewModel`.
    func toggleMicCapture() async {
        if micCapture.isRunning {
            micCapture.stop()
            try? await client.stopAssistantListening()
        } else {
            // Same id on the session and every sample, so the core listens to
            // this app's mic and drops the device's built-in mic.
            let source = audioSourceId
            try? await client.startAssistantListening(audioSource: source)
            try? await micCapture.start(audioSource: source)
        }
    }
}
