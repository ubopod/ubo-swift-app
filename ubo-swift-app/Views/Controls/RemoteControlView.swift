//
//  RemoteControlView.swift
//  ubo-swift-app
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct RemoteControlView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // D-Pad Controls
                dpadControls

                // Side Buttons
                sideButtons

                Spacer()
            }
            .padding()
            .navigationTitle("Remote")
        }
    }

    private var dpadControls: some View {
        VStack(spacing: 0) {
            // Up button
            RemoteButton(systemImage: "chevron.up") {
                Task { try? await viewModel.client.scrollUp() }
            }

            HStack(spacing: 0) {
                // Back button
                RemoteButton(systemImage: "chevron.left") {
                    Task { try? await viewModel.client.goBack() }
                }

                // Home button (center)
                RemoteButton(systemImage: "house.fill", isCenter: true) {
                    Task { try? await viewModel.client.goHome() }
                }

                // Empty space for symmetry (or could add forward)
                RemoteButton(systemImage: "chevron.right", style: .secondary) {
                    // No direct "forward" action, but could be used for something else
                }
                .opacity(0.3)
                .disabled(true)
            }

            // Down button
            RemoteButton(systemImage: "chevron.down") {
                Task { try? await viewModel.client.scrollDown() }
            }
        }
    }

    private var sideButtons: some View {
        VStack(spacing: 16) {
            Text("Side Buttons")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                SideButton(label: "L1") {
                    Task { try? await viewModel.client.pressL1() }
                }

                SideButton(label: "L2") {
                    Task { try? await viewModel.client.pressL2() }
                }

                SideButton(label: "L3") {
                    Task { try? await viewModel.client.pressL3() }
                }
            }
        }
    }
}

struct RemoteButton: View {
    let systemImage: String
    var isCenter: Bool = false
    var style: ButtonStyle = .primary
    let action: () -> Void

    enum ButtonStyle {
        case primary, secondary
    }

    @State private var isPressed = false

    var body: some View {
        Button {
            triggerHaptic()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(isCenter ? .white : .primary)
                .frame(width: buttonSize, height: buttonSize)
                .background {
                    if isCenter {
                        Circle()
                            .fill(Color.accentColor)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
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

    private var buttonSize: CGFloat {
        isCenter ? 80 : 70
    }

    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: isCenter ? .medium : .light)
        generator.impactOccurred()
        #endif
    }
}

struct SideButton: View {
    let label: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            triggerHaptic()
            action()
        } label: {
            Text(label)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 60, height: 44)
                .background {
                    Capsule()
                        .fill(.regularMaterial)
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
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

#Preview {
    RemoteControlView()
        .environment(DeviceViewModel())
}
