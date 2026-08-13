//
//  RenderDeviceView.swift
//  ubo-swift-app
//
//  Renders the sub-kinds of `RenderViewData` (qr_code, qr_code_carousel,
//  text_viewer, image_viewer, status, frame_stream, readings) emitted by
//  the Python core. Mirrors the Web UI's RenderView sub-kind switch.
//

import UboAppKit
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UboSwift

struct RenderDeviceView: View {
    let data: RenderViewData
    @Environment(DeviceViewModel.self) private var viewModel

    /// `.bottomBar` exists only on iOS; macOS/tvOS fall back to the default
    /// toolbar slot. (The shared shell replaces this UI on those platforms.)
    private var actionToolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .bottomBar
        #else
        .automatic
        #endif
    }

    var body: some View {
        Group {
            switch data.kind {
            case .qrCode:
                QRCodeRenderView(data: data)
            case .qrCodeCarousel:
                QRCodeCarouselRenderView(data: data)
            case .textViewer:
                TextViewerRenderView(data: data)
            case .imageViewer:
                ImageViewerRenderView(data: data)
            case .status:
                StatusRenderView(data: data)
            case .frameStream:
                FrameStreamRenderView(streamId: data.streamId, title: data.title)
            case .readings:
                ReadingsRenderView(data: data)
            case .unknown(let raw):
                UnknownKindView(kind: raw, data: data)
            }
        }
        .toolbar {
            if !data.items.isEmpty {
                ToolbarItem(placement: actionToolbarPlacement) {
                    HStack(spacing: 12) {
                        ForEach(data.items, id: \.key) { item in
                            Button(item.label.isEmpty ? item.key : item.label) {
                                viewModel.perform("selectMenuItem") { try await viewModel.selectMenuItem(item) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - QR Code

struct QRCodeRenderView: View {
    let data: RenderViewData

    /// The QR-encoded value. Every producer (tailscale/rpi-connect/vscode/
    /// hermes setup services) sends this under `value` — never `data`,
    /// `url`, or `payload`, which is what this used to check for.
    private var value: String {
        if case .string(let s) = data.props["value"] { return s }
        return ""
    }

    /// Tappable text under the QR, matching the Web UI's `QRCodePage`:
    /// `label` if the producer set one, else the raw `value`.
    private var label: String {
        if case .string(let s) = data.props["label"], !s.isEmpty { return s }
        return value
    }

    /// A code the user types after scanning (e.g. an OAuth device code) —
    /// kept out of the link since it isn't part of it.
    private var caption: String? {
        if case .string(let s) = data.props["caption"], !s.isEmpty { return s }
        return nil
    }

    var body: some View {
        VStack(spacing: 16) {
            if !data.title.isEmpty {
                markupText(data.title)
                    .font(.headline)
            }

            if let image = QRCodeImage.generate(from: value) {
                image
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 360)
                    .padding()
                    .background(.white)
                    .cornerRadius(12)
            } else {
                Text("Empty QR payload")
                    .foregroundStyle(.secondary)
            }

            if !label.isEmpty {
                LinkifiedText(text: label, font: .caption.monospaced())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let caption {
                Text(caption)
                    .font(.title3.monospaced().weight(.semibold))
                    .tracking(1)
            }
        }
        .padding()
    }
}

struct QRCodeCarouselRenderView: View {
    let data: RenderViewData
    @State private var index: Int = 0

    /// Parallel arrays, matching the Web UI's `QRCodeCarousel`: `values`
    /// are the QR-encoded strings, `labels` the (optionally shorter) text
    /// shown under each one — never `items`/`urls`, which no producer
    /// (the Docker port carousel is the only one) has ever sent.
    private var values: [String] {
        if case .list(let items) = data.props["values"] {
            return items.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        }
        return []
    }

    private var labels: [String] {
        if case .list(let items) = data.props["labels"] {
            return items.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        }
        return []
    }

    var body: some View {
        VStack(spacing: 12) {
            if !data.title.isEmpty {
                markupText(data.title).font(.headline)
            }
            if values.isEmpty {
                Text("No QR payloads")
                    .foregroundStyle(.secondary)
            } else {
                TabView(selection: $index) {
                    ForEach(Array(values.enumerated()), id: \.offset) { (i, value) in
                        let label = (i < labels.count && !labels[i].isEmpty) ? labels[i] : value
                        VStack {
                            if let image = QRCodeImage.generate(from: value) {
                                image
                                    .interpolation(.none)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: 360)
                                    .padding()
                                    .background(.white)
                                    .cornerRadius(12)
                            }
                            LinkifiedText(text: label, font: .caption.monospaced())
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .tag(i)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                #endif
                .frame(maxHeight: 480)
            }
        }
        .padding()
    }
}

// MARK: - Text Viewer

struct TextViewerRenderView: View {
    let data: RenderViewData

    private var text: String {
        if case .string(let s) = data.props["text"] { return s }
        if case .string(let s) = data.props["content"] { return s }
        if case .string(let s) = data.props["body"] { return s }
        return ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !data.title.isEmpty {
                    markupText(data.title)
                        .font(.headline)
                }
                markupText(text)
                    .font(.body.monospaced())
                    #if !os(tvOS)
                    .textSelection(.enabled)
                    #endif
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
}

// MARK: - Image Viewer

struct ImageViewerRenderView: View {
    let data: RenderViewData
    @Environment(DeviceViewModel.self) private var viewModel
    @State private var currentImage: PlatformImage?
    @State private var streamTask: Task<Void, Never>?

    // Props carry only the geometry (width/height, unused here since the
    // image is shown at its natural size) — the pixels arrive as
    // frame-stream events, exactly like FrameStreamRenderView, so an image
    // inline in props doesn't put a multi-megabyte payload on the store
    // stream that every client (including MCU ones) would have to swallow.
    // Mirrors the Web UI's `ImageViewer` component.
    var body: some View {
        VStack(spacing: 12) {
            if !data.title.isEmpty {
                markupText(data.title).font(.headline)
            }
            if let image = currentImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                #endif
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .padding()
        .task(id: data.streamId) {
            streamTask?.cancel()
            streamTask = Task { @MainActor in
                let stream = await viewModel.client.frameStream(streamId: data.streamId)
                do {
                    for try await frame in stream {
                        if Task.isCancelled { break }
                        if let image = RGBFrameDecoder.image(from: frame.data, width: frame.width, height: frame.height) {
                            currentImage = image
                        }
                    }
                } catch {
                    // Stream ended; UI will keep last frame.
                }
            }
            await streamTask?.value
        }
        .onDisappear {
            streamTask?.cancel()
            streamTask = nil
        }
    }
}

// MARK: - Readings

/// A sensor's live readings — one row of `label: value unit` per entity.
/// Entities with a natural range (per `SensorDisplay`, keyed by the same
/// Home Assistant `device_class` the Dashboard's sensor tiles use) render
/// as a grid of `DashboardGauge`s; the rest render as plain stat rows,
/// since a meter implies a limit and inventing one for a boundless reading
/// (a VOC index, a gas resistance) would be a lie.
struct ReadingsRenderView: View {
    let data: RenderViewData

    private struct Row: Identifiable {
        let id: Int
        let label: String
        let value: String
        let unit: String?
        let spec: SensorDisplaySpec
        /// The parsed numeric value, only when `spec.range` also exists —
        /// both are required to plot a gauge fraction.
        let meteredValue: Float?
    }

    private var rows: [Row] {
        let labels = data.stringListProp("labels")
        let values = data.stringListProp("values")
        let units = data.stringListProp("units")
        let keys = data.stringListProp("keys")
        let deviceClasses = data.stringListProp("device_classes")
        return labels.indices.map { index in
            let value = index < values.count ? values[index] : ""
            let unit = index < units.count ? units[index] : ""
            let key = index < keys.count ? keys[index] : ""
            let deviceClass = index < deviceClasses.count && !deviceClasses[index].isEmpty
                ? deviceClasses[index] : nil
            let spec = SensorDisplay.spec(forKey: key, deviceClass: deviceClass)
            return Row(
                id: index,
                label: labels[index],
                value: value,
                unit: unit.isEmpty ? nil : unit,
                spec: spec,
                meteredValue: spec.range != nil ? Float(value) : nil
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !data.title.isEmpty {
                    markupText(data.title)
                        .font(.title2.bold())
                }

                let allRows = rows
                if allRows.isEmpty {
                    Text("No readings yet")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    let metered = allRows.filter { $0.meteredValue != nil }
                    let plain = allRows.filter { $0.meteredValue == nil }

                    if !metered.isEmpty {
                        VStack(spacing: 16) {
                            ForEach(Array(metered.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                                HStack(spacing: 16) {
                                    ForEach(row) { gaugeTile($0) }
                                    if row.count < 3 { Spacer(minLength: 0) }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if !plain.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(plain) { row in
                                DashboardStat(label: row.label, value: row.value, unit: row.unit, icon: row.spec.icon)
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.regularMaterial)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func gaugeTile(_ row: Row) -> some View {
        // meteredValue is non-nil only when spec.range is too (see `rows`).
        if let range = row.spec.range, let value = row.meteredValue {
            VStack(spacing: 6) {
                DashboardGauge(
                    fraction: SensorDisplay.rangeFraction(value, range: range),
                    valueText: row.value,
                    unit: row.unit,
                    icon: row.spec.icon,
                    color: DashboardColor.gaugeAccent
                )
                .frame(width: 90, height: 90)
                Text(row.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private extension RenderViewData {
    /// Pull a list-of-strings prop (`labels`/`values`/`units`/`keys`/
    /// `device_classes`), matching the server's `RenderProps` shape.
    func stringListProp(_ key: String) -> [String] {
        guard case .list(let items)? = props[key] else { return [] }
        return items.compactMap {
            if case .string(let s) = $0 { return s } else { return nil }
        }
    }
}

#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

// MARK: - Status

struct StatusRenderView: View {
    let data: RenderViewData

    private var statusText: String {
        if case .string(let s) = data.props["text"] { return s }
        if case .string(let s) = data.props["status"] { return s }
        if case .string(let s) = data.props["message"] { return s }
        return ""
    }

    private var iconName: String {
        if case .string(let s) = data.props["icon"] { return s }
        return "info.circle"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: UboSymbolMapper.systemName(for: iconName))
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            if !data.title.isEmpty {
                markupText(data.title).font(.title3.bold())
            }
            if !statusText.isEmpty {
                markupText(statusText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Frame Stream

struct FrameStreamRenderView: View {
    let streamId: String
    let title: String
    @Environment(DeviceViewModel.self) private var viewModel
    @State private var currentImage: PlatformImage?
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 12) {
            if !title.isEmpty {
                markupText(title).font(.headline)
            }
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(1, contentMode: .fit)
                if let image = currentImage {
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                    #else
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                    #endif
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .cornerRadius(12)
            Text("Stream: \(streamId)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
        .task(id: streamId) {
            streamTask?.cancel()
            streamTask = Task { @MainActor in
                let stream = await viewModel.client.frameStream(streamId: streamId)
                do {
                    for try await frame in stream {
                        if Task.isCancelled { break }
                        if let image = RGBFrameDecoder.image(from: frame.data, width: frame.width, height: frame.height) {
                            currentImage = image
                        }
                    }
                } catch {
                    // Stream ended; UI will keep last frame.
                }
            }
            await streamTask?.value
        }
        .onDisappear {
            streamTask?.cancel()
            streamTask = nil
        }
    }
}

// MARK: - Unknown fallback

struct UnknownKindView: View {
    let kind: String
    let data: RenderViewData

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Unknown render kind")
                .font(.headline)
            Text("kind: \(kind)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if !data.title.isEmpty {
                markupText(data.title)
                    .font(.body)
            }
        }
        .padding()
    }
}

// MARK: - Helpers

enum QRCodeImage {
    static func generate(from string: String) -> Image? {
        guard !string.isEmpty else { return nil }
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        #if os(iOS)
        return Image(uiImage: UIImage(cgImage: cgImage))
        #elseif os(macOS)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let nsImage = NSImage(size: size)
        nsImage.addRepresentation(rep)
        return Image(nsImage: nsImage)
        #else
        return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    }
}

enum RGBFrameDecoder {
    /// Decode a packed RGB byte buffer (3 bytes per pixel) into a platform image.
    static func image(from data: Data, width: Int, height: Int) -> PlatformImage? {
        guard width > 0, height > 0, data.count >= width * height * 3 else { return nil }
        let bytesPerPixel = 3
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8 * bytesPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }

        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #elseif os(macOS)
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
}

