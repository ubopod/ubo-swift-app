//
//  AudioPlaybackService.swift
//  ubo-swift-app
//
//  Routes the device's playback event stream — one-shot samples
//  (chimes, alerts), indexed sequence chunks (TTS / file playback),
//  and stop signals — through `AVAudioEngine` so the user hears the
//  same audio on the iPhone speaker as the Pi would play locally.
//  Mirrors the contract the Web UI implements in `audio.ts`.
//

#if os(iOS)
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

    /// Per-sequence reorder buffers. The gRPC stream usually delivers
    /// chunks in arrival order, but we still gate on `index` to match
    /// the Web UI and tolerate any future reordering.
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

    /// Buffer chunks until the next-expected `index` arrives, then drain
    /// them in order. `sample == nil` is used by the Python core as a
    /// terminator — we just advance the counter.
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

        guard let format = AVAudioFormat(
            commonFormat: sample.width == 2 ? .pcmFormatInt16 : .pcmFormatFloat32,
            sampleRate: Double(sample.rate),
            channels: AVAudioChannelCount(sample.channels),
            interleaved: true
        ) else { return }

        if format != lastFormat {
            // Drain queued buffers from the previous format and reconnect.
            player.stop()
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            lastFormat = format
            do {
                if !engine.isRunning { try engine.start() }
            } catch {
                return
            }
            player.play()
        } else if !engine.isRunning {
            do { try engine.start() } catch { return }
            player.play()
        }

        player.volume = max(0, min(1, volume == 0 ? 1 : volume))

        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        guard bytesPerFrame > 0 else { return }
        let frameCount = AVAudioFrameCount(sample.data.count / bytesPerFrame)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }
        buffer.frameLength = frameCount

        sample.data.withUnsafeBytes { raw in
            if let int16 = buffer.int16ChannelData {
                memcpy(int16[0], raw.baseAddress, sample.data.count)
            } else if let float = buffer.floatChannelData {
                memcpy(float[0], raw.baseAddress, sample.data.count)
            }
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func stopPlayback() {
        player.stop()
        sequences.removeAll()
        // Re-arm so the next chunk plays immediately.
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
            // Audio session may stay un-activated on backgrounded launch;
            // the next start() call will retry.
        }
    }
}
#endif
