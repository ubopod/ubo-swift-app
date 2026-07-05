import XCTest
import UboSwift
@testable import UboAppKit

final class NotificationItemsTests: XCTestCase {
    private func item(key: String? = nil, actionId: String? = nil, label: String = "x") -> MenuItemData {
        MenuItemData(key: key ?? label, label: label, actionId: actionId)
    }

    func testPartitionSplitsDismissExtraInfoAndActions() {
        let items: [MenuItemData?] = [
            item(key: "dismiss"),
            item(key: "extra_info"),
            item(key: "open", label: "Open"),
            nil,
        ]
        let partitioned = partitionNotificationItems(items)
        XCTAssertTrue(partitioned.hasDismiss)
        XCTAssertNotNil(partitioned.extraInfo)
        XCTAssertEqual(partitioned.mainActions.map(\.label), ["Open"])
    }

    func testPartitionByActionIdPrefixes() {
        let items: [MenuItemData?] = [
            item(key: "a", actionId: NotificationItem.dismissPrefix + "n1"),
            item(key: "b", actionId: NotificationItem.extraInfoPrefix + "n1"),
        ]
        let partitioned = partitionNotificationItems(items)
        XCTAssertTrue(partitioned.hasDismiss)
        XCTAssertNotNil(partitioned.extraInfo)
        XCTAssertTrue(partitioned.mainActions.isEmpty)
    }

    func testEmptyInput() {
        let partitioned = partitionNotificationItems([])
        XCTAssertFalse(partitioned.hasDismiss)
        XCTAssertNil(partitioned.extraInfo)
        XCTAssertTrue(partitioned.mainActions.isEmpty)
    }
}
