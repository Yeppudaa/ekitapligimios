import XCTest
@testable import EkitapligimCore

final class ReaderPreviewLimitTests: XCTestCase {
    func testPage9IsStillFreeAndPage10IsTheLimit() {
        let page9 = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 9,
            documentPageCount: 240,
            catalogPageCount: 240
        )
        XCTAssertTrue(page9.hasLockedContent)
        XCTAssertEqual(page9.accessiblePageLimit, 10)
        XCTAssertEqual(page9.lastFreePage, 9)
        XCTAssertFalse(page9.isOnLimitPage)
        XCTAssertFalse(page9.blocks(9))
        XCTAssertFalse(page9.blocks(10))
        XCTAssertTrue(page9.blocks(11))

        let page10 = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 10,
            documentPageCount: 240,
            catalogPageCount: 240
        )
        XCTAssertTrue(page10.isOnLimitPage)
        XCTAssertEqual(page10.clamped(11), 10)
        XCTAssertEqual(page10.clamped(10), 10)
        XCTAssertEqual(page10.clamped(9), 9)
    }

    func testLimitNoticeAppearsWhenLeavingPage9() {
        let finishedPage9 = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 10,
            documentPageCount: 240,
            catalogPageCount: 240
        )
        XCTAssertGreaterThanOrEqual(finishedPage9.currentPage, finishedPage9.lastFreePage + 1)
        XCTAssertTrue(finishedPage9.isOnLimitPage)
        XCTAssertFalse(finishedPage9.blocks(finishedPage9.accessiblePageLimit))
    }

    func testTruncatedTenPagePreviewStillShowsLimit() {
        let limit = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 10,
            documentPageCount: 10,
            catalogPageCount: 0
        )
        XCTAssertTrue(limit.hasLockedContent)
        XCTAssertTrue(limit.isOnLimitPage)
        XCTAssertEqual(limit.lastFreePage, 9)
    }

    func testShortBookDoesNotLock() {
        let limit = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 8,
            documentPageCount: 8,
            catalogPageCount: 8
        )
        XCTAssertFalse(limit.hasLockedContent)
        XCTAssertFalse(limit.isOnLimitPage)
        XCTAssertEqual(limit.clamped(8), 8)
    }

    func testPremiumReaderHasNoPreviewLimit() {
        let limit = ReaderPreviewLimit(
            isPreviewMode: false,
            currentPage: 10,
            documentPageCount: 240,
            catalogPageCount: 240
        )
        XCTAssertFalse(limit.hasLockedContent)
        XCTAssertFalse(limit.isOnLimitPage)
        XCTAssertEqual(limit.accessiblePageLimit, 240)
        XCTAssertEqual(limit.clamped(180), 180)
    }

    func testCatalogPageCountCanLockBeforePDFReportsTotal() {
        let limit = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 10,
            documentPageCount: 1,
            catalogPageCount: 180
        )
        XCTAssertTrue(limit.hasLockedContent)
        XCTAssertTrue(limit.isOnLimitPage)
        XCTAssertEqual(limit.accessiblePageLimit, 10)
    }

    func testPreviewNoticeWaitsForRestoreThenPresentsOnceOnPage10() {
        var presentation = ReaderPreviewPresentation()
        let page9 = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 9,
            documentPageCount: 240,
            catalogPageCount: 240
        )
        let page10 = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 10,
            documentPageCount: 240,
            catalogPageCount: 240
        )

        XCTAssertEqual(presentation.handle(page10).event, .none)

        presentation.markRestored()
        XCTAssertEqual(presentation.handle(page9).event, .none)

        let first = presentation.handle(page10)
        XCTAssertEqual(first.event, .presentLimit)
        XCTAssertEqual(first.page, 10)
        XCTAssertEqual(presentation.handle(page10).event, .none)
    }

    func testBlockedPageDoesNotOpenPremiumWhileLimitIsVisible() {
        var presentation = ReaderPreviewPresentation(isReaderRestored: true)
        let page10 = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 10,
            documentPageCount: 240,
            catalogPageCount: 240
        )
        let page11 = ReaderPreviewLimit(
            isPreviewMode: true,
            currentPage: 11,
            documentPageCount: 240,
            catalogPageCount: 240
        )

        XCTAssertEqual(presentation.handle(page10).event, .presentLimit)
        let whileVisible = presentation.handle(page11)
        XCTAssertEqual(whileVisible.event, .clampOnly)
        XCTAssertEqual(whileVisible.page, 10)

        presentation.dismissLimit()
        let afterDismiss = presentation.handle(page11)
        XCTAssertEqual(afterDismiss.event, .openPremium)
        XCTAssertEqual(afterDismiss.page, 10)
    }

    func testDeferredTeardownDoesNotRunSynchronously() async {
        let flag = TeardownFlag()
        ReaderDeferredTeardown.enqueue { flag.value = true }
        XCTAssertFalse(flag.value)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(flag.value)
    }
}

private final class TeardownFlag: @unchecked Sendable {
    var value = false
}
