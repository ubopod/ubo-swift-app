//
//  WatchContentView.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//

import UboAppKit
import SwiftUI
import UboSwift

struct WatchContentView: View {
    @Environment(DeviceViewModel.self) private var viewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var hasAttemptedAutoConnect = false
    @State private var showError = false
    @State private var errorMessage = ""

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
                do {
                    try await viewModel.connectWithSavedSettings()
                } catch {
                    viewModel.report("connectWithSavedSettings", error)
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            hasAttemptedAutoConnect = true
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct WatchConnectionView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    @State private var host: String = ""
    @State private var portString: String = String(UboConstants.defaultPort)
    @State private var useTLS: Bool = false
    @State private var discovered: [DiscoveredDevice] = []
    @State private var browseTask: Task<Void, Never>?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)

                    Text("Ubo Connect")
                        .font(.headline)

                    TextField("Host", text: $host)
                        .textContentType(.URL)

                    TextField("Port", text: $portString)
                        .onChange(of: portString) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            if digits != newValue { portString = digits }
                        }

                    Toggle("Use TLS", isOn: $useTLS)
                        .font(.caption)

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

                    // Discovered devices (Bonjour) — mirrors ConnectionView's
                    // always-shown section with a "searching" placeholder.
                    VStack(spacing: 6) {
                        Text("Found on network")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if discovered.isEmpty {
                            Text("Searching…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(Array(discovered).sorted(by: { $0.name < $1.name }), id: \.self) { device in
                                // A physical Watch can't reach `device.port` (the
                                // native raw-TCP proxy) at all — TN3135 blocks it
                                // outright. Use the grpc-web bridge port instead,
                                // falling back to `port` only against an older
                                // core that hasn't started advertising it yet.
                                let connectPort = device.grpcWebPort ?? device.port
                                Button {
                                    host = device.host
                                    portString = String(connectPort)
                                    useTLS = false
                                    connect()
                                } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(device.name).font(.caption.weight(.medium))
                                        Text("\(device.host):\(String(connectPort))")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Recent Connections (up to 3) — replaces the old
                    // single "Use Last" button with the full list, same as
                    // the phone app's ConnectionView.
                    if !viewModel.recentConnections.isEmpty {
                        VStack(spacing: 6) {
                            Text("Recent Connections")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(viewModel.recentConnections) { recent in
                                Button {
                                    host = recent.host
                                    portString = String(recent.port)
                                    useTLS = recent.useTLS
                                    connect()
                                } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(recent.host).font(.caption.weight(.medium))
                                        Text("Port \(String(recent.port))\(recent.useTLS ? " · TLS" : "")")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Setting up a brand new Ubo: it isn't on any network
                    // yet, so this has to work before any connection exists.
                    VStack(spacing: 6) {
                        Text("New Device Setup")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        NavigationLink {
                            WatchWiFiQRCodeView()
                        } label: {
                            Label("Set up a new Ubo's Wi-Fi", systemImage: "qrcode")
                                .font(.caption)
                        }
                    }
                }
                .padding()
            }
            .onAppear {
                if host.isEmpty && !viewModel.savedHost.isEmpty {
                    host = viewModel.savedHost
                    portString = String(viewModel.savedPort)
                    useTLS = viewModel.savedUseTLS
                }
                startDiscovery()
            }
            .onDisappear { stopDiscovery() }
            .alert("Connection Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func connect() {
        let port = Int(portString) ?? UboConstants.defaultPort
        Task {
            do {
                try await viewModel.connect(host: host, port: port, useTLS: useTLS)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func startDiscovery() {
        browseTask?.cancel()
        browseTask = Task { @MainActor in
            for await snapshot in UboDiscovery.browse() {
                discovered = Array(snapshot)
            }
        }
    }

    private func stopDiscovery() {
        browseTask?.cancel()
        browseTask = nil
    }
}

#Preview {
    WatchContentView()
        .environment(DeviceViewModel())
}
