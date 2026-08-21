//
//  WatchActionsView.swift
//  ubo Watch App
//
//  Quick-actions tab. Audio / LEDs / Display / Assistant grouped under
//  one List. The Volume row pushes to a dedicated `WatchVolumeView`
//  driven by the digital crown so we don't bind the crown globally on
//  this tab and disturb menu scrolling on others.
//

import UboAppKit
import SwiftUI
import UboSwift

struct WatchActionsView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    @State private var showPowerAlert = false
    @State private var powerAction: PowerAction?

    enum PowerAction {
        case reboot, powerOff
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Audio") {
                    NavigationLink {
                        WatchVolumeView()
                    } label: {
                        HStack {
                            Label("Volume", systemImage: volumeIcon)
                            Spacer()
                            Text(volumePercentLabel)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        viewModel.perform("playChime") { try await viewModel.client.playChime(.done) }
                    } label: {
                        Label("Play Chime", systemImage: "bell.fill")
                    }

                    Button {
                        viewModel.perform("toggleMute") { try await viewModel.client.toggleMute() }
                    } label: {
                        Label(
                            (viewModel.cachedIsPlaybackMute ?? false) ? "Unmute" : "Mute",
                            systemImage: (viewModel.cachedIsPlaybackMute ?? false)
                                ? "speaker.fill"
                                : "speaker.slash.fill"
                        )
                    }

                    Button {
                        viewModel.perform("toggleMute") { try await viewModel.client.toggleMute(device: .input) }
                    } label: {
                        Label(
                            (viewModel.cachedIsCaptureMute ?? false) ? "Unmute Mic" : "Mute Mic",
                            systemImage: (viewModel.cachedIsCaptureMute ?? false)
                                ? "mic.slash.fill"
                                : "mic.fill"
                        )
                    }
                }

                Section("LEDs") {
                    Button {
                        viewModel.perform("rainbowLEDs") { try await viewModel.client.rainbowLEDs() }
                    } label: {
                        Label("Rainbow", systemImage: "rainbow")
                    }

                    Button {
                        viewModel.perform("pulseLEDs") { try await viewModel.client.pulseLEDs(color: .blue) }
                    } label: {
                        Label("Pulse", systemImage: "waveform.path")
                    }

                    Button {
                        viewModel.perform("clearLEDs") { try await viewModel.client.clearLEDs() }
                    } label: {
                        Label("LEDs Off", systemImage: "lightbulb.slash")
                    }
                }

                Section("Display") {
                    Button {
                        viewModel.perform("blankDisplay") { try await viewModel.client.blankDisplay() }
                    } label: {
                        Label("Sleep", systemImage: "moon.fill")
                    }

                    Button {
                        viewModel.perform("unblankDisplay") { try await viewModel.client.unblankDisplay() }
                    } label: {
                        Label("Wake", systemImage: "sun.max.fill")
                    }
                }

                Section("Assistant") {
                    Button {
                        Task { await viewModel.toggleMicCapture() }
                    } label: {
                        Label(
                            viewModel.isAssistantListening ? "Stop Talking" : "Push to Talk",
                            systemImage: viewModel.isAssistantListening
                                ? "mic.fill"
                                : "mic.circle"
                        )
                        .foregroundStyle(viewModel.isAssistantListening ? Color.red : Color.primary)
                    }

                    // Device-routed session (the Pi listens with its own
                    // mics). Disabled while the watch mic is streaming so the
                    // two entry points can't interleave and desync.
                    Button {
                        viewModel.perform("toggleAssistantListening") { try await viewModel.client.toggleAssistantListening() }
                    } label: {
                        Label("Assistant on Pod", systemImage: "waveform.circle.fill")
                    }
                    .disabled(viewModel.isAssistantListening)
                }

                Section("Power") {
                    Button {
                        powerAction = .reboot
                        showPowerAlert = true
                    } label: {
                        Label("Reboot", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        powerAction = .powerOff
                        showPowerAlert = true
                    } label: {
                        Label("Power Off", systemImage: "power")
                    }
                }

                // Mirrors the phone app's Settings-tab Disconnect
                // button/Dashboard-toolbar icon — same glyph, no confirm.
                Section("Connection") {
                    Button {
                        Task { await viewModel.disconnect() }
                    } label: {
                        Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Actions")
            .alert("Confirm Action", isPresented: $showPowerAlert) {
                Button("Cancel", role: .cancel) { }
                Button(powerAction == .reboot ? "Reboot" : "Power Off", role: .destructive) {
                    performPowerAction()
                }
            } message: {
                Text(powerAction == .reboot
                    ? "Reboot the device?"
                    : "Power off the device?")
            }
        }
    }

    private func performPowerAction() {
        Task {
            switch powerAction {
            case .reboot:
                do { try await viewModel.client.reboot() } catch { viewModel.report("reboot", error) }
            case .powerOff:
                do { try await viewModel.client.powerOff() } catch { viewModel.report("powerOff", error) }
            case .none:
                break
            }
            await viewModel.disconnect()
        }
    }

    private var volumePercentLabel: String {
        guard let v = viewModel.cachedPlaybackVolume else { return "—" }
        return "\(Int(v * 100))%"
    }

    private var volumeIcon: String {
        let muted = viewModel.cachedIsPlaybackMute ?? false
        let v = viewModel.cachedPlaybackVolume ?? 0
        if muted || v == 0 { return "speaker.slash.fill" }
        if v < 0.34 { return "speaker.fill" }
        if v < 0.67 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }
}

#Preview {
    WatchActionsView()
        .environment(DeviceViewModel())
}
