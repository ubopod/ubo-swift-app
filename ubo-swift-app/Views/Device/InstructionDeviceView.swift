//
//  InstructionDeviceView.swift
//  ubo-swift-app
//
//  Renders `InstructionViewData` — informational/wait screens shown while
//  the device is awaiting an external event (IR pulse, QR scan, button
//  press on hardware). Optionally shows a spinner and counts down a
//  per-instruction timeout.
//

import SwiftUI
import UboSwift

struct InstructionDeviceView: View {
    let data: InstructionViewData
    @State private var remaining: Int = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image(systemName: SymbolMapper.systemName(for: data.icon))
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            if !data.title.isEmpty {
                markupText(data.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }

            if !data.instruction.isEmpty {
                markupText(data.instruction)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if data.spinner {
                ProgressView()
                    .controlSize(.large)
            }

            if !data.progressText.isEmpty {
                markupText(data.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if data.timeoutSeconds > 0 {
                Text("\(remaining)s remaining")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            if !data.footerText.isEmpty {
                markupText(data.footerText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 24)
            }
        }
        .padding()
        .onAppear { startCountdownIfNeeded() }
        .onDisappear { stopCountdown() }
    }

    private func startCountdownIfNeeded() {
        guard data.timeoutSeconds > 0 else { return }
        remaining = data.timeoutSeconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            Task { @MainActor in
                if remaining > 0 {
                    remaining -= 1
                } else {
                    t.invalidate()
                }
            }
        }
    }

    private func stopCountdown() {
        timer?.invalidate()
        timer = nil
    }
}
