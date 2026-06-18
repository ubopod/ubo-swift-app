//
//  AudioPlaybackService.swift
//  ubo Watch App
//
//  watchOS counterpart of the iOS playback service. Same contract: subscribe
//  to the device's `PlaybackEvent` stream and route one-shot samples /
//  ordered sequence chunks / stop signals through `AVAudioEngine`.
//

import Foundation
import AVFAudio
import AVFoundation
import UboSwift

@MainActor
final class AudioPlaybackService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var subscriptionTask: Task<Void, Never>?
    private var lastFormat: AVAudioFormat?
    private var sessionConfigured = false

    /// Converts incoming interleaved PCM (int16/float, any rate) into the
    /// deinterleaved float32 format the engine connection uses. Cached and
    /// rebuilt only when the wire format changes.
    private var converter: AVAudioConverter?
    private var converterSourceFormat: AVAudioFormat?

    private var sequences: [String: SequenceState] = [:]

    private var client: UboClient?

    func configure(client: UboClient) {
        self.client = client
    }

    func start() {
        guard subscriptionTask == nil, let client else { return }
        if engine.attachedNodes.contains(player) == false {
            engine.attach(player)
        }
        configureSessionIfNeeded()
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = await client.playbackEvents()
                for try await event in stream {
                    if Task.isCancelled { break }
                    self.handle(event: event)
                }
            } catch {
                // Subscription stopped; will resume on next start().
            }
        }
    }

    func stop() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        player.stop()
        engine.stop()
        if engine.attachedNodes.contains(player) {
            engine.detach(player)
        }
        lastFormat = nil
        converter = nil
        converterSourceFormat = nil
        sequences.removeAll()
    }

    // MARK: - Event handling

    private func handle(event: PlaybackEvent) {
        switch event {
        case .sample(let sample, let volume):
            schedule(sample: sample, volume: volume)
        case .sequence(let id, let index, let sample, let volume):
            queueSequenceChunk(id: id, index: index, sample: sample, volume: volume)
        case .stop:
            stopPlayback()
        }
    }

    private struct SequenceState {
        var nextIndex: Int = 0
        var pending: [Int: (AudioSampleData, Float)] = [:]
    }

    private func queueSequenceChunk(
        id: String,
        index: Int,
        sample: AudioSampleData?,
        volume: Float
    ) {
        var state = sequences[id] ?? SequenceState()
        if let sample {
            state.pending[index] = (sample, volume)
        } else if state.nextIndex == index {
            state.nextIndex += 1
        }

        while let chunk = state.pending.removeValue(forKey: state.nextIndex) {
            schedule(sample: chunk.0, volume: chunk.1)
            state.nextIndex += 1
        }

        if state.pending.isEmpty && sample == nil {
            sequences.removeValue(forKey: id)
        } else {
            sequences[id] = state
        }
    }

    private func schedule(sample: AudioSampleData, volume: Float) {
        guard sample.channels > 0,
              sample.rate > 0,
              sample.width > 0,
              !sample.data.isEmpty else { return }

        // How the PCM bytes arrive on the wire (interleaved int16 or float).
        guard let sourceFormat = AVAudioFormat(
            commonFormat: sample.width == 2 ? .pcmFormatInt16 : .pcmFormatFloat32,
            sampleRate: Double(sample.rate),
            channels: AVAudioChannelCount(sample.channels),
            interleaved: true
        ) else { return }

        // The engine connection format: canonical deinterleaved float32.
        // AVAudioEngine rejects interleaved formats on a node connection with
        // -10868 (kAudioUnitErr_FormatNotSupported) — which crashed the app.
        guard let playbackFormat = AVAudioFormat(
            standardFormatWithSampleRate: Double(sample.rate),
            channels: AVAudioChannelCount(sample.channels)
        ) else { return }

        if playbackFormat != lastFormat {
            player.stop()
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: playbackFormat)
            lastFormat = playbackFormat
            do {
                if !engine.isRunning { try engine.start() }
            } catch {
                UboLog.audio.error("playback engine.start() failed: \(error.localizedDescription)")
                return
            }
            player.play()
        } else if !engine.isRunning {
            do { try engine.start() } catch {
                UboLog.audio.error("playback engine.start() failed: \(error.localizedDescription)")
                return
            }
            player.play()
        }

        if converterSourceFormat != sourceFormat {
            converter = AVAudioConverter(from: sourceFormat, to: playbackFormat)
            converterSourceFormat = sourceFormat
        }
        guard let converter else { return }

        player.volume = max(0, min(1, volume == 0 ? 1 : volume))

        let srcBytesPerFrame = Int(sourceFormat.streamDescription.pointee.mBytesPerFrame)
        guard srcBytesPerFrame > 0 else { return }
        let frameCount = AVAudioFrameCount(sample.data.count / srcBytesPerFrame)
        guard frameCount > 0,
              let srcBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount),
              let outBuffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount) else {
            return
        }
        srcBuffer.frameLength = frameCount
        sample.data.withUnsafeBytes { raw in
            if let base = srcBuffer.audioBufferList.pointee.mBuffers.mData {
                memcpy(base, raw.baseAddress, sample.data.count)
            }
        }

        var error: NSError?
        var consumed = false
        converter.convert(to: outBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return srcBuffer
        }
        guard error == nil, outBuffer.frameLength > 0 else {
            if let error { UboLog.audio.error("playback convert failed: \(error.localizedDescription)") }
            return
        }

        player.scheduleBuffer(outBuffer, completionHandler: nil)
    }

    private func stopPlayback() {
        player.stop()
        sequences.removeAll()
        if engine.isRunning {
            player.play()
        }
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            sessionConfigured = true
        } catch {
            // The next start() call will retry.
        }
    }
}
