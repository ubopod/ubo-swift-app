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

    /// Local slider position. While the user is dragging we don't let
    /// incoming `state.audio.playback_volume` updates clobber it.
    @State private var volumeSlider: Double = 0
    @State private var isEditingVolume: Bool = false

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

                // Audio (volume + mute + chime)
                audioSection

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

    private var audioSection: some View {
        Section {
            // Volume slider — bound to a local @State so dragging is smooth,
            // synced from the device whenever we're not actively editing.
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: volumeIcon)
                        .foregroundStyle(.secondary)
                    Text("Volume")
                    Spacer()
                    Text("\(Int(volumeSlider * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $volumeSlider, in: 0...1) { editing in
                    isEditingVolume = editing
                    if !editing {
                        let target = Float(volumeSlider)
                        Task { try? await viewModel.client.setVolume(target) }
                    }
                }
            }
            .onAppear {
                if let v = viewModel.cachedPlaybackVolume {
                    volumeSlider = Double(v)
                }
            }
            .onChange(of: viewModel.cachedPlaybackVolume) { _, newValue in
                guard !isEditingVolume, let v = newValue else { return }
                volumeSlider = Double(v)
            }

            Toggle(
                "Mute",
                isOn: Binding(
                    get: { viewModel.cachedIsPlaybackMute ?? false },
                    set: { newValue in
                        Task { try? await viewModel.client.setMute(newValue) }
                    }
                )
            )

            Button {
                Task { try? await viewModel.client.playChime(.done) }
            } label: {
                Label("Play Test Chime", systemImage: "bell.fill")
            }

            // Microphone — controls the device's own input mute (not the
            // iPhone's PCM stream from `MicCaptureService`). Independent
            // toggle so users can quiet the Pi's mic without stopping the
            // push-to-talk pipeline.
            Toggle(
                isOn: Binding(
                    get: { viewModel.cachedIsCaptureMute ?? false },
                    set: { newValue in
                        Task { try? await viewModel.client.setMute(newValue, device: .input) }
                    }
                )
            ) {
                Label(
                    "Mute Device Microphone",
                    systemImage: (viewModel.cachedIsCaptureMute ?? false)
                        ? "mic.slash.fill"
                        : "mic.fill"
                )
            }
        } header: {
            Text("Audio")
        } footer: {
            Text("Volume changes propagate to and from the device — hardware buttons, the Watch, and other connected clients stay in sync. Muting the device microphone stops the Pi from listening; the push-to-talk button below streams audio from this iPhone separately.")
        }
    }

    private var volumeIcon: String {
        if (viewModel.cachedIsPlaybackMute ?? false) || volumeSlider == 0 {
            return "speaker.slash.fill"
        }
        if volumeSlider < 0.34 { return "speaker.fill" }
        if volumeSlider < 0.67 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
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
