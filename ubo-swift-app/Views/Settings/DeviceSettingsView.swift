//
//  DeviceSettingsView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct DeviceSettingsView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    @State private var ledBrightness: Double = 1.0
    @State private var ledEnabled: Bool = true
    @State private var displayTimeout: DisplayBlankTimeout = .fiveMinutes
    @State private var showPowerAlert = false
    @State private var powerAction: PowerAction? = nil

    enum PowerAction {
        case reboot, powerOff
    }

    var body: some View {
        NavigationStack {
            Form {
                // Connection Info
                connectionSection

                // LED Settings
                ledSection

                // Display Settings
                displaySection

                // Power Controls
                powerSection

                // Disconnect
                disconnectSection
            }
            .navigationTitle("Settings")
            .alert("Confirm Action", isPresented: $showPowerAlert) {
                Button("Cancel", role: .cancel) { }
                Button(powerAction == .reboot ? "Reboot" : "Power Off", role: .destructive) {
                    performPowerAction()
                }
            } message: {
                Text(powerAction == .reboot
                    ? "Are you sure you want to reboot the device?"
                    : "Are you sure you want to power off the device?")
            }
        }
    }

    private var connectionSection: some View {
        Section {
            LabeledContent("Host", value: viewModel.savedHost)
            LabeledContent("Port", value: String(viewModel.savedPort))
            LabeledContent("Status", value: viewModel.isConnected ? "Connected" : "Disconnected")
        } header: {
            Text("Connection")
        }
    }

    private var ledSection: some View {
        Section {
            Toggle("LEDs Enabled", isOn: $ledEnabled)
                .onChange(of: ledEnabled) { _, newValue in
                    Task { try? await viewModel.client.setLEDEnabled(newValue) }
                }

            VStack(alignment: .leading) {
                Text("Brightness: \(Int(ledBrightness * 100))%")
                Slider(value: $ledBrightness, in: 0...1) { editing in
                    if !editing {
                        Task { try? await viewModel.client.setLEDBrightness(Float(ledBrightness)) }
                    }
                }
            }

            HStack {
                Button("Red") {
                    Task { try? await viewModel.client.setLEDColor(.red) }
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button("Green") {
                    Task { try? await viewModel.client.setLEDColor(.green) }
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button("Blue") {
                    Task { try? await viewModel.client.setLEDColor(.blue) }
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button("Off") {
                    Task { try? await viewModel.client.clearLEDs() }
                }
                .buttonStyle(.bordered)
            }
        } header: {
            Text("RGB LED Ring")
        }
    }

    private var displaySection: some View {
        Section {
            Picker("Auto-Sleep Timeout", selection: $displayTimeout) {
                Text("1 minute").tag(DisplayBlankTimeout.oneMinute)
                Text("5 minutes").tag(DisplayBlankTimeout.fiveMinutes)
                Text("10 minutes").tag(DisplayBlankTimeout.tenMinutes)
                Text("30 minutes").tag(DisplayBlankTimeout.thirtyMinutes)
                Text("1 hour").tag(DisplayBlankTimeout.oneHour)
                Text("Never").tag(DisplayBlankTimeout.off)
            }
            .onChange(of: displayTimeout) { _, newValue in
                Task { try? await viewModel.client.setDisplayTimeout(newValue) }
            }

            HStack {
                Button("Sleep Now") {
                    Task { try? await viewModel.client.blankDisplay() }
                }
                .buttonStyle(.bordered)

                Button("Wake") {
                    Task { try? await viewModel.client.unblankDisplay() }
                }
                .buttonStyle(.bordered)
            }
        } header: {
            Text("Display")
        }
    }

    private var powerSection: some View {
        Section {
            Button {
                powerAction = .reboot
                showPowerAlert = true
            } label: {
                Label("Reboot Device", systemImage: "arrow.triangle.2.circlepath")
            }

            Button(role: .destructive) {
                powerAction = .powerOff
                showPowerAlert = true
            } label: {
                Label("Power Off", systemImage: "power")
            }
        } header: {
            Text("Power")
        } footer: {
            Text("These actions will disconnect you from the device.")
        }
    }

    private var disconnectSection: some View {
        Section {
            Button("Disconnect") {
                Task {
                    await viewModel.disconnect()
                }
            }
        }
    }

    private func performPowerAction() {
        Task {
            switch powerAction {
            case .reboot:
                try? await viewModel.client.reboot()
            case .powerOff:
                try? await viewModel.client.powerOff()
            case .none:
                break
            }
            await viewModel.disconnect()
        }
    }
}

#Preview {
    DeviceSettingsView()
        .environment(DeviceViewModel())
}
