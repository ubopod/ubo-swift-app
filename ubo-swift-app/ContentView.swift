//
//  ContentView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct ContentView: View {
    @Environment(DeviceViewModel.self) private var viewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var hasAttemptedAutoConnect = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if viewModel.isConnected {
                mainTabView
            } else if viewModel.isConnecting || (!hasAttemptedAutoConnect && viewModel.hasSavedConnection) {
                // Show loading while auto-reconnecting
                connectingView
            } else {
                // Show connection screen if no saved connection or auto-connect failed
                ConnectionView()
            }
        }
        .task {
            // Auto-reconnect with saved settings on launch
            if hasCompletedOnboarding && !viewModel.isConnected && !viewModel.isConnecting && viewModel.hasSavedConnection {
                try? await viewModel.connectWithSavedSettings()
            }
            hasAttemptedAutoConnect = true
        }
    }

    private var mainTabView: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }

            DeviceView()
                .tabItem {
                    Label("Device", systemImage: "display")
                }

            DeviceSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }

    private var connectingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Connecting to \(viewModel.savedHost)...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Connected") {
    ContentView()
        .environment(DeviceViewModel())
}

#Preview("Onboarding") {
    ContentView()
        .environment(DeviceViewModel())
}
