import XCTest
@testable import EkitapligimCore

final class ReaderOpeningFrameTests: XCTestCase {
    func testLiftAndPaperMatchAndroidMilestones() {
        let first = ReaderOpeningFrame(elapsedMilliseconds: 0)
        XCTAssertEqual(first.lift, 0)
        XCTAssertEqual(first.coverAngle, 0)
        XCTAssertEqual(first.coverOpacity, 1)
        XCTAssertEqual(first.backdropOpacity, 0)
        XCTAssertFalse(first.paperVisible)
        let lifted = ReaderOpeningFrame(elapsedMilliseconds: 560)
        XCTAssertEqual(lifted.lift, 1)
        XCTAssertEqual(lifted.coverAngle, 0)
        XCTAssertTrue(lifted.paperVisible)
        XCTAssertEqual(lifted.paperExpansion, 0)
        XCTAssertEqual(lifted.backdropOpacity, 0.82, accuracy: 0.000001)
        XCTAssertGreaterThan(ReaderOpeningFrame(elapsedMilliseconds: 280).lift, 0.85,
                             "The Android lift decelerates early rather than using a linear interpolation")
    }

    func testLeftHingeAndCoverDissolveFinishBeforePaperHandoff() {
        let hinge = ReaderOpeningFrame(elapsedMilliseconds: 900)
        XCTAssertLessThan(hinge.coverAngle, -80)
        XCTAssertGreaterThan(hinge.coverAngle, -165)
        XCTAssertLessThan(hinge.coverOpacity, 1)
        XCTAssertGreaterThan(hinge.coverShadeOpacity, 0)
        let open = ReaderOpeningFrame(elapsedMilliseconds: 1_380)
        XCTAssertEqual(open.coverAngle, -178, accuracy: 0.000001)
        XCTAssertEqual(open.coverOpacity, 0)
        XCTAssertGreaterThan(open.paperExpansion, 0)
        XCTAssertLessThan(open.paperExpansion, 1)
    }

    func testFullPaperCoversReaderBeforeQuadraticFadeBegins() {
        let handoff = ReaderOpeningFrame(elapsedMilliseconds: 1_640)
        XCTAssertEqual(handoff.paperExpansion, 1)
        XCTAssertEqual(handoff.backdropOpacity, 0)
        XCTAssertEqual(handoff.overlayOpacity, 1)
        XCTAssertEqual(ReaderOpeningFrame(elapsedMilliseconds: 1_920).overlayOpacity, 1)
        XCTAssertEqual(ReaderOpeningFrame(elapsedMilliseconds: 2_040).overlayOpacity, 0.25)
        XCTAssertEqual(ReaderOpeningFrame(elapsedMilliseconds: 2_160).overlayOpacity, 0)
    }

    func testAllSampledFramesHaveBoundedMonotonicMotion() {
        var previous = ReaderOpeningFrame(elapsedMilliseconds: 0)
        for elapsed in stride(from: 8.0, through: 2_200, by: 8) {
            let frame = ReaderOpeningFrame(elapsedMilliseconds: elapsed)
            XCTAssertGreaterThanOrEqual(frame.lift, previous.lift)
            XCTAssertGreaterThanOrEqual(frame.hinge, previous.hinge)
            XCTAssertGreaterThanOrEqual(frame.paperExpansion, previous.paperExpansion)
            XCTAssertLessThanOrEqual(frame.coverOpacity, previous.coverOpacity)
            XCTAssertLessThanOrEqual(frame.overlayOpacity, previous.overlayOpacity)
            for value in [frame.lift, frame.hinge, frame.paperExpansion, frame.coverOpacity,
                          frame.overlayOpacity, frame.coverShadeOpacity, frame.backdropOpacity] {
                XCTAssertTrue((0...1).contains(value))
            }
            previous = frame
        }
    }

    func testInvalidAndOutOfRangeClockValuesRemainStable() {
        let first = ReaderOpeningFrame(elapsedMilliseconds: 0)
        for value in [-100.0, -.infinity, .nan] {
            XCTAssertEqual(ReaderOpeningFrame(elapsedMilliseconds: value), first)
        }
        XCTAssertEqual(ReaderOpeningFrame(elapsedMilliseconds: .infinity),
                       ReaderOpeningFrame(elapsedMilliseconds: 2_160))
        XCTAssertFalse(ReaderL10n.text("opening.title").isEmpty)
        XCTAssertNotEqual(ReaderL10n.text("opening.title"), "opening.title")
    }
}

@MainActor
final class ReaderOpeningSequenceTests: XCTestCase {
    func testNormalSequenceHoldsPaperUntilSingleReaderHandoff() async {
        var delays: [Duration] = []
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence(sleep: { delays.append($0) })
        await sequence.run(reduceMotion: false) { phases.append($0) }
        XCTAssertEqual(delays, [.milliseconds(1_640), .milliseconds(520)])
        XCTAssertEqual(phases, [.opening, .revealing, .finished])
        XCTAssertTrue(sequence.phase.showsReader)
        // Reappearing from settings must not replay or mount another reader.
        await sequence.run(reduceMotion: false) { phases.append($0) }
        XCTAssertEqual(delays.count, 2)
        XCTAssertEqual(phases.filter { $0 == .revealing }.count, 1)
    }

