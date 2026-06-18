//
//  WatchChatView.swift
//  ubo Watch App
//
//  Slim watch renderer for `ChatViewData` — the assistant conversation. The
//  core precomputes every bubble (alignment, colors, waveform, playing state),
//  so this view only draws what it's told. Voice-only: audio bubbles are
//  tapped to toggle playback.
//

import SwiftUI
import UboSwift

struct WatchChatView: View {
    let data: ChatViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        if data.bubbles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("No messages yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(data.bubbles) { bubble in
                            WatchChatBubbleRow(bubble: bubble) {
                                Task { try? await viewModel.client.toggleChatAudio(messageId: bubble.messageId) }
                            }
                            .id(bubble.messageId)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: data.bubbles.last?.messageId) { _, lastId in
                    guard let lastId, data.scrollOffset == 0 else { return }
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }
        }
    }
}

private struct WatchChatBubbleRow: View {
    let bubble: ChatBubbleData
    let onToggleAudio: () -> Void

    private var isUser: Bool { bubble.alignment == "right" }
    private var isAudio: Bool { bubble.kind == "audio" }
    private var foreground: Color { Color(hex: bubble.color) ?? .white }
    private var background: Color { Color(hex: bubble.backgroundColor) ?? Color(white: 0.18) }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 16) }
            content
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 16) }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if isAudio {
                Button(action: onToggleAudio) {
                    HStack(spacing: 6) {
                        Image(systemName: bubble.isPlaying ? "pause.fill" : "play.fill")
                            .font(.caption2)
                        Text("Audio")
                            .font(.caption2)
                    }
                    .foregroundStyle(foreground)
                }
                .buttonStyle(.plain)
            } else {
                Text(bubble.text)
                    .font(.footnote)
                    .foregroundStyle(foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
