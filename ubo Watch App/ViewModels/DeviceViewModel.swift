import SwiftUI
import Combine
import UboSwift

@MainActor
@Observable
class DeviceViewModel {
    let client = UboClient()
    let audioPlayback = AudioPlaybackService()

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

    func connect(host: String, port: Int = 50051) async throws {
        savedHost = host
        savedPort = port
        try await client.connect(host: host, port: port, subscribeToDisplay: false)
        client.startViewSubscription()
        client.startStatsSubscription()
        client.startInputsSubscription()
        audioPlayback.configure(client: client)
        audioPlayback.start()
    }

    func connectWithSavedSettings() async throws {
        guard !savedHost.isEmpty else { return }
        try await connect(host: savedHost, port: savedPort)
    }

    func disconnect() async {
        audioPlayback.stop()
        await client.disconnect()
    }
}
