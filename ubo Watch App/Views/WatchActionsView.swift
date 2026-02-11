//
//  WatchActionsView.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct WatchActionsView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        List {
            Section("Audio") {
                Button {
                    Task { try? await viewModel.client.playChime(.done) }
                } label: {
                    Label("Play Chime", systemImage: "bell.fill")
                }

                Button {
                    Task { try? await viewModel.client.toggleMute() }
                } label: {
                    Label("Toggle Mute", systemImage: "speaker.slash.fill")
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

#Preview {
    WatchActionsView()
        .environment(DeviceViewModel())
}
