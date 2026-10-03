import XCTest
@testable import EkitapligimCore

final class ReaderLibraryProjectionTests: XCTestCase {
    func testPendingPagePublishesImmediatelyAndPreservesShelfAndFavorites() throws {
        let saved = record(page: 40, pending: true, changedAt: 900)
        let updated = try XCTUnwrap(project(saved, existing: item()))
        XCTAssertEqual(updated.lastReadPage, 40)
        XCTAssertEqual(updated.progressPercent, 40)
        XCTAssertEqual(updated.lastReadAt, 900)
        XCTAssertEqual(updated.shelfState, "OKUYORUM")
        XCTAssertTrue(updated.isFavorite)
        XCTAssertTrue(updated.isDownloaded)
        XCTAssertEqual(updated.title, "Existing title")
    }

    func testAcknowledgedProgressUsesServerDateAndCanMoveBackwards() throws {
        let updated = try XCTUnwrap(project(record(page: 12), existing: item()))
        XCTAssertEqual(updated.lastReadPage, 12)
        XCTAssertEqual(updated.progressPercent, 12)
        XCTAssertEqual(updated.lastReadAt, 300)
    }

    func testRestoredBookOutsideShelvesBecomesContinueCandidateWhenMetadataArrives() throws {
        var saved = record(page: 25)
        XCTAssertNil(project(saved))
        saved.book = metadata
        let updated = try XCTUnwrap(project(saved))
        XCTAssertEqual(updated.bookId, "7")
        XCTAssertEqual(updated.title, metadata.title)
        XCTAssertEqual(updated.shelfState, "NONE")
        XCTAssertEqual([updated].continueReadingItem()?.lastReadPage, 25)
    }

    func testEPUBKeepsPercentAndDoesNotPretendCFIIsAPage() throws {
        var saved = SavedReaderProgress(position: ReaderPositionDTO(positionType: "epub",
            positionValue: "epubcfi(/6/2!/4/2/1:25)", progressPercent: 23.5, lastReadDate: 300), revision: "server")
        saved.book = metadata
        let updated = try XCTUnwrap(project(saved))
        XCTAssertEqual(updated.positionType, "epub")
        XCTAssertEqual(updated.lastReadPage, 0)
        XCTAssertEqual(updated.progressPercent, 24)
        XCTAssertTrue(updated.isContinueReadingCandidate)
    }

    func testServerResetClearsContinuePositionWithoutChangingShelfOrFlags() throws {
        let saved = SavedReaderProgress(position: nil, revision: "reset")
        let existing = item().updating(shelfState: "NONE")
        let updated = try XCTUnwrap(project(saved, existing: existing))
        XCTAssertEqual(updated.lastReadPage, 0)
        XCTAssertEqual(updated.lastReadAt, 0)
        XCTAssertEqual(updated.progressPercent, 0)
        XCTAssertTrue(updated.isFavorite)
        XCTAssertTrue(updated.isDownloaded)
        XCTAssertFalse(updated.isContinueReadingCandidate)
        XCTAssertNil(project(saved))
    }

    func testInvalidServerPositionCannotTrapOrReplaceLibraryData() {
        for percent in [Double.nan, .infinity, -1, 101] {
            let saved = SavedReaderProgress(position: ReaderPositionDTO(positionType: "pdf",
                positionValue: "25", progressPercent: percent), revision: "invalid")
            XCTAssertNil(project(saved, existing: item()))
        }
        let invalid = SavedReaderProgress(position: ReaderPositionDTO(positionType: "epub",
            positionValue: "25", progressPercent: 25), revision: "invalid")
        XCTAssertNil(project(invalid, existing: item()))
    }

    private let metadata = ReaderBookMetadata(title: "Restored title", author: "Author", coverURL: "", pageCount: 100)

    private func record(page: Int, pending: Bool = false, changedAt: Int = 900) -> SavedReaderProgress {
        SavedReaderProgress(position: ReaderPositionDTO(positionType: "pdf", positionValue: String(page),
            progressPercent: Double(page), lastReadDate: 300), revision: "server", pending: pending, changedAt: changedAt)
    }

    private func project(_ saved: SavedReaderProgress, existing: LibraryItemDTO? = nil) -> LibraryItemDTO? {
        ReaderLibraryProjection.item(bookID: 7, record: saved, existing: existing, isDownloaded: true)
    }

    private func item() -> LibraryItemDTO {
        LibraryItemDTO(bookId: "7", shelfState: "OKUYORUM", progressPercent: 40, lastReadPage: 40,
            isDownloaded: true, isFavorite: true, title: "Existing title", author: "Author", coverUrl: "", pageCount: 100,
            lastReadAt: 200)
    }
}
