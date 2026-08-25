import Foundation

/// Central home for values shared across the app targets and the widget.
/// Anything that used to be a scattered magic number belongs here.
public enum UboConstants {
    /// Default gRPC port for reaching a device over the network.
    ///
    /// 50053 is Envoy's raw-TCP proxy, which exposes the core's gRPC server
    /// to the LAN. The core itself listens on 127.0.0.1:50051 and is not
    /// reachable from another device.
    ///
    /// A physical Apple Watch can't reach that raw-TCP proxy at all — real
    /// hardware blocks low-level networking outright per Apple's TN3135
    /// technote — so watchOS defaults to 50052, Envoy's grpc-web bridge,
    /// which `GRPCWebClientTransport` speaks over `URLSession` instead.
    /// Every other platform is unaffected and keeps 50053.
    #if os(watchOS)
    public static let defaultPort = 50052
    #else
    public static let defaultPort = 50053
    #endif

    /// App Group identifier for sharing data between app and widget.
    public static let appGroupIdentifier = "group.com.getubo.ubo-swift-app.shared"

    /// Minimum interval between widget data refreshes from the app.
    public static let widgetUpdateThrottle: TimeInterval = 5

    /// Widget data older than this is rendered as stale/disconnected.
    public static let widgetStaleThreshold: TimeInterval = 300

    /// Mic capture wire format the core's assistant pipeline expects.
    public static let micSampleRate: Double = 16000
    public static let micTapBufferSize: UInt32 = 1024

    /// Remote camera frames: square crop size and pacing (~12 FPS).
    public static let cameraTargetSize = 240
    public static let cameraFrameInterval: TimeInterval = 1.0 / 12.0
}
