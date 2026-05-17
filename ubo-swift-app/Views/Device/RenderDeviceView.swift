//
//  RenderDeviceView.swift
//  ubo-swift-app
//
//  Renders the seven sub-kinds of `RenderViewData` (qr_code,
//  qr_code_carousel, text_viewer, image_viewer, status, frame_stream)
//  emitted by the Python core. Mirrors the Web UI's RenderView sub-kind
//  switch.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UboSwift

struct RenderDeviceView: View {
    let data: RenderViewData
    @Environment(DeviceViewModel.self) private var viewModel

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
            case .unknown(let raw):
                UnknownKindView(kind: raw, data: data)
            }
        }
        .toolbar {
            if !data.items.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 12) {
                        ForEach(data.items, id: \.key) { item in
                            Button(item.label.isEmpty ? item.key : item.label) {
                                Task { try? await viewModel.client.selectMenuItem(label: item.label) }
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

    private var payload: String {
        if case .string(let s) = data.props["data"] { return s }
        if case .string(let s) = data.props["url"] { return s }
        if case .string(let s) = data.props["payload"] { return s }
        return ""
    }

    var body: some View {
        VStack(spacing: 16) {
            if !data.title.isEmpty {
                markupText(data.title)
                    .font(.headline)
            }

            if let image = QRCodeImage.generate(from: payload) {
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

            Text(payload)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct QRCodeCarouselRenderView: View {
    let data: RenderViewData
    @State private var index: Int = 0

    private var payloads: [String] {
        if case .list(let values) = data.props["items"] {
            return values.compactMap {
                if case .string(let s) = $0 { return s } else { return nil }
            }
        }
        if case .list(let values) = data.props["urls"] {
            return values.compactMap {
                if case .string(let s) = $0 { return s } else { return nil }
            }
        }
        return []
    }

    var body: some View {
        VStack(spacing: 12) {
            if !data.title.isEmpty {
                markupText(data.title).font(.headline)
            }
            if payloads.isEmpty {
                Text("No QR payloads")
                    .foregroundStyle(.secondary)
            } else {
                TabView(selection: $index) {
                    ForEach(Array(payloads.enumerated()), id: \.offset) { (i, payload) in
                        VStack {
                            if let image = QRCodeImage.generate(from: payload) {
                                image
                                    .interpolation(.none)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: 360)
                                    .padding()
                                    .background(.white)
                                    .cornerRadius(12)
                            }
                            Text(payload)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
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
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
}

// MARK: - Image Viewer

struct ImageViewerRenderView: View {
    let data: RenderViewData

    private var imageData: Data? {
        if case .bytes(let d) = data.props["data"] { return d }
        if case .bytes(let d) = data.props["image"] { return d }
        if case .string(let b64) = data.props["data_base64"] {
            return Data(base64Encoded: b64)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 12) {
            if !data.title.isEmpty {
                markupText(data.title).font(.headline)
            }
            if let bytes = imageData,
               let uiImage = PlatformImage(data: bytes) {
                #if os(iOS)
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                #else
                Image(nsImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                #endif
            } else {
                Text("No image data")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
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
            Image(systemName: SymbolMapper.systemName(for: iconName))
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
                    #if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                    #else
                    Image(nsImage: image)
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

enum SymbolMapper {
    static func systemName(for icon: String) -> String {
        switch icon.lowercased() {
        case "info", "󰋼": return "info.circle"
        case "warning", "alert", "󰀦": return "exclamationmark.triangle"
        case "error", "fail", "failure": return "xmark.circle"
        case "success", "ok", "check", "checkmark", "󰄬": return "checkmark.circle"
        case "wifi", "󰖩": return "wifi"
        case "ssh", "󰣀": return "terminal"
        case "vpn", "󰖂": return "lock.shield"
        case "docker", "󰡨": return "shippingbox"
        case "settings", "gear", "󰒓": return "gear"
        case "power", "󰐥": return "power"
        default: return "circle"
        }
    }
}
