import SwiftUI
import Combine
import WidgetKit
import UboSwift

@MainActor
@Observable
class DeviceViewModel {
    let client = UboClient()
    let cameraManager = CameraManager()
    let micCapture = MicCaptureService()
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

    private var cancellables = Set<AnyCancellable>()
    private var cameraObservationTask: Task<Void, Never>?

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

        // Subscribe to system stats for continuous CPU/RAM/temperature updates
        client.$systemStats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                if let stats = stats {
                    self?.cachedCpuPercent = stats.cpuPercent
                    self?.cachedRamPercent = stats.ramPercent
                    self?.cachedTemperature = stats.temperature
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
        WidgetCenter.shared.reloadAllTimelines()
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

    var menuPageInfo: (current: Int, total: Int)? {
        if case .menu(let data) = currentView {
            return (data.pageIndex, data.totalPages)
        }
        return nil
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
        client.startCameraSubscription()
        client.startInputsSubscription()
        cameraManager.configure(client: client)
        startCameraObservation()
        micCapture.configure(client: client)
        audioPlayback.configure(client: client)
        audioPlayback.start()
    }

    func connectWithSavedSettings() async throws {
        guard !savedHost.isEmpty else { return }
        try await connect(host: savedHost, port: savedPort)
    }

    func disconnect() async {
        cameraObservationTask?.cancel()
        cameraObservationTask = nil
        cameraManager.stopCamera()
        micCapture.stop()
        audioPlayback.stop()
        await client.disconnect()
    }

    /// Toggle "press to talk" mic capture. Streams PCM16 frames to the
    /// device's assistant pipeline.
    func toggleMicCapture() async {
        if micCapture.isRunning {
            micCapture.stop()
            try? await client.stopAssistantListening()
        } else {
            try? await client.startAssistantListening()
            try? await micCapture.start()
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
}
