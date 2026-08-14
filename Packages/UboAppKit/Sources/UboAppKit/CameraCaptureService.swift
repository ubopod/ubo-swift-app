//
//  CameraCaptureService.swift
//
//  AVCaptureSession wrapper producing center-cropped RGB frames for the
//  Pi's remote-camera pipeline.
//
//  Threading contract: session mutations (`start`/`stop`/`switchPosition`)
//  run on `sessionQueue`; `captureOutput` and frame timing run on
//  `processingQueue`; `isRunning` is the only state crossing queues and is
//  lock-protected. Everything else must stay confined to its queue.
//

import AVFoundation
import Foundation

// Camera capture (AVCaptureSession video) exists only on iOS + macOS.
#if os(iOS) || os(macOS)

public enum CameraError: Error, LocalizedError {
    case noCameraAvailable
    case inputCreationFailed
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .noCameraAvailable: return "No camera available on this device"
        case .inputCreationFailed: return "Could not initialize camera input"
        case .permissionDenied: return "Camera permission denied"
        }
    }
}

public protocol CameraCaptureDelegate: AnyObject {
    func cameraCaptureService(
        _ service: CameraCaptureService,
        didOutputRGBData data: Data,
        width: Int,
        height: Int,
        timestamp: Double
    )

    func cameraCaptureService(
        _ service: CameraCaptureService,
        didFailWithError error: CameraError
    )
}

public final class CameraCaptureService: NSObject {
    public weak var delegate: CameraCaptureDelegate?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ubo.camera.session")
    private let processingQueue = DispatchQueue(label: "com.ubo.camera.processing")

    private let targetSize = UboConstants.cameraTargetSize
    private let minFrameInterval: TimeInterval = UboConstants.cameraFrameInterval
    /// Only touched on `processingQueue` (captureOutput).
    private var lastFrameTime: TimeInterval = 0

    // Pre-allocated RGB buffer for efficiency
    private var rgbBuffer: UnsafeMutablePointer<UInt8>?
    private let rgbBufferSize: Int

    /// Written on `sessionQueue`, read from the delegate's error path on
    /// arbitrary threads — lock-protected.
    private let isRunningLock = NSLock()
    private var _isRunning = false
    public private(set) var isRunning: Bool {
        get { isRunningLock.withLock { _isRunning } }
        set { isRunningLock.withLock { _isRunning = newValue } }
    }

    /// Position we're currently configured for (read on sessionQueue only).
    private var currentPosition: AVCaptureDevice.Position = .back
    private var currentInput: AVCaptureDeviceInput?
    private var currentOutput: AVCaptureVideoDataOutput?

    override public init() {
        rgbBufferSize = UboConstants.cameraTargetSize * UboConstants.cameraTargetSize * 3
        super.init()
        rgbBuffer = .allocate(capacity: rgbBufferSize)
    }

    deinit {
        rgbBuffer?.deallocate()
    }

    public func start(position: AVCaptureDevice.Position = .back) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.currentPosition = position
            self.configureAndStart()
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isRunning else { return }
            self.captureSession.stopRunning()

            // Remove the input/output so a subsequent start() isn't left
            // trying to add fresh ones to a session that still has the old
            // ones attached -- canAddInput() silently returns false in that
            // case, leaving the session running with a stale configuration.
            self.captureSession.beginConfiguration()
            if let input = self.currentInput {
                self.captureSession.removeInput(input)
                self.currentInput = nil
            }
            if let output = self.currentOutput {
                self.captureSession.removeOutput(output)
                self.currentOutput = nil
            }
            self.captureSession.commitConfiguration()

            self.isRunning = false
        }
    }

    /// Hot-swap front/rear without tearing down the entire session.
    public func switchPosition(to newPosition: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self, self.isRunning else { return }
            guard self.currentPosition != newPosition else { return }

            self.captureSession.beginConfiguration()
            if let oldInput = self.currentInput {
                self.captureSession.removeInput(oldInput)
                self.currentInput = nil
            }

            guard let camera = self.resolveCamera(for: newPosition),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.captureSession.canAddInput(input) else {
                self.captureSession.commitConfiguration()
                self.delegate?.cameraCaptureService(self, didFailWithError: .noCameraAvailable)
                return
            }

            self.captureSession.addInput(input)
            self.currentInput = input
            self.currentPosition = newPosition
            self.captureSession.commitConfiguration()
        }
    }

    /// Try every camera type at the requested position, then fall back to the
    /// opposite position, then to whatever default video device exists. On
    /// simulator / iPad-without-back-camera this is the difference between
    /// "blank black screen" and "front camera renders".
    private func resolveCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // The multi-lens device types are iPhone-only; macOS exposes just the
        // wide-angle (built-in or external) camera.
        #if os(iOS)
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera,
        ]
        #else
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        #endif
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video)
    }

    private func configureAndStart() {
        guard !isRunning else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        guard let camera = resolveCamera(for: currentPosition) else {
            captureSession.commitConfiguration()
            delegate?.cameraCaptureService(self, didFailWithError: .noCameraAvailable)
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            delegate?.cameraCaptureService(self, didFailWithError: .inputCreationFailed)
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            currentInput = input
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
            currentOutput = output
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
        isRunning = true
    }

    /// The underlying AVCaptureSession, for use with CameraPreviewView
    public var session: AVCaptureSession { captureSession }

    public static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    public static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
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

        // Convert BGRA to RGB with center-crop, resize, and a 90° clockwise
        // rotation — AVCaptureVideoDataOutput delivers frames in the
        // sensor's native (landscape) orientation with no auto-rotation
        // (that's a Preview-layer-only behavior), so the back camera comes
        // out sideways in portrait use without this. The crop is already
        // square, so rotation is just remapping the write index, not a
        // dimension swap.
        for y in 0..<targetSize {
            let srcY = cropY + Int(Double(y) * scale)
            let rowBase = srcY * bytesPerRow

            for x in 0..<targetSize {
                let srcX = cropX + Int(Double(x) * scale)
                let srcOffset = rowBase + srcX * 4

                let outRow = x
                let outCol = targetSize - 1 - y
                let dstOffset = (outRow * targetSize + outCol) * 3

                rgbBuffer[dstOffset] = srcData[srcOffset + 2]     // R (from BGRA)
                rgbBuffer[dstOffset + 1] = srcData[srcOffset + 1] // G
                rgbBuffer[dstOffset + 2] = srcData[srcOffset]     // B
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

#endif
