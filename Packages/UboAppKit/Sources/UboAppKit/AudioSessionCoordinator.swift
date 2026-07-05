//
//  AudioSessionCoordinator.swift
//
//  Single owner of the process-wide `AVAudioSession` shared by playback
//  (`AudioPlaybackService`) and push-to-talk capture (`MicCaptureService`).
//  Neither service touches the session directly: capture ending must hand
//  the session *back* to playback — a bare `setActive(false)` tears the
//  shared session out from under the playback engine and silences device
//  audio until an engine restart.
//

#if os(iOS) || os(watchOS)
import AVFAudio
import UboSwift

@MainActor
public enum AudioSessionCoordinator {
    private enum Mode { case none, playback, capture }
    private static var mode: Mode = .none

    /// Playback category, mixing with other audio. Idempotent.
    public static func activatePlayback() throws {
        guard mode != .playback else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        mode = .playback
    }

    /// Capture category for push-to-talk. `.playAndRecord` keeps playback
    /// alive while the mic streams.
    public static func activateCapture() throws {
        let session = AVAudioSession.sharedInstance()
        #if os(iOS)
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        #else
        // watchOS does not support `.defaultToSpeaker` — the Watch routes
        // audio through paired BT or the built-in speaker automatically.
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP]
        )
        #endif
        try session.setActive(true)
        mode = .capture
    }

    /// Hand the session back to playback after capture ends. Never
    /// deactivates the shared session.
    public static func restorePlayback() {
        mode = .none
        do {
            try activatePlayback()
        } catch {
            UboLog.audio.error("failed to restore playback session after capture: \(error.localizedDescription)")
        }
    }
}
#endif
