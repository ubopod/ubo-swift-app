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

    // MARK: - Skip-ahead recovery (mirrors Android's SKIP_AHEAD_TIMEOUT_MS)

    func testGapFillingWithinTimeoutDoesNotSkip() {
        var state = AudioPlaybackService.SequenceState()
        let t0 = Date(timeIntervalSince1970: 0)
        _ = AudioPlaybackService.merge(index: 0, sample: sample(0), volume: 1, into: &state, now: t0)
        // Index 2 arrives first, index 1 is still missing: this is a gap, not a skip.
        let stuck = AudioPlaybackService.merge(index: 2, sample: sample(2), volume: 1, into: &state, now: t0)
        XCTAssertEqual(stuck.ready.count, 0)
        // Index 1 fills the gap well before the 5s timeout: normal drain, no skip.
        let filled = AudioPlaybackService.merge(
            index: 1, sample: sample(1), volume: 1, into: &state, now: t0.addingTimeInterval(2)
        )
        XCTAssertEqual(bytes(filled.ready), [1, 2])
    }

    func testGapPastTimeoutSkipsAheadAndDiscardsStaleEntries() {
        var state = AudioPlaybackService.SequenceState()
        let t0 = Date(timeIntervalSince1970: 0)
        _ = AudioPlaybackService.merge(index: 0, sample: sample(0), volume: 1, into: &state, now: t0)
        // Index 1 never arrives. 5 and 6 pile up behind the gap.
        _ = AudioPlaybackService.merge(index: 5, sample: sample(5), volume: 1, into: &state, now: t0)
        _ = AudioPlaybackService.merge(
            index: 6, sample: sample(6), volume: 1, into: &state, now: t0.addingTimeInterval(1)
        )
        // Past the 5s timeout since the gap was first observed: skip ahead to 5.
        let skipped = AudioPlaybackService.merge(
            index: 7, sample: sample(7), volume: 1, into: &state, now: t0.addingTimeInterval(6)
        )
        XCTAssertEqual(bytes(skipped.ready), [5, 6, 7])
    }

    func testSkipAheadDoesNotRecurSpuriouslyAfterRecovery() {
        var state = AudioPlaybackService.SequenceState()
        let t0 = Date(timeIntervalSince1970: 0)
        _ = AudioPlaybackService.merge(index: 0, sample: sample(0), volume: 1, into: &state, now: t0)
        _ = AudioPlaybackService.merge(index: 5, sample: sample(5), volume: 1, into: &state, now: t0)
        _ = AudioPlaybackService.merge(
            index: 6, sample: sample(6), volume: 1, into: &state, now: t0.addingTimeInterval(6)
        )
        // Skip already fired above: nextIndex jumped to 5, drained through 6, nextIndex is now 7,
        // and stuckSince was reset to nil by that drain.
        // A brand-new gap starts here — its own timer must start from *this* moment, not be
        // considered already-expired just because 6+ seconds have elapsed since t0.
        _ = AudioPlaybackService.merge(
            index: 9, sample: sample(9), volume: 1, into: &state, now: t0.addingTimeInterval(6.1)
        )
        let notYetStuck = AudioPlaybackService.merge(
            index: 10, sample: sample(10), volume: 1, into: &state, now: t0.addingTimeInterval(8)
        )
        XCTAssertEqual(notYetStuck.ready.count, 0, "a fresh gap must not skip before its own timeout elapses")

        // Only once the *new* gap's own timer actually expires does it skip ahead.
        let skipped = AudioPlaybackService.merge(
            index: 11, sample: sample(11), volume: 1, into: &state, now: t0.addingTimeInterval(11.2)
        )
        XCTAssertEqual(bytes(skipped.ready), [9, 10, 11])
    }
}
