//
//  NotificationItems.swift
//  ubo-swift-app
//
//  Mirrors the Web UI's notification action filtering contract
//  (`web-app/src/store/constants.ts`,
//  `web-app/src/components/NotificationOverlay.tsx`). Notification
//  payloads from the device may include items keyed/prefixed as either
//  "dismiss" or "extra_info" — those are not regular action buttons and
//  should be rendered as a single corner dismiss affordance / a small
//  inline icon, not full-width buttons.
//

import Foundation
import UboSwift

public enum NotificationItem {
    /// Action buttons that belong in the main grid (QR, Web UI, custom actions).
    public static let dismissPrefix = "notification:dismiss:"
    public static let extraInfoPrefix = "notification:extra_info:"
    public static let dismissKey = "dismiss"
    public static let extraInfoKey = "extra_info"

    /// True when the item is a synthesised dismiss action (close icon path).
    public nonisolated static func isDismiss(_ item: MenuItemData) -> Bool {
        item.key == dismissKey || item.actionId?.hasPrefix(dismissPrefix) == true
    }

    /// True when the item is the optional "read aloud / extra info" action
    /// rendered as a small accent icon next to `extraInformation`.
    public nonisolated static func isExtraInfo(_ item: MenuItemData) -> Bool {
        item.key == extraInfoKey || item.actionId?.hasPrefix(extraInfoPrefix) == true
    }
}

public struct PartitionedNotificationItems: Sendable {
    public let mainActions: [MenuItemData]
    public let extraInfo: MenuItemData?
    public let hasDismiss: Bool
}

/// Split the device-supplied items into:
/// - `mainActions` — the buttons rendered in the main grid;
/// - `extraInfo` — the optional accent icon paired with `extraInformation`;
/// - `hasDismiss` — whether to surface a dedicated dismiss affordance.
public func partitionNotificationItems(_ items: [MenuItemData?]) -> PartitionedNotificationItems {
    let unwrapped = items.compactMap { $0 }
    let extraInfo = unwrapped.first(where: NotificationItem.isExtraInfo)
    let hasDismiss = unwrapped.contains(where: NotificationItem.isDismiss)
    let mainActions = unwrapped.filter { item in
        !NotificationItem.isDismiss(item) && !NotificationItem.isExtraInfo(item)
    }
    return PartitionedNotificationItems(
        mainActions: mainActions,
        extraInfo: extraInfo,
        hasDismiss: hasDismiss
    )
}
