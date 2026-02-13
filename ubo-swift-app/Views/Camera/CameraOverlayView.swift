import AVFoundation
import SwiftUI

struct CameraOverlayView: View {
    let session: AVCaptureSession
    let pattern: String?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Live camera preview
            CameraPreviewView(session: session)
                .ignoresSafeArea()

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
}
