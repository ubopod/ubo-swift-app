//
//  WatchAssistantTrigger.swift
//  ubo Watch App
//
//  How the watch identifies itself when it opens an assistant session.
//

import UboSwift

extension AssistantTriggerSource {
    /// Trigger sent when the watch starts a listening session.
    ///
    /// Declared as a quick-chat wake so the core applies its quick-chat
    /// policy: the pod ends the turn after its configured silence window
    /// rather than waiting for the watch to stop the session. That also arms
    /// the core's stage-1 voice-shortcut grammar against this session's audio
    /// source, matching what a spoken quick-chat wake does on the device.
    ///
    /// `phrase`/`detector` are diagnostic only — nothing in the core branches
    /// on them — so they name the real trigger rather than a spoken phrase.
    static let watchDoubleTap = AssistantTriggerSource.wakePhrase(
        phrase: "double tap",
        detector: "watch",
        mode: .quickChat
    )
}