    func testReducedMotionSkipsLiftAndHingeAndOnlyCrossfades() async {
        var delays: [Duration] = []
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence(sleep: { delays.append($0) })
        await sequence.run(reduceMotion: true) { phases.append($0) }
        XCTAssertEqual(delays, [.milliseconds(180)])
        XCTAssertEqual(phases, [.opening, .revealing, .finished])
        XCTAssertTrue(sequence.reducesMotion)
    }

    func testDismissalBeforeHandoffCannotOpenReaderLater() async {
        let began = expectation(description: "Opening began")
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence()
        let task = Task {
            await sequence.run(reduceMotion: false) {
                phases.append($0)
                if $0 == .opening { began.fulfill() }
            }
        }
        await fulfillment(of: [began], timeout: 2)
        sequence.cancel()
        task.cancel()
        await task.value
        XCTAssertEqual(phases, [.opening, .cancelled])
        XCTAssertFalse(sequence.phase.showsReader)
    }

    func testCancelledSleepNeverCallsHandoff() async {
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence(sleep: { _ in throw CancellationError() })
        await sequence.run(reduceMotion: false) { phases.append($0) }
        XCTAssertEqual(phases, [.opening, .cancelled])
    }

    func testTaskCancellationDuringRevealKeepsTheMountedReader() async {
        var calls = 0
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence(sleep: { _ in
            calls += 1
            if calls == 2 { throw CancellationError() }
        })
        await sequence.run(reduceMotion: false) { phases.append($0) }
        XCTAssertEqual(phases, [.opening, .revealing, .finished])
        XCTAssertEqual(phases.filter { $0 == .revealing }.count, 1)
        XCTAssertTrue(sequence.phase.showsReader)
    }

    func testChildPresentationDuringRevealSettlesWithoutUnmountingOrReplayingReader() async {
        var delays: [Duration] = []
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence(sleep: { delays.append($0) })
        await sequence.run(reduceMotion: false) { phase in
            phases.append(phase)
            if phase == .revealing { sequence.presentationDisappeared() }
        }
        XCTAssertEqual(phases, [.opening, .revealing, .finished])
        XCTAssertEqual(delays, [.milliseconds(1_640)])
        await sequence.run(reduceMotion: false) { phases.append($0) }
        XCTAssertEqual(phases.filter { $0 == .revealing }.count, 1)
        XCTAssertTrue(sequence.phase.showsReader)
    }

    func testExplicitDismissalAfterHandoffStillCancels() async {
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence(sleep: { _ in })
        await sequence.run(reduceMotion: false) { phase in
            phases.append(phase)
            if phase == .revealing { sequence.cancel() }
        }
        XCTAssertEqual(phases, [.opening, .revealing, .cancelled])
        XCTAssertFalse(sequence.phase.showsReader)
    }

    func testSourceDisappearanceBeforeHandoffCannotOpenReader() async {
        var delays: [Duration] = []
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence(sleep: { delays.append($0) })
        await sequence.run(reduceMotion: false) { phase in
            phases.append(phase)
            if phase == .opening { sequence.presentationDisappeared() }
        }
        XCTAssertEqual(phases, [.opening, .cancelled])
        XCTAssertTrue(delays.isEmpty)
    }

    func testAlreadyCancelledTaskReportsTerminalCancellationRatherThanIdle() async {
        let sequence = ReaderOpeningSequence(sleep: { _ in XCTFail("A cancelled task cannot begin opening") })
        var phases: [ReaderOpeningSequence.Phase] = []
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await sequence.run(reduceMotion: false) { phases.append($0) }
        }
        await task.value
        XCTAssertEqual(phases, [.cancelled])
        XCTAssertEqual(sequence.phase, .cancelled)
    }

    func testBackgroundingOrNewReduceMotionSettingSettlesWithoutAnotherDelay() async {
        var delays: [Duration] = []
        var phases: [ReaderOpeningSequence.Phase] = []
        let sequence = ReaderOpeningSequence(sleep: { delays.append($0) })
        await sequence.run(reduceMotion: false) { phase in
            phases.append(phase)
            if phase == .opening { sequence.finish() }
        }
        XCTAssertEqual(phases, [.opening, .finished])
        XCTAssertTrue(delays.isEmpty)
        sequence.cancel()
        XCTAssertEqual(sequence.phase, .finished)
    }

    func testAccountCancellationBeforeFirstFramePreventsRun() async {
        var delays: [Duration] = []
        let sequence = ReaderOpeningSequence(sleep: { delays.append($0) })
        sequence.cancel()
        await sequence.run(reduceMotion: false) { XCTAssertEqual($0, .cancelled) }
        XCTAssertTrue(delays.isEmpty)
        XCTAssertEqual(sequence.elapsedMilliseconds, 0)
    }
}
