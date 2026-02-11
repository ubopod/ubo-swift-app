//
//  QuickActionsView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct QuickActionsView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    @State private var showVolumeSlider = false
    @State private var volumeValue: Double = 0.5

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                // Audio Actions
                ActionButton(
                    title: "Chime",
                    icon: "bell.fill",
                    color: .blue
                ) {
                    Task { try? await viewModel.client.playChime(.done) }
                }

                ActionButton(
                    title: "Volume",
                    icon: volumeIcon,
                    color: .indigo
                ) {
                    showVolumeSlider.toggle()
                }

                ActionButton(
                    title: "Mute",
                    icon: "speaker.slash.fill",
                    color: .orange
                ) {
                    Task { try? await viewModel.client.toggleMute() }
                }

                // LED Actions
                ActionButton(
                    title: "Rainbow",
                    icon: "rainbow",
                    color: .purple
                ) {
                    Task { try? await viewModel.client.rainbowLEDs() }
                }

                ActionButton(
                    title: "Pulse",
                    icon: "waveform.path",
                    color: .pink
                ) {
                    Task { try? await viewModel.client.pulseLEDs(color: .blue) }
                }

                ActionButton(
                    title: "LEDs Off",
                    icon: "lightbulb.slash",
                    color: .gray
                ) {
                    Task { try? await viewModel.client.clearLEDs() }
                }

                // Display Actions
                ActionButton(
                    title: "Sleep",
                    icon: "moon.fill",
                    color: .cyan
                ) {
                    Task { try? await viewModel.client.blankDisplay() }
                }

                ActionButton(
                    title: "Wake",
                    icon: "sun.max.fill",
                    color: .yellow
                ) {
                    Task { try? await viewModel.client.unblankDisplay() }
                }

                // Assistant
                ActionButton(
                    title: "Assistant",
                    icon: "waveform.circle.fill",
                    color: .green
                ) {
                    Task { try? await viewModel.client.toggleAssistantListening() }
                }
            }
        }
        .sheet(isPresented: $showVolumeSlider) {
            VolumeControlSheet(viewModel: viewModel)
                .presentationDetents([.height(200)])
        }
    }

    private var volumeIcon: String {
        if volumeValue == 0 { return "speaker.slash.fill" }
        if volumeValue < 0.33 { return "speaker.fill" }
        if volumeValue < 0.66 { return "speaker.wave.1.fill" }
        return "speaker.wave.3.fill"
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            triggerHaptic()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }

    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

struct VolumeControlSheet: View {
    let viewModel: DeviceViewModel

    @State private var volume: Double = 0.5
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(Int(volume * 100))%")
                    .font(.title)
                    .fontWeight(.semibold)

                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: $volume, in: 0...1) { editing in
                        if !editing {
                            Task {
                                // setVolume expects 0-1 range
                                try? await viewModel.client.setVolume(Float(volume))
                            }
                        }
                    }
                    Image(systemName: "speaker.wave.3.fill")
                }
                .padding(.horizontal)

                HStack(spacing: 20) {
                    Button("Mute") {
                        volume = 0
                        Task { try? await viewModel.client.setMute(true) }
                    }
                    .buttonStyle(.bordered)

                    Button("50%") {
                        volume = 0.5
                        Task { try? await viewModel.client.setVolume(0.5) }
                    }
                    .buttonStyle(.bordered)

                    Button("Max") {
                        volume = 1.0
                        Task { try? await viewModel.client.setVolume(1.0) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Volume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            // Get initial volume from home view data if available
            if case .home(let data) = viewModel.currentView {
                volume = Double(data.volumeLevel) / 100.0
            }
        }
    }
}

#Preview {
    QuickActionsView()
        .padding()
        .environment(DeviceViewModel())
}
