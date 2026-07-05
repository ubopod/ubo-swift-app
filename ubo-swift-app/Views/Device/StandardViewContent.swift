//
//  StandardViewContent.swift
//  ubo-swift-app
//
//  The ViewData cases whose rendering is identical in both shells
//  (touch DeviceView, focus-driven TileShellView). Home/menu are
//  shell-specific — touch cards vs focus tiles — and stay in the shells;
//  everything else routes through here so the mapping never forks.
//

import UboAppKit
import SwiftUI
import UboSwift

struct StandardViewContent: View {
    let view: ViewData?

    var body: some View {
        switch view {
        case .notification(let data):
            NotificationDeviceView(data: data)
        case .application(let data):
            ApplicationDeviceView(data: data)
        case .instruction(let data):
            InstructionDeviceView(data: data)
        case .prompt(let data):
            PromptDeviceView(data: data)
        case .render(let data):
            RenderDeviceView(data: data)
        case .chat(let data):
            ChatDeviceView(data: data)
        case .home, .menu, .none:
            VStack(spacing: 16) {
                ProgressView()
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
