//
//  QuickActionsView.swift
//  ubo-swift-app
//
//  Quick-access tile grid for one-shot device actions (chime, mute, LED
//  presets, display sleep/wake, assistant). Volume lives in
//  Settings → Audio so the slider can be live-bound to
//  `state.audio.playback_volume` rather than the stale local @State this
//  view used to host.
//

import UboAppKit
import SwiftUI
import UboSwift

struct QuickActionsView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ActionButton(
                    title: "Chime",
                    icon: "bell.fill",
                    color: .blue
                ) {
                    viewModel.perform("playChime") { try await viewModel.client.playChime(.done) }
                }

                ActionButton(
                    title: "Mute",
                    icon: "speaker.slash.fill",
                    color: .orange
                ) {
                    viewModel.perform("toggleMute") { try await viewModel.client.toggleMute() }
                }

                ActionButton(
                    title: "Rainbow",
                    icon: "rainbow",
                    color: .purple
                ) {
                    viewModel.perform("rainbowLEDs") { try await viewModel.client.rainbowLEDs() }
                }

                ActionButton(
                    title: "Pulse",
                    icon: "waveform.path",
                    color: .pink
                ) {
                    viewModel.perform("pulseLEDs") { try await viewModel.client.pulseLEDs(color: .blue) }
                }

                ActionButton(
                    title: "LEDs Off",
                    icon: "lightbulb.slash",
                    color: .gray
                ) {
                    viewModel.perform("clearLEDs") { try await viewModel.client.clearLEDs() }
                }

                ActionButton(
                    title: "Sleep",
                    icon: "moon.fill",
                    color: .cyan
                ) {
                    viewModel.perform("blankDisplay") { try await viewModel.client.blankDisplay() }
                }

                ActionButton(
                    title: "Wake",
                    icon: "sun.max.fill",
                    color: .yellow
                ) {
                    viewModel.perform("unblankDisplay") { try await viewModel.client.unblankDisplay() }
                }

                ActionButton(
                    title: "Assistant",
                    icon: "waveform.circle.fill",
                    color: .green
                ) {
                    viewModel.perform("toggleAssistantListening") { try await viewModel.client.toggleAssistantListening() }
                }
            }
        }
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
        #if !os(tvOS)
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
        #endif
    }

    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

#Preview {
    QuickActionsView()
        .padding()
        .environment(DeviceViewModel())
}
