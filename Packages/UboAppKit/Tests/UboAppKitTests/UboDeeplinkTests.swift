import XCTest
@testable import UboAppShared

final class UboDeeplinkTests: XCTestCase {
    func testRoundTrip() throws {
        let url = try XCTUnwrap(UboDeeplink.inputURL(host: "ubo.local", port: 50051, useTLS: true, inputId: "abc"))
        let request = try XCTUnwrap(UboDeeplink.parseInput(url))
        XCTAssertEqual(request.host, "ubo.local")
        XCTAssertEqual(request.port, 50051)
        XCTAssertTrue(request.useTLS)
        XCTAssertEqual(request.inputId, "abc")
    }

    func testEmptyHostRejected() {
        XCTAssertNil(UboDeeplink.inputURL(host: "", port: 1, useTLS: false, inputId: "x"))
    }

    func testWrongSchemeOrHostRejected() {
        XCTAssertNil(UboDeeplink.parseInput(URL(string: "https://input?host=a")!))
        XCTAssertNil(UboDeeplink.parseInput(URL(string: "ubo://other?host=a")!))
    }

    func testMissingPortDefaults() throws {
        let request = try XCTUnwrap(UboDeeplink.parseInput(URL(string: "ubo://input?host=a")!))
        XCTAssertEqual(request.port, UboConstants.defaultPort)
        XCTAssertFalse(request.useTLS)
        XCTAssertEqual(request.inputId, "")
    }
}
