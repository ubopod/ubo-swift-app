//
//  WatchExtraViews.swift
//  ubo Watch App
//
//  watchOS counterparts to the iOS Render / Instruction / Prompt views,
//  trimmed for the smaller screen.
//

import UboAppKit
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
                WatchQRView(value: extractString("value"), title: data.title, caption: extractString("caption"))
            case .qrCodeCarousel:
                WatchQRCarousel(values: extractList("values"), title: data.title)
            case .textViewer:
                WatchTextViewer(text: extractString("text", "content", "body"), title: data.title)
            case .imageViewer:
                WatchImageViewer(streamId: data.streamId, title: data.title)
            case .status:
                WatchStatusView(text: extractString("text", "status", "message"), title: data.title, icon: extractString("icon"))
            case .frameStream:
                WatchFrameStream(streamId: data.streamId, title: data.title)
            case .readings:
                WatchReadingsView(
                    labels: extractList("labels"),
                    values: extractList("values"),
                    units: extractList("units"),
                    keys: extractList("keys"),
                    deviceClasses: extractList("device_classes"),
                    title: data.title
                )
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

// A real scannable QR bitmap, not a placeholder icon — the watch screen is
// close enough in size to the pod's own 1.56" display and the ESP32
// display, both of which render actual QR codes at this scale. No
// hyperlink/value text underneath: there's no browser here to act on it,
// so it would just cost the QR the room it needs (same reasoning as the
// pod GUI's QRCodeRenderPage, which drops URL-shaped labels for the same
// reason). `caption` is kept since it's not a link — it's a code the user
// types after scanning (e.g. an OAuth device code).
private struct WatchQRView: View {
    let value: String
    let title: String
    let caption: String

    var body: some View {
        VStack(spacing: 6) {
            if !title.isEmpty {
                markupText(title).font(.caption).fontWeight(.semibold)
            }
            if let image = QRCodeImage.generate(from: value) {
                image
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .padding(4)
                    .background(.white)
                    .cornerRadius(8)
            } else {
                Text("Empty QR payload")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        }
        .padding(.horizontal, 6)
    }
}

private struct WatchQRCarousel: View {
    let values: [String]
    let title: String
    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: 6) {
            if !title.isEmpty {
                Text(title).font(.caption).fontWeight(.semibold)
            }
            if values.isEmpty {
                Text("No QR data").font(.caption2).foregroundStyle(.secondary)
            } else {
                TabView(selection: $index) {
                    ForEach(Array(values.enumerated()), id: \.offset) { (i, value) in
                        Group {
                            if let image = QRCodeImage.generate(from: value) {
                                image
                                    .interpolation(.none)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .padding(4)
                                    .background(.white)
                                    .cornerRadius(8)
                            }
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
    let streamId: String
    let title: String
    @Environment(DeviceViewModel.self) private var viewModel
    @State private var image: UIImage?
    @State private var task: Task<Void, Never>?

    // Props carry only geometry — the pixels arrive as frame-stream events,
    // exactly like WatchFrameStream, so an image inline in props doesn't put
    // a multi-megabyte payload on the store stream. Mirrors the iOS
    // ImageViewerRenderView / Web UI's ImageViewer.
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if !title.isEmpty {
                    markupText(title).font(.caption).fontWeight(.semibold)
                }
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, 6)
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

private struct WatchStatusView: View {
    let text: String
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: UboSymbolMapper.systemName(for: icon))
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

private struct WatchReadingsView: View {
    let labels: [String]
    let values: [String]
    let units: [String]
    let keys: [String]
    let deviceClasses: [String]
    let title: String

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if !title.isEmpty {
                    markupText(title).font(.caption).fontWeight(.semibold)
                }
                if labels.isEmpty {
                    Text("No readings yet").font(.caption2).foregroundStyle(.secondary)
                } else {
                    ForEach(labels.indices, id: \.self) { index in
                        row(at: index)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private func row(at index: Int) -> some View {
        let label = labels[index]
        let value = index < values.count ? values[index] : ""
        let unit = index < units.count ? units[index] : ""
        let key = index < keys.count ? keys[index] : ""
        let deviceClass = index < deviceClasses.count && !deviceClasses[index].isEmpty ? deviceClasses[index] : nil
        let spec = WatchSensorDisplay.spec(forKey: key, deviceClass: deviceClass)

        if let range = spec.range, let floatValue = Float(value) {
            WatchCompactGauge(
                fraction: WatchSensorDisplay.rangeFraction(floatValue, range: range),
                valueText: value,
                label: label,
                color: .blue
            )
        } else {
            HStack(spacing: 6) {
                Image(systemName: spec.icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(value + (unit.isEmpty ? "" : " \(unit)"))
                    .font(.caption2.weight(.semibold))
            }
        }
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
                Image(systemName: UboSymbolMapper.systemName(for: data.icon))
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
                Image(systemName: UboSymbolMapper.systemName(for: data.icon))
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
                        viewModel.perform("goBack") { try await viewModel.client.goBack() }
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                } else {
                    ForEach(data.items, id: \.key) { item in
                        Button {
                            viewModel.perform("selectMenuItem") { try await viewModel.selectMenuItem(item) }
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

