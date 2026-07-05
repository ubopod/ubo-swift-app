//
//  ubo_swift_appApp.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import UboAppKit
import SwiftUI
import UboSwift

@main
struct UboSwiftApp: App {
    @State private var viewModel = DeviceViewModel()

    init() {
        #if DEBUG
        UboLog.level = .debug
        #else
        UboLog.level = .info
        #endif
        UboIconFontBootstrap.ensureRegistered()
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
        // Backgrounding suspends the audio engine; end a live listening
        // session cleanly and re-arm the playback subscription on return.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: viewModel.sceneDidEnterBackground()
            case .active: viewModel.sceneDidBecomeActive()
            default: break
            }
        }
    }
}
