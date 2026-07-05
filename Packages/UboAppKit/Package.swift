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
        .package(path: "../../../ubo-swift-grpc"),
    ],
    targets: [
        .target(name: "UboAppShared"),
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
