//
//  CameraManager.swift
//
//  Main-actor camera coordinator: reacts to the Pi's viewfinder events,
//  coalesces frames from the capture service, and paces frame dispatch to
//  the core.
//
//  Threading contract: `frameLock` guards `pendingFrame`, the single
//  hand-off point between the nonisolated capture delegate (processing
//  queue) and the main-actor dispatch loop. `pendingFrame` must never be
//  touched without holding `frameLock`; all other state is main-actor.
//

import AVFoundation
import Foundation
import UboSwift

// Camera capture exists only on iOS + macOS; tvOS/visionOS have no viewfinder.
#if os(iOS) || os(macOS)

@MainActor
@Observable
public final class CameraManager: CameraCaptureDelegate {
    public private(set) var isActive = false
    public private(set) var lastError: CameraError?
    public private(set) var position: AVCaptureDevice.Position = .back

    private let captureService = CameraCaptureService()
    private var client: UboClient?

    // Frame coalescing: latest frame protected by NSLock, accessed from nonisolated delegate
    private let frameLock = NSLock()
    private nonisolated(unsafe) var pendingFrame: (data: Data, width: Int, height: Int, timestamp: Float)?
    private var dispatchTask: Task<Void, Never>?

    public var captureSession: AVCaptureSession { captureService.session }

    public init() {}

    public func configure(client: UboClient) {
        self.client = client
    }

    public func startCamera() {
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

    public func stopCamera() {
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
    public func switchPosition() {
        let newPosition: AVCaptureDevice.Position = (position == .back) ? .front : .back
        position = newPosition
        lastError = nil
        captureService.switchPosition(to: newPosition)
    }

    // MARK: - CameraCaptureDelegate

    public nonisolated func cameraCaptureService(
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

    public nonisolated func cameraCaptureService(
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

    /// Take (and clear) the latest coalesced frame. Safe from any context.
    private nonisolated func takePendingFrame() -> (data: Data, width: Int, height: Int, timestamp: Float)? {
        frameLock.lock()
        defer { frameLock.unlock() }
        let frame = pendingFrame
        pendingFrame = nil
        return frame
    }

    private func startDispatchLoop() {
        dispatchTask?.cancel()
        dispatchTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                // Pick up the latest frame
                let frame = self.takePendingFrame()

                if let frame, let client {
                    do {
                        try await client.sendCameraFrame(
                            data: frame.data,
                            width: frame.width,
                            height: frame.height,
                            timestamp: frame.timestamp
                        )
                    } catch {
                        UboLog.camera.error("sendCameraFrame failed: \(error.localizedDescription)")
                    }
                }

                // Pace the dispatch loop (~12 FPS)
                try? await Task.sleep(nanoseconds: UInt64(UboConstants.cameraFrameInterval * 1_000_000_000))
            }
        }
    }
}

#endif
