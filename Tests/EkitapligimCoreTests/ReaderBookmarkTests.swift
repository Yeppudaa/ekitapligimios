import XCTest
@testable import EkitapligimCore

final class ReaderBookmarkTests: XCTestCase {
    func testToggleAddsAndRemovesBookmark() {
        var bookmarks = ReaderBookmarks()
        bookmarks.toggle(bookID: 42, page: 8)
        XCTAssertTrue(bookmarks.contains(bookID: 42, page: 8))
        bookmarks.toggle(bookID: 42, page: 8)
        XCTAssertFalse(bookmarks.contains(bookID: 42, page: 8))
    }

    func testBookmarksAreSeparatedByBookAndSortedByPage() {
        let bookmarks = ReaderBookmarks(items: [
            ReaderBookmark(bookID: 2, page: 9),
            ReaderBookmark(bookID: 1, page: 12),
            ReaderBookmark(bookID: 1, page: 3),
            ReaderBookmark(bookID: 1, page: 3)
        ])
        XCTAssertEqual(bookmarks.bookmarks(for: 1).map(\.page), [3, 12])
        XCTAssertEqual(bookmarks.bookmarks(for: 2).map(\.page), [9])
    }

    func testPageIsClampedToFirstPage() {
        XCTAssertEqual(ReaderBookmark(bookID: 1, page: 0).page, 1)
    }

    func testCollectionRoundTripsThroughJSON() throws {
        let original = ReaderBookmarks(items: [ReaderBookmark(bookID: 7, page: 21)])
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ReaderBookmarks.self, from: data), original)
    }
}
