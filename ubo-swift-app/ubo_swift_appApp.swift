//
//  ubo_swift_appApp.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
    }
}
