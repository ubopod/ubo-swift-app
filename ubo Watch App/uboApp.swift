//
//  uboApp.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

@main
struct UboWatchApp: App {
    @State private var viewModel = DeviceViewModel()

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
    }
}
