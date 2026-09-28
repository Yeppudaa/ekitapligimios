import XCTest
@testable import EkitapligimCore

final class ReaderLoadingProgressTests: XCTestCase {
    func testKnownLengthUsesTransferredBytesForPercentage() {
        let progress = BookTransferProgress(receivedBytes: 125, expectedBytes: 500)
        XCTAssertEqual(progress.fraction, 0.25)
        XCTAssertEqual(progress.percent, 25)
        XCTAssertEqual(BookTransferProgress(receivedBytes: 1, expectedBytes: 3).percent, 33)
    }

    func testUnknownLengthRemainsIndeterminate() {
        for expected in [Int64(-1), 0] {
            let progress = BookTransferProgress(receivedBytes: 524_288, expectedBytes: expected)
            XCTAssertNil(progress.expectedBytes)
            XCTAssertNil(progress.fraction)
            XCTAssertNil(progress.percent)
            XCTAssertFalse(progress.byteDescription.isEmpty)
        }
    }

    func testInvalidCountsCannotProduceNegativeOrOverFullProgress() {
        XCTAssertEqual(BookTransferProgress(receivedBytes: -10, expectedBytes: 100).receivedBytes, 0)
        XCTAssertEqual(BookTransferProgress(receivedBytes: -10, expectedBytes: 100).percent, 0)
        XCTAssertEqual(BookTransferProgress(receivedBytes: 200, expectedBytes: 100).percent, 100)
        XCTAssertEqual(BookTransferProgress(receivedBytes: .max, expectedBytes: 1).fraction, 1)
    }

    func testOnlyDownloadingPhaseExposesTransferPercentage() {
        let progress = BookTransferProgress(receivedBytes: 500, expectedBytes: 1_000)
        XCTAssertEqual(ReaderLoadingPhase.downloading(progress).transfer, progress)
        for phase in [ReaderLoadingPhase.authorizing, .restoring, .validating, .opening] {
            XCTAssertNil(phase.transfer)
            XCTAssertFalse(phase.title.isEmpty)
        }
    }
}
