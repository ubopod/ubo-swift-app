//
//  WatchExtraViews.swift
//  ubo Watch App
//
//  watchOS counterparts to the iOS Render / Instruction / Prompt views,
//  trimmed for the smaller screen.
//

import SwiftUI
import UboSwift

// MARK: - Render View

struct WatchRenderView: View {
    let data: RenderViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        Group {
            switch data.kind {
            case .qrCode:
                WatchQRView(payload: extractString("data", "url", "payload"), title: data.title)
            case .qrCodeCarousel:
                WatchQRCarousel(payloads: extractList("items", "urls"), title: data.title)
            case .textViewer:
                WatchTextViewer(text: extractString("text", "content", "body"), title: data.title)
            case .imageViewer:
                WatchImageViewer(data: extractBytes("data", "image"), title: data.title)
            case .status:
                WatchStatusView(text: extractString("text", "status", "message"), title: data.title, icon: extractString("icon"))
            case .frameStream:
                WatchFrameStream(streamId: data.streamId, title: data.title)
            case .unknown(let raw):
                Text("Unknown kind: \(raw)").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func extractString(_ keys: String...) -> String {
        for key in keys {
            if case .string(let s) = data.props[key] { return s }
        }
        return ""
    }

    private func extractBytes(_ keys: String...) -> Data? {
        for key in keys {
            if case .bytes(let d) = data.props[key] { return d }
        }
        return nil
    }

    private func extractList(_ keys: String...) -> [String] {
        for key in keys {
            if case .list(let values) = data.props[key] {
                return values.compactMap {
                    if case .string(let s) = $0 { return s } else { return nil }
                }
            }
        }
        return []
    }
}

// Note: watchOS does not include CoreImage's QR generator in this SDK
// configuration. Watch users see the payload as text (small) — for actual
// scanning use the iPhone counterpart.
private struct WatchQRView: View {
    let payload: String
    let title: String

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if !title.isEmpty {
                    markupText(title).font(.caption).fontWeight(.semibold)
                }
                Image(systemName: "qrcode")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(payload)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Scan from iPhone")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct WatchQRCarousel: View {
    let payloads: [String]
    let title: String
    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: 6) {
            if !title.isEmpty {
                Text(title).font(.caption).fontWeight(.semibold)
            }
            if payloads.isEmpty {
                Text("No QR data").font(.caption2).foregroundStyle(.secondary)
            } else {
                TabView(selection: $index) {
                    ForEach(Array(payloads.enumerated()), id: \.offset) { (i, payload) in
                        VStack(spacing: 4) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text(payload)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page)
            }
        }
        .padding(.horizontal, 6)
    }
}

private struct WatchTextViewer: View {
    let text: String
    let title: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if !title.isEmpty {
                    markupText(title).font(.caption).fontWeight(.semibold)
                }
                markupText(text)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
        }
    }
}

private struct WatchImageViewer: View {
    let data: Data?
    let title: String

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if !title.isEmpty {
                    markupText(title).font(.caption).fontWeight(.semibold)
                }
                if let bytes = data, let image = UIImage(data: bytes) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Text("No image").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

private struct WatchStatusView: View {
    let text: String
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: WatchSymbolMapper.systemName(for: icon))
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            if !title.isEmpty {
                Text(title).font(.caption).fontWeight(.semibold)
            }
            if !text.isEmpty {
                markupText(text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 6)
    }
}

private struct WatchFrameStream: View {
    let streamId: String
    let title: String
    @Environment(DeviceViewModel.self) private var viewModel
    @State private var image: UIImage?
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 6) {
            if !title.isEmpty {
                Text(title).font(.caption).fontWeight(.semibold)
            }
            ZStack {
                Rectangle().fill(Color.black).aspectRatio(1, contentMode: .fit)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .cornerRadius(8)
        }
        .task(id: streamId) {
            task?.cancel()
            task = Task { @MainActor in
                let stream = await viewModel.client.frameStream(streamId: streamId)
                do {
                    for try await frame in stream {
                        if Task.isCancelled { break }
                        if let img = WatchRGBDecoder.image(from: frame.data, width: frame.width, height: frame.height) {
                            image = img
                        }
                    }
                } catch {}
            }
            await task?.value
        }
        .onDisappear { task?.cancel(); task = nil }
    }
}

// MARK: - Instruction View

struct WatchInstructionView: View {
    let data: InstructionViewData
    @State private var remaining: Int = 0
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: WatchSymbolMapper.systemName(for: data.icon))
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                if !data.title.isEmpty {
                    markupText(data.title).font(.caption).fontWeight(.semibold)
                }
                if !data.instruction.isEmpty {
                    markupText(data.instruction)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if data.spinner {
                    ProgressView()
                }
                if !data.progressText.isEmpty {
                    markupText(data.progressText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                if data.timeoutSeconds > 0 {
                    Text("\(remaining)s")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                if !data.footerText.isEmpty {
                    markupText(data.footerText)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 6)
        }
        .onAppear {
            guard data.timeoutSeconds > 0 else { return }
            remaining = data.timeoutSeconds
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
                Task { @MainActor in
                    if remaining > 0 { remaining -= 1 } else { t.invalidate() }
                }
            }
        }
        .onDisappear { timer?.invalidate(); timer = nil }
    }
}

// MARK: - Prompt View

struct WatchPromptView: View {
    let data: PromptViewData
    @Environment(DeviceViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: WatchSymbolMapper.systemName(for: data.icon))
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                if !data.title.isEmpty {
                    markupText(data.title).font(.caption).fontWeight(.semibold)
                }
                if !data.prompt.isEmpty {
                    markupText(data.prompt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if data.items.isEmpty {
                    Button("Dismiss") {
                        Task { try? await viewModel.client.goBack() }
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                } else {
                    ForEach(data.items, id: \.key) { item in
                        Button {
                            Task { try? await viewModel.client.selectMenuItem(label: item.label) }
                        } label: {
                            markupText(item.label.isEmpty ? item.key : item.label)
                                .font(.caption2)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Helpers

enum WatchRGBDecoder {
    static func image(from data: Data, width: Int, height: Int) -> UIImage? {
        guard width > 0, height > 0, data.count >= width * height * 3 else { return nil }
        let bytesPerRow = width * 3
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

enum WatchSymbolMapper {
    static func systemName(for icon: String) -> String {
        switch icon.lowercased() {
        case "info", "󰋼": return "info.circle"
        case "warning", "alert", "󰀦": return "exclamationmark.triangle"
        case "error", "fail", "failure": return "xmark.circle"
        case "success", "ok", "check", "checkmark", "󰄬": return "checkmark.circle"
        case "wifi", "󰖩": return "wifi"
        case "ssh", "󰣀": return "terminal"
        case "settings", "gear", "󰒓": return "gear"
        case "power", "󰐥": return "power"
        default: return "circle"
        }
    }
}
