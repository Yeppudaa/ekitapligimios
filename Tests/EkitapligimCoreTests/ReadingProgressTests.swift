import XCTest
@testable import EkitapligimCore

final class ReadingProgressTests: XCTestCase {
    func testProgressClampsPageAndCalculatesPercent() {
        let progress = ReadingProgress(currentPage: 150, totalPages: 100)

        XCTAssertEqual(progress.currentPage, 100)
        XCTAssertEqual(progress.percent, 100)
    }

    func testProgressNeverDividesByZero() {
        let progress = ReadingProgress(currentPage: 1, totalPages: 0)

        XCTAssertEqual(progress.totalPages, 1)
        XCTAssertEqual(progress.percent, 100)
    }
}
