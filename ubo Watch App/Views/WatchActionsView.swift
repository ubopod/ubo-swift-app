//
//  WatchActionsView.swift
//  ubo Watch App
//
//  Quick-actions tab. Audio / LEDs / Display / Assistant grouped under
//  one List. The Volume row pushes to a dedicated `WatchVolumeView`
//  driven by the digital crown so we don't bind the crown globally on
//  this tab and disturb menu scrolling on others.
//

import SwiftUI
import UboSwift

struct WatchActionsView: View {
    @Environment(DeviceViewModel.self) private var viewModel

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
                        Task { try? await viewModel.client.playChime(.done) }
                    } label: {
                        Label("Play Chime", systemImage: "bell.fill")
                    }

                    Button {
                        Task { try? await viewModel.client.toggleMute() }
                    } label: {
                        Label(
                            (viewModel.cachedIsPlaybackMute ?? false) ? "Unmute" : "Mute",
                            systemImage: (viewModel.cachedIsPlaybackMute ?? false)
                                ? "speaker.fill"
                                : "speaker.slash.fill"
                        )
                    }
                }

                Section("LEDs") {
                    Button {
                        Task { try? await viewModel.client.rainbowLEDs() }
                    } label: {
                        Label("Rainbow", systemImage: "rainbow")
                    }

                    Button {
                        Task { try? await viewModel.client.pulseLEDs(color: .blue) }
                    } label: {
                        Label("Pulse", systemImage: "waveform.path")
                    }

                    Button {
                        Task { try? await viewModel.client.clearLEDs() }
                    } label: {
                        Label("LEDs Off", systemImage: "lightbulb.slash")
                    }
                }

                Section("Display") {
                    Button {
                        Task { try? await viewModel.client.blankDisplay() }
                    } label: {
                        Label("Sleep", systemImage: "moon.fill")
                    }

                    Button {
                        Task { try? await viewModel.client.unblankDisplay() }
                    } label: {
                        Label("Wake", systemImage: "sun.max.fill")
                    }
                }

                Section("Assistant") {
                    Button {
                        Task { try? await viewModel.client.toggleAssistantListening() }
                    } label: {
                        Label("Toggle Assistant", systemImage: "waveform.circle.fill")
                    }
                }
            }
            .navigationTitle("Actions")
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
