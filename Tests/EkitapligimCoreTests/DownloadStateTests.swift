import XCTest
@testable import EkitapligimCore

final class DownloadStateTests: XCTestCase {
    func testDownloadStateCarriesFailureMessage() {
        let state = DownloadState.failed(message: "Yetersiz depolama alanı.")

        XCTAssertEqual(state, .failed(message: "Yetersiz depolama alanı."))
    }
}
