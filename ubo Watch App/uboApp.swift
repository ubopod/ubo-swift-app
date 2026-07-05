//
//  uboApp.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//

import UboAppKit
import SwiftUI
import UboSwift

@main
struct UboWatchApp: App {
    @State private var viewModel = DeviceViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        UboLog.level = .debug
        #else
        UboLog.level = .info
        #endif
        UboIconFontBootstrap.ensureRegistered()
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(viewModel)
        }
        // Wrist-down suspends the app and kills the audio engine; end the
        // core-side listening session cleanly instead of leaving it bound
        // to a dead mic, and re-arm playback on return.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: viewModel.sceneDidEnterBackground()
            case .active: viewModel.sceneDidBecomeActive()
            default: break
            }
        }
    }
}
