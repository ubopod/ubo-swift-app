//
//  WatchContentView.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct WatchContentView: View {
    @Environment(DeviceViewModel.self) private var viewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var hasAttemptedAutoConnect = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                WatchOnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if viewModel.isConnected {
                TabView {
                    WatchDashboardView()
                    WatchDeviceView()
                    WatchActionsView()
                }
                .tabViewStyle(.verticalPage)
            } else if viewModel.isConnecting || (!hasAttemptedAutoConnect && viewModel.hasSavedConnection) {
                // Show loading while auto-reconnecting
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                WatchConnectionView()
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
}

struct WatchConnectionView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    @State private var host: String = ""
    @State private var isConnecting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)

                Text("Ubo Connect")
                    .font(.headline)

                TextField("Host", text: $host)
                    .textContentType(.URL)

                Button {
                    connect()
                } label: {
                    if viewModel.isConnecting {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
                }
                .disabled(host.isEmpty || viewModel.isConnecting)

                if !viewModel.savedHost.isEmpty {
                    Button("Use Last: \(viewModel.savedHost)") {
                        host = viewModel.savedHost
                        connect()
                    }
                    .font(.caption)
                }
            }
            .padding()
        }
        .onAppear {
            if host.isEmpty && !viewModel.savedHost.isEmpty {
                host = viewModel.savedHost
            }
        }
    }

    private func connect() {
        Task {
            try? await viewModel.connect(host: host)
        }
    }
}

#Preview {
    WatchContentView()
        .environment(DeviceViewModel())
}
