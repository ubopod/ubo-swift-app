//
//  ShellControlBar.swift
//  ubo-swift-app
//
//  The persistent control row for the TV/desktop shell: back + home, the
//  breadcrumb trail, and the assistant mic. Like the Web UI there are no
//  on-screen L1/L2/L3 buttons. This view is a pure renderer — `TileShellView`
//  owns focus/key handling and passes the currently `focused` element so each
//  control can draw its highlight; the buttons' own actions handle the mouse /
//  Siri-Remote-select path.
//

#if os(tvOS) || os(macOS)
import SwiftUI
import UboSwift

struct ShellControlBar: View {
    let title: String
    let showsBack: Bool
    let focused: ShellFocus?

    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: 16) {
            if showsBack {
                controlButton(.back, systemImage: "chevron.left", accessibility: "Back") {
                    dispatch { try await viewModel.client.goBack() }
                }
            }

            controlButton(.home, systemImage: "house", accessibility: "Home") {
                dispatch { try await viewModel.client.goHome() }
            }

            // Breadcrumb: ancestor crumbs (between Home and the current view),
            // then the current title with its leading glyph — mirroring the
            // Web UI's "Home › … › Current" trail.
            HStack(spacing: 6) {
                ForEach(ancestors) { item in
                    Text(item.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                let split = splitLeadingGlyph(title)
                if let glyph = split.icon {
                    IconView(icon: glyph, size: 20)
                }
                markupText(split.label)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()

            controlButton(
                .mic,
                systemImage: viewModel.isAssistantListening ? "mic.fill" : "mic",
                accessibility: viewModel.isAssistantListening ? "Stop assistant" : "Start assistant",
                tint: viewModel.isAssistantListening ? .red : .primary
            ) {
                Task { await viewModel.toggleAssistantListening() }
            }
        }
        .buttonStyle(.bordered)
        .font(.headline)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private func controlButton(
        _ target: ShellFocus,
        systemImage: String,
        accessibility: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .accessibilityLabel(accessibility)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, lineWidth: focused == target ? 3 : 0)
        )
        // The shell container owns focus; don't let the native engine (tvOS)
        // grab these buttons.
        .focusable(false)
    }

    /// Intermediate crumbs between Home (the leading button) and the current
    /// view (rendered as the bold title), i.e. the stack minus root and leaf.
    private var ancestors: [UboStackItem] {
        let stack = viewModel.stack
        guard stack.count > 1 else { return [] }
        return Array(stack.dropFirst().dropLast())
    }

    private func dispatch(_ work: @escaping () async throws -> Void) {
        Task { try? await work() }
    }
}
#endif
