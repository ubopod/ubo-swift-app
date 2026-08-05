import Foundation

/// Central home for values shared across the app targets and the widget.
/// Anything that used to be a scattered magic number belongs here.
public enum UboConstants {
    /// Default gRPC port the Ubo core listens on.
    public static let defaultPort = 50051

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
