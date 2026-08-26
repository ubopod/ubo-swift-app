import XCTest
@testable import UboAppKit

final class DeviceViewModelListeningReconciliationTests: XCTestCase {
    func testOwnSessionListeningReconcilesToTrue() {
        let result = DeviceViewModel.reconciledListening(
            serverIsListening: true,
            serverActiveAudioSource: "watch:abc",
            mySourceId: "watch:abc"
        )
        XCTAssertTrue(result)
    }

    func testAnotherSourcesSessionDoesNotReconcileToTrue() {
        // A different client is listening — this device's UI must not show
        // itself as the one actively streaming.
        let result = DeviceViewModel.reconciledListening(
            serverIsListening: true,
            serverActiveAudioSource: "ios:def",
            mySourceId: "watch:abc"
        )
        XCTAssertFalse(result)
    }

    func testNotListeningReconcilesToFalseRegardlessOfSource() {
        let result = DeviceViewModel.reconciledListening(
            serverIsListening: false,
            serverActiveAudioSource: "watch:abc",
            mySourceId: "watch:abc"
        )
        XCTAssertFalse(result)
    }

    func testTvOSEmptySourceMatchesDeviceRoutedSession() {
        // tvOS sends audioSource: "" for its device-routed sessions.
        let result = DeviceViewModel.reconciledListening(
            serverIsListening: true,
            serverActiveAudioSource: "",
            mySourceId: ""
        )
        XCTAssertTrue(result)
    }
}
