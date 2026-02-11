//
//  WatchRemoteView.swift
//  ubo Watch App
//
//  Created by Nathan Perrier on 28/1/2026.
//

import SwiftUI
import UboSwift

struct WatchRemoteView: View {
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 8) {
            Text("Remote")
                .font(.headline)

            // Compact D-Pad
            VStack(spacing: 4) {
                // Up
                WatchRemoteButton(systemImage: "chevron.up") {
                    Task { try? await viewModel.client.scrollUp() }
                }

                HStack(spacing: 4) {
                    // Back
                    WatchRemoteButton(systemImage: "chevron.left") {
                        Task { try? await viewModel.client.goBack() }
                    }

                    // Home
                    WatchRemoteButton(systemImage: "house.fill", isCenter: true) {
                        Task { try? await viewModel.client.goHome() }
                    }

                    // Placeholder
                    Color.clear
                        .frame(width: 40, height: 40)
                }

                // Down
                WatchRemoteButton(systemImage: "chevron.down") {
                    Task { try? await viewModel.client.scrollDown() }
                }
            }

            // Side Buttons
            HStack(spacing: 8) {
                WatchSideButton(label: "L1") {
                    Task { try? await viewModel.client.pressL1() }
                }
                WatchSideButton(label: "L2") {
                    Task { try? await viewModel.client.pressL2() }
                }
                WatchSideButton(label: "L3") {
                    Task { try? await viewModel.client.pressL3() }
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

struct WatchRemoteButton: View {
    let systemImage: String
    var isCenter: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(isCenter ? .title3 : .body)
                .foregroundStyle(isCenter ? .white : .primary)
                .frame(width: 40, height: 40)
                .background {
                    if isCenter {
                        Circle()
                            .fill(Color.accentColor)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct WatchSideButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .frame(width: 36, height: 28)
                .background {
                    Capsule()
                        .fill(.quaternary)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WatchRemoteView()
        .environment(DeviceViewModel())
}
