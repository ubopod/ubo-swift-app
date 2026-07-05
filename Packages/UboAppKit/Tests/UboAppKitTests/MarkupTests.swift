import XCTest
@testable import UboAppShared

final class MarkupTests: XCTestCase {
    func testPlainTextPassesThrough() {
        let segments = parseMarkupSegments("hello world")
        XCTAssertEqual(segments.map(\.text).joined(), "hello world")
        XCTAssertFalse(segments.contains { $0.bold || $0.italic || $0.underline })
    }

    func testBoldSegment() {
        let segments = parseMarkupSegments("a[b]bold[/b]c")
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].text, "a")
        XCTAssertFalse(segments[0].bold)
        XCTAssertEqual(segments[1].text, "bold")
        XCTAssertTrue(segments[1].bold)
        XCTAssertEqual(segments[2].text, "c")
        XCTAssertFalse(segments[2].bold)
    }

    func testNestedTags() {
        let segments = parseMarkupSegments("[b]bold [i]both[/i] bold[/b]")
        XCTAssertEqual(segments.count, 3)
        XCTAssertTrue(segments[0].bold)
        XCTAssertFalse(segments[0].italic)
        XCTAssertTrue(segments[1].bold)
        XCTAssertTrue(segments[1].italic)
        XCTAssertTrue(segments[2].bold)
        XCTAssertFalse(segments[2].italic)
    }

    func testUnclosedTagDoesNotCrash() {
        let segments = parseMarkupSegments("[b]never closed")
        XCTAssertEqual(segments.map(\.text).joined(), "never closed")
        XCTAssertTrue(segments.allSatisfy(\.bold))
    }

    func testStrayClosingTagDoesNotCrash() {
        let segments = parseMarkupSegments("text[/b]more")
        XCTAssertEqual(segments.map(\.text).joined(), "textmore")
    }

    func testColorTagParsesHex() {
        let segments = parseMarkupSegments("[color=#ff0000]red[/color]")
        XCTAssertEqual(segments.count, 1)
        XCTAssertNotNil(segments[0].color)
    }

    func testUnknownTagsAreStripped() {
        let segments = parseMarkupSegments("a[ref=xyz]b[/ref]c")
        XCTAssertEqual(segments.map(\.text).joined(), "abc")
    }

    func testStripMarkup() {
        XCTAssertEqual(stripMarkup("[b]bold[/b] and [color=#fff]white[/color]"), "bold and white")
        XCTAssertEqual(stripMarkup("plain"), "plain")
        XCTAssertEqual(stripMarkup("[size=20]big[/size]"), "big")
    }
}
