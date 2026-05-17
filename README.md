
# UBO Swift App

A multiplatform Swift application for iOS, macOS, and watchOS.

## Features

- Cross-platform compatibility
- Native performance
- SwiftUI interface

## Requirements

- Xcode 14.0+
- Swift 5.7+
- iOS 15.0+, macOS 12.0+, watchOS 8.0+

## Installation

1. Clone the repository
2. Open `UBO.xcodeproj` in Xcode
3. Select your target platform
4. Build and run

## Architecture

Built with SwiftUI and Combine for reactive, declarative UI across all platforms.

## Logging

`UboSwift` exposes a unified `UboLog` API on top of `os.Logger`. Apps choose
the verbosity at startup:

```swift
import UboSwift

@main
struct uboApp: App {
    init() {
        #if DEBUG
        UboLog.level = .debug   // verbose — every subscription event, every dispatch
        #else
        UboLog.level = .info    // production — only lifecycle events
        #endif
        // or UboLog.level = .off to suppress entirely
    }
    // ...
}
```

Filter in **Console.app** (or Xcode's debug console) by subsystem
`com.ubopod.uboswift`. To narrow further, e.g. just the input flow:

```
subsystem:com.ubopod.uboswift category:input
```

Available categories: `connection`, `subscription`, `input`, `action`,
`audio`, `camera`, `discovery`.

## Contributing

Pull requests welcome. Please follow Swift style guidelines.

## License

Apache License 2.0
