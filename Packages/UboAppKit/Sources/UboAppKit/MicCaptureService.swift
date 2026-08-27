//
//  MicCaptureService.swift
//
//  Captures PCM16 microphone samples via AVAudioEngine and streams them
//  to the device as `AudioReportSampleAction`s. Mirrors the Web UI's
//  `reportAudioSample` flow at the assistant pipeline's expected rate.
//  Shared by the iOS/macOS and watchOS targets — same wire format
//  (PCM16 mono @ 16 kHz) so the Pi's assistant pipeline receives
//  identical frames regardless of which client is talking.
//

#if os(iOS) || os(macOS) || os(watchOS)
import Foundation
import AVFAudio
import AVFoundation
import UboSwift

@MainActor
public final class MicCaptureService {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var startedAt: Date = .distantPast
    public private(set) var isRunning: Bool = false

    /// Format the device expects: PCM16 mono @ 16 kHz.
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: UboConstants.micSampleRate,
        channels: 1,
        interleaved: true
    )!

    private var client: UboClient?

    /// Tags every streamed sample so the core binds the listening session to
    /// this app's mic and ignores the device's built-in mic. Set at `start`.
    private var audioSource: String = ""

    /// Diagnostics: how many tap callbacks fired and how many samples we sent.
    private var tapCount = 0
    private var sampleCount = 0

    /// One chunk queued for network dispatch: the converted PCM16 bytes plus
    /// the elapsed-time timestamp captured alongside it.
    private struct QueuedSample {
        let data: Data
        let timestamp: Float
    }

    /// Feeds `dispatch()`'s converted chunks to the single sender task below.
    /// Unbounded, mirroring the Android phone client's `Channel` — capture
    /// should never block on network speed, and audio is small enough per
    /// session that unbounded backlog is a minor risk, not a real one (same
    /// tradeoff already accepted there).
    private var sampleContinuation: AsyncStream<QueuedSample>.Continuation?

    /// Drains `sampleContinuation`'s stream one chunk at a time, awaiting
    /// each `reportAudioSample` call before starting the next. Chunks were
    /// previously dispatched as one unstructured `Task` each — with no cap
    /// and no ordering guarantee — over watchOS's grpc-web transport (up to
    /// 16 concurrent HTTP/1.1 connections), which measurably reordered
    /// audio at the core and broke STT even though every chunk arrived.
    /// Serializing to one in-flight request at a time, like ESP32's and
    /// Android's proven single-sender designs, guarantees capture order is
    /// preserved by construction instead of racing on the network.
    private var senderTask: Task<Void, Never>?

    public init() {}

    public func configure(client: UboClient) {
        self.client = client
    }

    public func start(audioSource: String = "") async throws {
        guard !isRunning else { UboLog.audio.info("mic start ignored — already running"); return }
        guard client != nil else { UboLog.audio.error("mic start aborted — no client configured"); return }
        self.audioSource = audioSource
        tapCount = 0
        sampleCount = 0
        UboLog.audio.info("mic start requested (audioSource=\(audioSource.isEmpty ? "<empty/system>" : audioSource))")

        try await requestMicPermission()
        UboLog.audio.info("mic permission granted")

        #if os(iOS) || os(watchOS)
        // macOS has no AVAudioSession; AVAudioEngine drives the input node directly.
        try AudioSessionCoordinator.activateCapture()
        #endif

        let input = engine.inputNode
        // Engages Apple's voice-processing I/O unit — AGC, noise suppression,
        // echo cancellation — on the raw input tap. Without it AVAudioEngine
        // hands back whatever level the mic hardware happens to produce with
        // no correction; confirmed on real Watch hardware to come in quiet
        // enough (peak ~-30 to -34 dBFS) to intermittently fail both a VAD
        // loudness gate and the VAD model's own speech-confidence score,
        // while the exact same mic captured at raised volume passed both
        // comfortably. Best-effort: log and continue capturing raw if the
        // platform/OS version doesn't support it rather than failing capture
        // entirely.
        do {
            try input.setVoiceProcessingEnabled(true)
        } catch {
            UboLog.audio.error("failed to enable input voice processing (AGC): \(error.localizedDescription)")
        }
        let inputFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        UboLog.audio.info(
            "input format: rate=\(inputFormat.sampleRate) ch=\(inputFormat.channelCount); converter=\(self.converter == nil ? "NIL ⚠️" : "ok")"
        )

        startSender()

        let bufferSize: AVAudioFrameCount = UboConstants.micTapBufferSize
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let elapsed = Float(Date().timeIntervalSince(self.startedAt))
            Task { @MainActor [weak self] in
                self?.dispatch(buffer: buffer, timestamp: elapsed)
            }
        }

        engine.prepare()
        startedAt = Date()
        do {
            try engine.start()
        } catch {
            UboLog.audio.error("engine.start() failed: \(error.localizedDescription)")
            throw error
        }
        isRunning = true
        UboLog.audio.info("mic engine started — streaming to core")
    }

    public func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        #if os(iOS) || os(watchOS)
        // Hand the shared session back to playback — deactivating it here
        // would kill device audio after every push-to-talk cycle.
        AudioSessionCoordinator.restorePlayback()
        #endif
        // Finish (don't cancel) so the sender drains whatever's already
        // queued instead of dropping the last few chunks of the utterance.
        sampleContinuation?.finish()
        sampleContinuation = nil
        senderTask = nil
        isRunning = false
    }

    /// Starts the single dedicated sender that drains queued chunks strictly
    /// in capture order, one `reportAudioSample` RPC in flight at a time.
    private func startSender() {
        let (stream, continuation) = AsyncStream<QueuedSample>.makeStream()
        sampleContinuation = continuation
        senderTask = Task { [weak self] in
            for await sample in stream {
                guard let self else { return }
                do {
                    try await self.client?.reportAudioSample(
                        timestamp: sample.timestamp,
                        data: sample.data,
                        channels: 1,
                        rate: Int(UboConstants.micSampleRate),
                        width: 2,
                        audioSource: self.audioSource
                    )
                } catch {
                    UboLog.audio.error("reportAudioSample dispatch FAILED: \(error.localizedDescription)")
                }
            }
        }
    }

    private func dispatch(buffer: AVAudioPCMBuffer, timestamp: Float) {
        tapCount += 1
        guard let converter,
              let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: AVAudioFrameCount(targetFormat.sampleRate)
              ) else {
            UboLog.audio.error("dispatch: no converter/outputBuffer — dropping (tap #\(self.tapCount))")
            return
        }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                // .noDataNow (NOT .endOfStream): the converter is reused across
                // every tap callback, and .endOfStream permanently finishes a
                // stateful converter — after the first buffer it would return
                // .endOfStream with 0 frames forever. .noDataNow means "no more
                // input for this call" and keeps the converter alive.
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status == .haveData || status == .inputRanDry,
              outputBuffer.frameLength > 0,
              let int16Channel = outputBuffer.int16ChannelData else {
            if let error {
                UboLog.audio.error("mic conversion failed: \(error.localizedDescription)")
            } else {
                UboLog.audio.debug("mic dispatch: 0 frames (status=\(status.rawValue)) — skipping")
            }
            return
        }

        let frameCount = Int(outputBuffer.frameLength)
        let byteCount = frameCount * MemoryLayout<Int16>.size
        let data = Data(bytes: int16Channel[0], count: byteCount)

        sampleCount += 1
        if sampleCount == 1 {
            UboLog.audio.info("mic streaming: first sample sent (\(byteCount) bytes, src=\(self.audioSource))")
        } else if sampleCount % 100 == 0 {
            UboLog.audio.debug("mic streaming: \(self.sampleCount) samples sent (taps=\(self.tapCount))")
        }

        sampleContinuation?.yield(QueuedSample(data: data, timestamp: timestamp))
    }

    private func requestMicPermission() async throws {
        #if os(iOS) || os(watchOS)
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { allowed in
                cont.resume(returning: allowed)
            }
        }
        #else
        // macOS: AVAudioApplication is unavailable; gate capture on the
        // sandbox's audio-input device permission instead.
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        #endif
        guard granted else {
            throw NSError(
                domain: "MicCaptureService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"]
            )
        }
    }
}
#endif
