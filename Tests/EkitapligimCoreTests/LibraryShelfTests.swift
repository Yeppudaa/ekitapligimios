import XCTest
@testable import EkitapligimCore

final class LibraryShelfTests: XCTestCase {
    func testReadingShelfMatchesAndroidCodes() {
        XCTAssertTrue(makeItem(shelfState: "OKUYORUM").isOnReadingShelf)
        XCTAssertTrue(makeItem(shelfState: "reading", progressPercent: 45).isOnReadingShelf)
        XCTAssertFalse(makeItem(shelfState: "OKUYACAGIM").isOnReadingShelf)
    }

    func testWantToReadShelfMatchesAndroidCodes() {
        XCTAssertTrue(makeItem(shelfState: "OKUYACAGIM").isOnWantToReadShelf)
        XCTAssertTrue(makeItem(shelfState: "want_to_read").isOnWantToReadShelf)
        XCTAssertFalse(makeItem(shelfState: "OKUYORUM").isOnWantToReadShelf)
    }

    func testFinishedShelfMatchesAndroidCodes() {
        XCTAssertTrue(makeItem(shelfState: "OKUDUM").isOnFinishedShelf)
        XCTAssertTrue(makeItem(shelfState: "read", progressPercent: 100).isOnFinishedShelf)
        XCTAssertFalse(makeItem(shelfState: "OKUYORUM").isOnFinishedShelf)
    }

    func testFavoriteItemUsesShelfStateOrFlag() {
        XCTAssertTrue(makeItem(shelfState: "FAVORI").isFavoriteItem)
        XCTAssertTrue(makeItem(shelfState: "NONE", isFavorite: true).isFavoriteItem)
        XCTAssertFalse(makeItem(shelfState: "OKUYORUM").isFavoriteItem)
    }

    func testReadingProgressForShelfUpdatePreservesValues() {
        let item = makeItem(shelfState: "OKUYORUM", progressPercent: 42, lastReadPage: 17)
        let progress = item.readingProgressForShelfUpdate
        XCTAssertEqual(progress.percent, 42)
        XCTAssertEqual(progress.page, 17)
    }

    func testDisplayShelfStateForMenuPreservesReadingShelfWhenFavorite() {
        let item = makeItem(shelfState: "FAVORI", progressPercent: 42, lastReadPage: 17, isFavorite: true)
        XCTAssertEqual(item.displayShelfStateForMenu, "OKUYORUM")
    }

    func testDisplayShelfStateForMenuUsesExplicitShelfCodes() {
        XCTAssertEqual(makeItem(shelfState: "OKUYACAGIM").displayShelfStateForMenu, "OKUYACAGIM")
        XCTAssertEqual(makeItem(shelfState: "OKUDUM").displayShelfStateForMenu, "OKUDUM")
    }

    func testLibraryItemUpdatingPreservesUntouchedFields() {
        let item = makeItem(shelfState: "OKUYORUM", progressPercent: 10, lastReadPage: 5)
        let updated = item.updating(progressPercent: 42, lastReadPage: 17)
        XCTAssertEqual(updated.progressPercent, 42)
        XCTAssertEqual(updated.lastReadPage, 17)
        XCTAssertEqual(updated.shelfState, "OKUYORUM")
    }

    func testDisplayProgressPercentFallsBackToPageRatio() {
        let item = makeItem(shelfState: "OKUYORUM", progressPercent: 0, lastReadPage: 25)
        // pageCount defaults to 100 in makeItem
        XCTAssertEqual(item.displayProgressPercent, 25)
    }

    func testDisplayProgressPercentFinishedShelfIsAlways100() {
        XCTAssertEqual(makeItem(shelfState: "OKUDUM", progressPercent: 40, lastReadPage: 10).displayProgressPercent, 100)
    }

    func testDisplayProgressPercentIgnoresFirstPageOnly() {
        // Android libraryProgress requires lastReadPage > 1 before deriving percent.
        XCTAssertEqual(makeItem(shelfState: "OKUYORUM", progressPercent: 0, lastReadPage: 1).displayProgressPercent, 0)
    }

    func testLibraryMetaTextMatchesAndroidShelfLabels() {
        XCTAssertEqual(makeItem(shelfState: "OKUDUM").libraryMetaText, L10n.libraryMetaFinished)
        XCTAssertEqual(makeItem(shelfState: "OKUYACAGIM").libraryMetaText, L10n.libraryMetaWantToRead)
        XCTAssertEqual(makeItem(shelfState: "OKUYORUM", lastReadPage: 12).libraryMetaText, L10n.libraryMetaLastPage(12))
        XCTAssertEqual(makeItem(shelfState: "OKUYORUM", progressPercent: 30, lastReadPage: 0).libraryMetaText, L10n.libraryMetaLastPage(1))
        XCTAssertEqual(makeItem(shelfState: "OKUYORUM", isDownloaded: true).libraryMetaText, L10n.libraryMetaDownloaded)
        XCTAssertEqual(makeItem(shelfState: "OKUYORUM", isFavorite: true).libraryMetaText, L10n.libraryMetaFavorite)
        XCTAssertEqual(makeItem(shelfState: "OKUYORUM").libraryMetaText, L10n.libraryMetaContinue)
        XCTAssertEqual(makeItem(shelfState: "FAVORI", isFavorite: true).libraryMetaText, L10n.libraryMetaFavorite)
    }

    private func makeItem(
        shelfState: String,
        progressPercent: Int = 0,
        lastReadPage: Int = 0,
        isFavorite: Bool = false,
        isDownloaded: Bool = false
    ) -> LibraryItemDTO {
        LibraryItemDTO(
            bookId: "123",
            shelfState: shelfState,
            progressPercent: progressPercent,
            lastReadPage: lastReadPage,
            isDownloaded: isDownloaded,
            isFavorite: isFavorite,
            title: "Test",
            author: "Author",
            coverUrl: "",
            pageCount: 100
        )
    }
}
