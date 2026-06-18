//
//  ChatDeviceView.swift
//  ubo-swift-app
//
//  Renders `ChatViewData` — the assistant conversation overlay. The core
//  precomputes every bubble (alignment, colors, waveform, playing state) in
//  `ChatBubbleData`, so this view only draws what it's told. Chat is
//  voice-only for now (no text composer); audio bubbles are tapped to toggle
//  playback, mirroring the device's L1/L2/L3 button binding.
//

import SwiftUI
import UboSwift

struct ChatDeviceView: View {
    let data: ChatViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(data.bubbles) { bubble in
                        ChatBubbleRow(bubble: bubble) {
                            Task { try? await viewModel.client.toggleChatAudio(messageId: bubble.messageId) }
                        }
                        .id(bubble.messageId)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: data.bubbles.last?.messageId) { _, lastId in
                guard let lastId, data.scrollOffset == 0 else { return }
                withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
            }
        }
        .overlay {
            if data.bubbles.isEmpty {
                ContentUnavailableView(
                    "No messages yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start talking to the assistant.")
                )
            }
        }
    }
}

/// A single chat speech bubble — a text bubble or an audio bubble with a
/// waveform. Tapping an audio bubble toggles playback.
private struct ChatBubbleRow: View {
    let bubble: ChatBubbleData
    let onToggleAudio: () -> Void

    private var isUser: Bool { bubble.alignment == "right" }
    private var isAudio: Bool { bubble.kind == "audio" }
    private var foreground: Color { Color(hex: bubble.color) ?? .white }
    private var background: Color { Color(hex: bubble.backgroundColor) ?? Color(white: 0.18) }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            Group {
                if isAudio {
                    Button(action: onToggleAudio) {
                        bubbleContent
                    }
                    .buttonStyle(.plain)
                } else {
                    bubbleContent
                }
            }
            .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        HStack(spacing: 8) {
            if isAudio {
                Image(systemName: bubble.isPlaying ? "pause.fill" : "play.fill")
                    .font(.footnote)
                    .foregroundStyle(foreground)
                Waveform(bars: bubble.waveform, color: foreground, isPlaying: bubble.isPlaying)
            } else {
                Text(bubble.text)
                    .foregroundStyle(foreground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Static bar visualization for an audio bubble. `isPlaying` only changes
/// opacity (no animation) so the rendered frame stays deterministic — matching
/// the other clients.
private struct Waveform: View {
    let bars: [Float]
    let color: Color
    let isPlaying: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: max(4, CGFloat(min(1, max(0, value))) * 28))
            }
        }
        .frame(height: 28)
        .frame(minWidth: 120)
        .opacity(isPlaying ? 1 : 0.45)
    }
}
