import XCTest
@testable import UboAppKit

final class DeviceViewModelMicStreamRequestTests: XCTestCase {
    func testMatchingActiveRequestStarts() {
        let result = DeviceViewModel.micStreamRequestAction(
            audioSource: "watch:abc",
            isActive: true,
            mySourceId: "watch:abc"
        )
        XCTAssertEqual(result, .start)
    }

    func testMatchingInactiveRequestStops() {
        let result = DeviceViewModel.micStreamRequestAction(
            audioSource: "watch:abc",
            isActive: false,
            mySourceId: "watch:abc"
        )
        XCTAssertEqual(result, .stop)
    }

    func testRequestForAnotherSourceIsIgnored() {
        // Addressed to a different client — must not touch this device's mic.
        let result = DeviceViewModel.micStreamRequestAction(
            audioSource: "ios:def",
            isActive: true,
            mySourceId: "watch:abc"
        )
        XCTAssertEqual(result, .ignore)
    }

    func testMatchingIsPlainEquality() {
        // No special-casing for empty strings: unlike tvOS's device-routed
        // listening sessions (reconciledListening's "" case), iOS/watchOS
        // always generate a non-empty audioSourceId before it's ever read,
        // so an empty mySourceId can't occur here in practice - this just
        // documents that the match is plain string equality, nothing more.
        let result = DeviceViewModel.micStreamRequestAction(
            audioSource: "",
            isActive: true,
            mySourceId: ""
        )
        XCTAssertEqual(result, .start)
    }
}
