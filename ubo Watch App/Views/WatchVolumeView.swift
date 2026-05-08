//
//  WatchVolumeView.swift
//  ubo Watch App
//
//  Dedicated volume screen reachable from `WatchActionsView` → "Volume".
//  Bound to the digital crown so users can sweep volume on the Pi without
//  the crown being globally hijacked elsewhere in the app. Live-syncs
//  `state.audio.playback_volume` so hardware-button changes from the Pi
//  show up immediately.
//

import SwiftUI
import UboSwift

struct WatchVolumeView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    @State private var value: Double = 0
    @State private var isEditing: Bool = false
    @State private var pendingDispatch: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isMuted ? Color.secondary : Color.accentColor)

            Text("\(Int(value * 100))%")
                .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(isMuted ? Color.secondary : Color.primary)

            ProgressView(value: value)
                .tint(isMuted ? Color.secondary : Color.accentColor)
                .padding(.horizontal, 4)

            Button {
                Task { try? await viewModel.client.toggleMute() }
            } label: {
                Label(isMuted ? "Unmute" : "Mute",
                      systemImage: isMuted ? "speaker.fill" : "speaker.slash.fill")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Volume")
        .focusable()
        .digitalCrownRotation(
            $value,
            from: 0,
            through: 1,
            by: 0.05,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear { syncFromDevice() }
        .onChange(of: viewModel.cachedPlaybackVolume) { _, newValue in
            guard !isEditing, let v = newValue else { return }
            value = Double(v)
        }
        .onChange(of: value) { oldValue, newValue in
            // Crown rotation drives this; mark as editing and debounce the
            // dispatch so we don't flood the gRPC channel.
            guard abs(newValue - oldValue) > 0.0001 else { return }
            isEditing = true
            pendingDispatch?.cancel()
            pendingDispatch = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                let target = Float(newValue)
                try? await viewModel.client.setVolume(target)
                isEditing = false
            }
        }
        .onDisappear {
            pendingDispatch?.cancel()
            pendingDispatch = nil
        }
    }

    private func syncFromDevice() {
        if let v = viewModel.cachedPlaybackVolume {
            value = Double(v)
        }
    }

    private var isMuted: Bool {
        viewModel.cachedIsPlaybackMute ?? false
    }

    private var icon: String {
        if isMuted || value == 0 { return "speaker.slash.fill" }
        if value < 0.34 { return "speaker.fill" }
        if value < 0.67 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }
}

#Preview {
    NavigationStack {
        WatchVolumeView()
            .environment(DeviceViewModel())
    }
}
