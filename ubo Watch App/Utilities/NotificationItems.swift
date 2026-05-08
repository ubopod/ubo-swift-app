//
//  NotificationItems.swift
//  ubo Watch App
//
//  watchOS counterpart of the iOS `NotificationItems` helper. Mirrors the
//  Web UI's notification action filtering contract so dismiss / extra_info
//  items don't leak into the main button grid.
//

import Foundation
import UboSwift

public enum NotificationItem {
    public static let dismissPrefix = "notification:dismiss:"
    public static let extraInfoPrefix = "notification:extra_info:"
    public static let dismissKey = "dismiss"
    public static let extraInfoKey = "extra_info"

    public nonisolated static func isDismiss(_ item: MenuItemData) -> Bool {
        item.key == dismissKey || item.actionId?.hasPrefix(dismissPrefix) == true
    }

    public nonisolated static func isExtraInfo(_ item: MenuItemData) -> Bool {
        item.key == extraInfoKey || item.actionId?.hasPrefix(extraInfoPrefix) == true
    }
}

public struct PartitionedNotificationItems: Sendable {
    public let mainActions: [MenuItemData]
    public let extraInfo: MenuItemData?
    public let hasDismiss: Bool
}

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
