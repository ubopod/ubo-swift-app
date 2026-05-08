//
//  PromptDeviceView.swift
//  ubo-swift-app
//
//  Renders `PromptViewData` — confirmation/decision screens (Yes/Cancel,
//  Connect/Delete, etc.). Each item dispatches its label back to the core
//  via menuChooseByLabel.
//

import SwiftUI
import UboSwift

struct PromptDeviceView: View {
    let data: PromptViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image(systemName: SymbolMapper.systemName(for: data.icon))
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)

            if !data.title.isEmpty {
                markupText(data.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }

            if !data.prompt.isEmpty {
                markupText(data.prompt)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)

            if data.items.isEmpty {
                Button("Dismiss") {
                    Task { try? await viewModel.client.goBack() }
                }
                .buttonStyle(.bordered)
            } else {
                VStack(spacing: 10) {
                    ForEach(data.items, id: \.key) { item in
                        Button {
                            triggerHaptic()
                            Task {
                                try? await viewModel.client.selectMenuItem(label: item.label)
                            }
                        } label: {
                            markupText(item.label.isEmpty ? item.key : item.label)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}
