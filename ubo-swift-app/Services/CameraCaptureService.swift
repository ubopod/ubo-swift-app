import AVFoundation
import Foundation

protocol CameraCaptureDelegate: AnyObject {
    func cameraCaptureService(
        _ service: CameraCaptureService,
        didOutputRGBData data: Data,
        width: Int,
        height: Int,
        timestamp: Double
    )
}

final class CameraCaptureService: NSObject {
    weak var delegate: CameraCaptureDelegate?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ubo.camera.session")
    private let processingQueue = DispatchQueue(label: "com.ubo.camera.processing")

    private let targetSize = 240
    private let minFrameInterval: TimeInterval = 1.0 / 12.0 // ~12 FPS
    private var lastFrameTime: TimeInterval = 0

    // Pre-allocated RGB buffer for efficiency
    private var rgbBuffer: UnsafeMutablePointer<UInt8>?
    private let rgbBufferSize: Int

    private(set) var isRunning = false

    override init() {
        rgbBufferSize = 240 * 240 * 3
        super.init()
        rgbBuffer = .allocate(capacity: rgbBufferSize)
    }

    deinit {
        rgbBuffer?.deallocate()
    }

    func start() {
        sessionQueue.async { [weak self] in
            self?.configureAndStart()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.isRunning else { return }
            self.captureSession.stopRunning()
            self.isRunning = false
        }
    }

    private func configureAndStart() {
        guard !isRunning else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // Add video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
        isRunning = true
    }

    /// The underlying AVCaptureSession, for use with CameraPreviewView
    var session: AVCaptureSession { captureSession }

    static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= minFrameInterval else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let rgbBuffer = rgbBuffer else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let srcData = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Center-crop to square
        let cropSize = min(srcWidth, srcHeight)
        let cropX = (srcWidth - cropSize) / 2
        let cropY = (srcHeight - cropSize) / 2

        // Scale factor from cropped region to target
        let scale = Double(cropSize) / Double(targetSize)

        // Convert BGRA to RGB with center-crop and resize
        var dstOffset = 0
        for y in 0..<targetSize {
            let srcY = cropY + Int(Double(y) * scale)
            let rowBase = srcY * bytesPerRow

            for x in 0..<targetSize {
                let srcX = cropX + Int(Double(x) * scale)
                let srcOffset = rowBase + srcX * 4

                rgbBuffer[dstOffset] = srcData[srcOffset + 2]     // R (from BGRA)
                rgbBuffer[dstOffset + 1] = srcData[srcOffset + 1] // G
                rgbBuffer[dstOffset + 2] = srcData[srcOffset]     // B
                dstOffset += 3
            }
        }

        let data = Data(bytes: rgbBuffer, count: rgbBufferSize)
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        delegate?.cameraCaptureService(
            self,
            didOutputRGBData: data,
            width: targetSize,
            height: targetSize,
            timestamp: timestamp
        )
    }
}
