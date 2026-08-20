// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UboAppKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
    ],
    products: [
        // Widget-safe shared logic: no gRPC dependency, so the widget
        // extension stays lean. The app targets get it re-exported through
        // UboAppKit.
        .library(name: "UboAppShared", targets: ["UboAppShared"]),
        // Everything the app targets share: capture/playback services and
        // the device view model, on top of the UboSwift gRPC client.
        .library(name: "UboAppKit", targets: ["UboAppKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ubopod/ubo-swift-grpc.git", branch: "dev"),
        // CoreImage (and its CIFilter QR generator) isn't part of the
        // watchOS SDK, so a CIFilter-based generator can't build for the
        // watch target. QRCode falls back to a pure-Swift generator on
        // watchOS while still using CoreImage on the platforms that have
        // it — one call site for both, instead of a per-platform impl.
        .package(url: "https://github.com/dagronf/QRCode.git", from: "28.0.0"),
    ],
    targets: [
        .target(
            name: "UboAppShared",
            dependencies: [
                .product(name: "QRCode", package: "QRCode"),
            ]
        ),
        .target(
            name: "UboAppKit",
            dependencies: [
                "UboAppShared",
                .product(name: "UboSwift", package: "ubo-swift-grpc"),
            ]
        ),
        .testTarget(name: "UboAppKitTests", dependencies: ["UboAppKit"]),
    ],
    swiftLanguageModes: [.v5]
)
