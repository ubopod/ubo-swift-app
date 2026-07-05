//
//  ViewChrome.swift
//
//  Shared chrome computation for the current `ViewData`: title and
//  back-affordance. Both shells (touch `DeviceView`, focus-driven
//  `TileShellView`) and the Watch render these identically — keep the
//  mapping in one place.
//

import UboSwift

public extension Optional where Wrapped == ViewData {
    /// Human-readable title for the current view.
    var uboTitle: String {
        switch self {
        case .home: return "Home"
        case .menu(let d): return d.title.isEmpty ? "Menu" : d.title
        case .notification: return "Notification"
        case .application(let d): return d.applicationId
        case .instruction(let d): return d.title.isEmpty ? "Instruction" : d.title
        case .prompt(let d): return d.title.isEmpty ? "Prompt" : d.title
        case .render(let d): return d.title.isEmpty ? "Render" : d.title
        case .chat: return "Assistant"
        case .none: return "Device"
        }
    }

    /// Whether the shell should offer a back affordance for this view.
    var uboShowsBack: Bool {
        if case .home = self { return false }
        return self != nil
    }
}
