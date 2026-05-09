import AVFoundation
import Foundation
import UboSwift

@MainActor
@Observable
final class CameraManager: CameraCaptureDelegate {
    private(set) var isActive = false
    private(set) var lastError: CameraError?
    private(set) var position: AVCaptureDevice.Position = .back

    private let captureService = CameraCaptureService()
    private var client: UboClient?

    // Frame coalescing: latest frame protected by NSLock, accessed from nonisolated delegate
    private nonisolated(unsafe) let frameLock = NSLock()
    private nonisolated(unsafe) var pendingFrame: (data: Data, width: Int, height: Int, timestamp: Float)?
    private var dispatchTask: Task<Void, Never>?

    var captureSession: AVCaptureSession { captureService.session }

    func configure(client: UboClient) {
        self.client = client
    }

    func startCamera() {
        guard !isActive else { return }
        isActive = true
        lastError = nil

        Task {
            let granted = await CameraCaptureService.requestPermission()
            guard granted else {
                lastError = .permissionDenied
                isActive = false
                return
            }

            captureService.delegate = self
            captureService.start(position: position)
            startDispatchLoop()
        }
    }

    func stopCamera() {
        guard isActive else { return }
        captureService.stop()
        captureService.delegate = nil
        dispatchTask?.cancel()
        dispatchTask = nil
        frameLock.lock()
        pendingFrame = nil
        frameLock.unlock()
        isActive = false
    }

    /// Flip between front and rear cameras while the session keeps running.
    func switchPosition() {
        let newPosition: AVCaptureDevice.Position = (position == .back) ? .front : .back
        position = newPosition
        lastError = nil
        captureService.switchPosition(to: newPosition)
    }

    // MARK: - CameraCaptureDelegate

    nonisolated func cameraCaptureService(
        _ service: CameraCaptureService,
        didOutputRGBData data: Data,
        width: Int,
        height: Int,
        timestamp: Double
    ) {
        frameLock.lock()
        pendingFrame = (data: data, width: width, height: height, timestamp: Float(timestamp))
        frameLock.unlock()
    }

    nonisolated func cameraCaptureService(
        _ service: CameraCaptureService,
        didFailWithError error: CameraError
    ) {
        Task { @MainActor [weak self] in
            self?.lastError = error
            // Keep isActive true if the error came from a switch (so the user
            // can flip back); only clear it on the initial start failure.
            if !service.isRunning {
                self?.isActive = false
            }
        }
    }

    // MARK: - Dispatch Loop

    private func startDispatchLoop() {
        dispatchTask?.cancel()
        dispatchTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                // Pick up the latest frame
                frameLock.lock()
                let frame = pendingFrame
                pendingFrame = nil
                frameLock.unlock()

                if let frame, let client {
                    try? await client.sendCameraFrame(
                        data: frame.data,
                        width: frame.width,
                        height: frame.height,
                        timestamp: frame.timestamp
                    )
                }

                // Pace the dispatch loop (~12 FPS)
                try? await Task.sleep(nanoseconds: 83_000_000)
            }
        }
    }
}
