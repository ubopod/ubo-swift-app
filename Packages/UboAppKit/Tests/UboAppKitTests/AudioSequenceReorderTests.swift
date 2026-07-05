import XCTest
import UboSwift
@testable import UboAppKit

final class AudioSequenceReorderTests: XCTestCase {
    private func sample(_ byte: UInt8) -> AudioSampleData {
        AudioSampleData(data: Data([byte]))
    }

    private func bytes(_ chunks: [(AudioSampleData, Float)]) -> [UInt8] {
        chunks.map { $0.0.data[0] }
    }

    func testInOrderChunksDrainImmediately() {
        var state = AudioPlaybackService.SequenceState()
        let r0 = AudioPlaybackService.merge(index: 0, sample: sample(0), volume: 1, into: &state)
        XCTAssertEqual(bytes(r0.ready), [0])
        XCTAssertFalse(r0.finished)
        let r1 = AudioPlaybackService.merge(index: 1, sample: sample(1), volume: 1, into: &state)
        XCTAssertEqual(bytes(r1.ready), [1])
    }

    func testOutOfOrderChunksBufferUntilGapFills() {
        var state = AudioPlaybackService.SequenceState()
        let r2 = AudioPlaybackService.merge(index: 2, sample: sample(2), volume: 1, into: &state)
        XCTAssertEqual(r2.ready.count, 0)
        let r1 = AudioPlaybackService.merge(index: 1, sample: sample(1), volume: 1, into: &state)
        XCTAssertEqual(r1.ready.count, 0)
        // Index 0 arrives: everything drains in order.
        let r0 = AudioPlaybackService.merge(index: 0, sample: sample(0), volume: 1, into: &state)
        XCTAssertEqual(bytes(r0.ready), [0, 1, 2])
    }

    func testNilTerminatorAdvancesAndFinishes() {
        var state = AudioPlaybackService.SequenceState()
        _ = AudioPlaybackService.merge(index: 0, sample: sample(0), volume: 1, into: &state)
        // Terminator at the expected index: no chunks, sequence done.
        let end = AudioPlaybackService.merge(index: 1, sample: nil, volume: 0, into: &state)
        XCTAssertEqual(end.ready.count, 0)
        XCTAssertTrue(end.finished)
    }

    func testTerminatorWithPendingChunksIsNotFinished() {
        var state = AudioPlaybackService.SequenceState()
        _ = AudioPlaybackService.merge(index: 2, sample: sample(2), volume: 1, into: &state)
        let end = AudioPlaybackService.merge(index: 0, sample: nil, volume: 0, into: &state)
        XCTAssertFalse(end.finished)
    }

    func testVolumeTravelsWithChunk() {
        var state = AudioPlaybackService.SequenceState()
        let r = AudioPlaybackService.merge(index: 0, sample: sample(9), volume: 0.25, into: &state)
        XCTAssertEqual(r.ready.first?.1, 0.25)
    }
}
