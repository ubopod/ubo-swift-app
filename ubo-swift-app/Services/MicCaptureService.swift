//
//  MicCaptureService.swift
//  ubo-swift-app
//
//  Captures PCM16 microphone samples via AVAudioEngine and streams them
//  to the device as `AudioReportSampleAction`s. Mirrors the Web UI's
//  `reportAudioSample` flow at the assistant pipeline's expected rate.
//

#if os(iOS)
import Foundation
import AVFAudio
import AVFoundation
import UboSwift

@MainActor
final class MicCaptureService {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var startedAt: Date = .distantPast
    private(set) var isRunning: Bool = false

    /// Format the device expects: PCM16 mono @ 16 kHz.
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!

    private var client: UboClient?

    func configure(client: UboClient) {
        self.client = client
    }

    func start() async throws {
        guard !isRunning else { return }
        guard let client else { return }

        try await requestMicPermission()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        let bufferSize: AVAudioFrameCount = 1024
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let elapsed = Float(Date().timeIntervalSince(self.startedAt))
            Task { @MainActor [weak self] in
                self?.dispatch(buffer: buffer, timestamp: elapsed)
            }
        }

        engine.prepare()
        startedAt = Date()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
    }

    private func dispatch(buffer: AVAudioPCMBuffer, timestamp: Float) {
        guard let converter,
              let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: AVAudioFrameCount(targetFormat.sampleRate)
              ) else { return }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status == .haveData || status == .inputRanDry,
              outputBuffer.frameLength > 0,
              let int16Channel = outputBuffer.int16ChannelData else { return }

        let frameCount = Int(outputBuffer.frameLength)
        let byteCount = frameCount * MemoryLayout<Int16>.size
        let data = Data(bytes: int16Channel[0], count: byteCount)

        Task { [weak self] in
            try? await self?.client?.reportAudioSample(
                timestamp: timestamp,
                data: data,
                channels: 1,
                rate: 16000,
                width: 2
            )
        }
    }

    private func requestMicPermission() async throws {
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { allowed in
                cont.resume(returning: allowed)
            }
        }
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
