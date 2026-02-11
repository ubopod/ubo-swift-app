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

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(viewModel)
        }
    }
}
