//
//  AudioPlaybackService.swift
//  ubo-swift-app
//
//  Subscribes to `AudioPlayAudioSampleEvent` and routes the device's PCM
//  samples through AVAudioEngine so TTS / chimes / assistant audio play
//  back on the connected client's speaker.
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

    private var client: UboClient?

    func configure(client: UboClient) {
        self.client = client
    }

    func start() {
        guard subscriptionTask == nil, let client else { return }
        engine.attach(player)
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = await client.playbackAudio()
                for try await sample in stream {
                    if Task.isCancelled { break }
                    self.play(sample: sample)
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
        engine.detach(player)
        lastFormat = nil
    }

    private func play(sample: AudioSampleData) {
        guard sample.channels > 0,
              sample.rate > 0,
              sample.width > 0,
              !sample.data.isEmpty else { return }

        let format = AVAudioFormat(
            commonFormat: sample.width == 2 ? .pcmFormatInt16 : .pcmFormatFloat32,
            sampleRate: Double(sample.rate),
            channels: AVAudioChannelCount(sample.channels),
            interleaved: true
        )

        guard let format else { return }

        if format != lastFormat {
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            lastFormat = format
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                return
            }
            do {
                try engine.start()
            } catch {
                return
            }
            player.play()
        }

        let frameCount = AVAudioFrameCount(sample.data.count / (Int(format.streamDescription.pointee.mBytesPerFrame)))
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        sample.data.withUnsafeBytes { raw in
            if let int16Channel = buffer.int16ChannelData {
                memcpy(int16Channel[0], raw.baseAddress, sample.data.count)
            } else if let floatChannel = buffer.floatChannelData {
                memcpy(floatChannel[0], raw.baseAddress, sample.data.count)
            }
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}
#endif
