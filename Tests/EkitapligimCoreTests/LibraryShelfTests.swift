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

    func testContinueReadingPrefersMostRecentlyReadBook() {
        let olderHighProgress = makeItem(bookId: "old", shelfState: "OKUYORUM", progressPercent: 80, lastReadPage: 200, lastReadAt: 100)
        let newestLowProgress = makeItem(bookId: "new", shelfState: "OKUYORUM", progressPercent: 10, lastReadPage: 12, lastReadAt: 500)
        let items = [olderHighProgress, newestLowProgress]

        XCTAssertEqual(items.continueReadingItem()?.bookId, "new")
    }

    func testContinueReadingFallsBackToLibraryOrderWhenTimestampsAreMissing() {
        let first = makeItem(bookId: "first", shelfState: "OKUYORUM", progressPercent: 10, lastReadPage: 4)
        let later = makeItem(bookId: "later", shelfState: "OKUYORUM", progressPercent: 90, lastReadPage: 180)
        let items = [first, later]

        XCTAssertEqual(items.continueReadingItem()?.bookId, "first")
    }

    func testContinueReadingSkipsFinishedBooks() {
        let finished = makeItem(bookId: "done", shelfState: "OKUDUM", progressPercent: 100, lastReadPage: 300, lastReadAt: 900)
        let reading = makeItem(bookId: "reading", shelfState: "OKUYORUM", progressPercent: 20, lastReadPage: 40, lastReadAt: 100)

        XCTAssertEqual([finished, reading].continueReadingItem()?.bookId, "reading")
    }

    func testContinueReadingUsesRecentlyReadBookOutsideReadingShelf() {
        let want = makeItem(bookId: "want", shelfState: "OKUYACAGIM", progressPercent: 5, lastReadPage: 9, lastReadAt: 800)
        let reading = makeItem(bookId: "reading", shelfState: "OKUYORUM", progressPercent: 50, lastReadPage: 80, lastReadAt: 100)

        XCTAssertEqual([reading, want].continueReadingItem()?.bookId, "want")
    }

    func testMergingRecencyKeepsNewerLocalProgress() {
        let server = makeItem(bookId: "1", shelfState: "OKUYORUM", progressPercent: 10, lastReadPage: 8, lastReadAt: 50)
        let local = makeItem(bookId: "1", shelfState: "OKUYORUM", progressPercent: 22, lastReadPage: 18, lastReadAt: 80)

        let merged = LibraryItemDTO.mergingRecency(server: [server], local: [local])

        XCTAssertEqual(merged.first?.progressPercent, 22)
        XCTAssertEqual(merged.first?.lastReadPage, 18)
        XCTAssertEqual(merged.first?.lastReadAt, 80)
    }

    func testLibraryItemDecodesStringProgressAndLastReadAt() throws {
        let data = Data("""
        {
          "book_id": "15582",
          "shelf_state": "OKUYORUM",
          "progress_percent": "40",
          "last_read_page": "12",
          "last_read_at": "1700000000",
          "title": "Dune",
          "author": "Frank Herbert",
          "cover_url": "",
          "page_count": "320"
        }
        """.utf8)

        let item = try JSONDecoder.ekitapligim.decode(LibraryItemDTO.self, from: data)

        XCTAssertEqual(item.bookId, "15582")
        XCTAssertEqual(item.progressPercent, 40)
        XCTAssertEqual(item.lastReadPage, 12)
        XCTAssertEqual(item.lastReadAt, 1700000000)
        XCTAssertEqual(item.pageCount, 320)
    }

    private func makeItem(
        bookId: String = "123",
        shelfState: String,
        progressPercent: Int = 0,
        lastReadPage: Int = 0,
        isFavorite: Bool = false,
        isDownloaded: Bool = false,
        lastReadAt: Int = 0
    ) -> LibraryItemDTO {
        LibraryItemDTO(
            bookId: bookId,
            shelfState: shelfState,
            progressPercent: progressPercent,
            lastReadPage: lastReadPage,
            isDownloaded: isDownloaded,
            isFavorite: isFavorite,
            title: "Test",
            author: "Author",
            coverUrl: "",
            pageCount: 100,
            lastReadAt: lastReadAt
        )
    }
}
