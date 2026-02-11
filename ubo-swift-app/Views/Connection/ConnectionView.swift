//
//  ConnectionView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct ConnectionView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    @State private var host: String = ""
    @State private var portString: String = "50051"
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

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
                                .textFieldStyle(.roundedBorder)
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

                            TextField("50051", text: $portString)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
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

                    // Recent Connection
                    if !viewModel.savedHost.isEmpty && viewModel.savedHost != host {
                        VStack(spacing: 12) {
                            Text("Recent")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                host = viewModel.savedHost
                                portString = String(viewModel.savedPort)
                                connect()
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)

                                    VStack(alignment: .leading) {
                                        Text(viewModel.savedHost)
                                            .font(.body.weight(.medium))
                                        Text("Port \(viewModel.savedPort)")
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
                    }

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
                }
            }
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

        let port = Int(portString) ?? 50051

        Task {
            do {
                try await viewModel.connect(host: host, port: port)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ConnectionView()
        .environment(DeviceViewModel())
}
