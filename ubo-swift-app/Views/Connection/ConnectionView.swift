//
//  ConnectionView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import UboAppKit
import SwiftUI
import UboSwift

struct ConnectionView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    @State private var host: String = ""
    @State private var portString: String = String(UboConstants.defaultPort)
    @State private var useTLS: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var discovered: [DiscoveredDevice] = []
    @State private var browseTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor)

                        Text("Connect to Ubo")
                            .font(.title2.bold())

                        Text("Enter the IP address or hostname of your Ubo device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal)

                    // Connection Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Host")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            TextField("e.g. ubo.local or 192.168.1.100", text: $host)
                                #if !os(tvOS)
                                .textFieldStyle(.roundedBorder)
                                #endif
                                .textContentType(.URL)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                #endif
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Port")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            TextField(String(UboConstants.defaultPort), text: $portString)
                                #if !os(tvOS)
                                .textFieldStyle(.roundedBorder)
                                #endif
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                        }

                        Toggle(isOn: $useTLS) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use TLS (secure)")
                                    .font(.subheadline.weight(.medium))
                                Text("Enable when connecting through a secure tunnel or reverse proxy.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Connect Button
                    Button {
                        connect()
                    } label: {
                        HStack {
                            if viewModel.isConnecting {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text(viewModel.isConnecting ? "Connecting..." : "Connect")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(host.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(host.isEmpty || viewModel.isConnecting)
                    .padding(.horizontal)

                    Link("Order UboPod", destination: URL(string: "https://shop.getubo.com/products/ubo-pro-4-and-5")!)
                        .font(.subheadline.weight(.medium))

                    // Discovered devices (Bonjour) — always shown, with a
                    // "searching" placeholder when empty, so there's a visual
                    // sign discovery is running (mirrors ConnectionScreen.kt).
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "wifi")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                            Text("Found on network")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        if discovered.isEmpty {
                            Text("Searching… make sure your phone and Ubo device are on the same Wi-Fi network.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(Array(discovered).sorted(by: { $0.name < $1.name }), id: \.self) { device in
                                Button {
                                    host = device.host
                                    portString = String(device.port)
                                    // mDNS-discovered devices are on the LAN → plaintext.
                                    useTLS = false
                                    connect()
                                } label: {
                                    HStack {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .font(.title3)
                                            .foregroundStyle(Color.accentColor)
                                        VStack(alignment: .leading) {
                                            Text(device.name)
                                                .font(.body.weight(.medium))
                                            Text("\(device.host):\(String(device.port))")
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding()
                                    .background {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.regularMaterial)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Recent Connections (up to 3)
                    if !viewModel.recentConnections.isEmpty {
                        VStack(spacing: 12) {
                            Text("Recent Connections")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(viewModel.recentConnections) { recent in
                                Button {
                                    host = recent.host
                                    portString = String(recent.port)
                                    useTLS = recent.useTLS
                                    connect()
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.title3)
                                            .foregroundStyle(Color.accentColor)

                                        VStack(alignment: .leading) {
                                            Text(recent.host)
                                                .font(.body.weight(.medium))
                                            Text("Port \(String(recent.port))\(recent.useTLS ? " · TLS" : "")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding()
                                    .background {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.regularMaterial)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Setting up a brand new Ubo: it isn't on any network yet,
                    // so this has to work before any connection exists.
                    VStack(spacing: 12) {
                        Text("New Device Setup")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        NavigationLink {
                            WiFiQRCodeGeneratorView()
                        } label: {
                            HStack {
                                Image(systemName: "qrcode")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)

                                VStack(alignment: .leading) {
                                    Text("Set up a new Ubo's Wi-Fi")
                                        .font(.body.weight(.medium))
                                    Text("Generate a QR code for the pod's camera to scan.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.regularMaterial)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Ubo Connect")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

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
    ConnectionView()
        .environment(DeviceViewModel())
}
