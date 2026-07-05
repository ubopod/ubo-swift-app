//
//  ContentView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import UboAppKit
import SwiftUI
import UboSwift

struct ContentView: View {
    @Environment(DeviceViewModel.self) private var viewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var hasAttemptedAutoConnect = false
    @State private var selectedTab: Tab = .dashboard

    private enum Tab: Hashable { case dashboard, device, settings }

    /// The onboarding carousel is phone-oriented (it even describes the
    /// on-phone D-pad), so tvOS skips straight to the connection screen.
    private var needsOnboarding: Bool {
        #if os(tvOS)
        false
        #else
        !hasCompletedOnboarding
        #endif
    }

    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if viewModel.isConnected {
                // macOS + tvOS use the focus-driven tile shell (Web-UI style);
                // iPhone/iPad/visionOS keep the tap-first tab UI.
                #if os(tvOS) || os(macOS)
                TileShellView()
                #else
                mainTabView
                #endif
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
            if !needsOnboarding && !viewModel.isConnected && !viewModel.isConnecting && viewModel.hasSavedConnection {
                try? await viewModel.connectWithSavedSettings()
            }
            hasAttemptedAutoConnect = true
        }
        #if os(iOS) || os(visionOS)
        // A scanned `ubo://input` QR from an Apple TV: connect to the TV's core
        // (if not already there) and land on the Device tab, where the shared
        // input form auto-presents.
        .onOpenURL(perform: handleDeeplink)
        #endif
    }

    #if os(iOS) || os(visionOS)
    private func handleDeeplink(_ url: URL) {
        guard let request = UboDeeplink.parseInput(url) else { return }
        Task {
            let needsConnect = !viewModel.isConnected
                || viewModel.savedHost != request.host
                || viewModel.savedPort != request.port
            if needsConnect {
                try? await viewModel.connect(
                    host: request.host,
                    port: request.port,
                    useTLS: request.useTLS
                )
            }
            selectedTab = .device
        }
    }
    #endif

    #if os(iOS)
    private var cameraCoverBinding: Binding<Bool> {
        .init(
            get: { viewModel.cameraManager.isActive },
            set: { newValue in
                if !newValue {
                    viewModel.cameraManager.stopCamera()
                }
            }
        )
    }

    @ViewBuilder private var cameraOverlay: some View {
        CameraOverlayView(
            cameraManager: viewModel.cameraManager,
            pattern: viewModel.client.cameraPattern,
            onDismiss: {
                viewModel.cameraManager.stopCamera()
            }
        )
    }
    #endif

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(Tab.dashboard)

            DeviceView()
                .tabItem {
                    Label("Device", systemImage: "display")
                }
                .tag(Tab.device)

            DeviceSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        // The viewfinder cover is iOS-only (macOS uses the shell; visionOS has
        // no camera). macOS camera presentation is wired into TileShellView.
        #if os(iOS)
        .fullScreenCover(isPresented: cameraCoverBinding) { cameraOverlay }
        #endif
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
