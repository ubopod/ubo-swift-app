import Foundation

/// One entry in `DeviceViewModel.recentConnections` — a pod the user has
/// connected to before, so they can switch back without re-typing
/// host/port/TLS.
public struct RecentConnection: Codable, Sendable, Equatable, Identifiable {
    public var host: String
    public var port: Int
    public var useTLS: Bool

    public var id: String { "\(host):\(port)" }

    public init(host: String, port: Int, useTLS: Bool) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }
}
