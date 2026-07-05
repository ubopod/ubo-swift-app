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
        let inputFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        UboLog.audio.info(
            "input format: rate=\(inputFormat.sampleRate) ch=\(inputFormat.channelCount); converter=\(self.converter == nil ? "NIL ⚠️" : "ok")"
        )

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
        isRunning = false
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

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.client?.reportAudioSample(
                    timestamp: timestamp,
                    data: data,
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
