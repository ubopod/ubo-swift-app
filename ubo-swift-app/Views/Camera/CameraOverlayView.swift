import AVFoundation
import SwiftUI

struct CameraOverlayView: View {
    let cameraManager: CameraManager
    let pattern: String?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Live camera preview
            CameraPreviewView(session: cameraManager.captureSession)
                .ignoresSafeArea()

            // Diagnostic banner if the session can't produce frames (simulator,
            // missing camera, denied permission, etc.). Without this the user
            // sees a solid black rectangle and has no idea why.
            if let error = cameraManager.lastError {
                errorBanner(error)
            }

            // Overlay UI
            VStack {
                // Top bar
                topBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                // Center viewfinder guide
                viewfinderGuide

                Spacer()

                // Bottom live indicator
                liveIndicator
                    .padding(.bottom, 32)
            }
        }
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Camera Active")
                    .font(.headline)
                    .foregroundStyle(.white)

                if let pattern {
                    Text("Pattern: \(pattern)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            Button {
                cameraManager.switchPosition()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .accessibilityLabel(cameraManager.position == .back ? "Switch to front camera" : "Switch to back camera")

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var viewfinderGuide: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(.white.opacity(0.6), lineWidth: 2)
            .frame(width: 240, height: 240)
    }

    private var liveIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)

            Text("LIVE")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
    }

    private func errorBanner(_ error: CameraError) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.8))
            Text(error.errorDescription ?? "Camera unavailable")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(24)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
