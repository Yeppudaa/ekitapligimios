import XCTest
@testable import EkitapligimCore

/// Fulfilled requests open the real shelved book, and counters come from site-wide totals.
final class BookRequestLinkTests: XCTestCase {
    func testFulfilledRequestCarriesTheShelvedBookAndCover() throws {
        let page = try decode(#"""
        {"book_requests":[
          {"id":"467","request_id":467,"title":"His 3","author":"Durumavii","requested_by":"Ada","user_id":27195,
           "vote_count":1,"status":"ACQUIRED","created_at":1795035426,"book_id":"48612",
           "book":{"id":"48612","thread_id":48612,"title":"His 3 / Cehennem Ateşi","cover_url":"https://ekitapligim.com/data/books/covers/48/48612.jpg?1"}},
          {"id":"468","title":"Kızıltepe 4","author":"Hazal Aba","requested_by":"Ada","vote_count":1,"status":"PENDING",
           "book_id":null,"book":null}
        ],
        "stats":{"total":361,"pending":159,"acquired":202,"rejected":0,"support":597},
        "pagination":{"page":1,"per_page":100,"total":361,"pages":4,"has_more":true}}
        """#)
        let shelved = page.items[0]
        XCTAssertEqual(shelved.fulfilledBookID, "48612")
        XCTAssertEqual(shelved.fulfilledCoverURL, "https://ekitapligim.com/data/books/covers/48/48612.jpg?1")
        XCTAssertEqual(shelved.userId, 27195)
        XCTAssertEqual(shelved.createdAt, 1795035426)
        let open = page.items[1]
        XCTAssertNil(open.fulfilledBookID)
        XCTAssertNil(open.fulfilledCoverURL)
        XCTAssertEqual(page.stats?.total, 361)
        XCTAssertEqual(page.stats?.pending, 159)
        XCTAssertEqual(page.stats?.acquired, 202)
        XCTAssertEqual(page.stats?.support, 597)
        XCTAssertEqual(page.page, 1)
        XCTAssertTrue(page.hasMore)
    }

    func testBookObjectAloneStillLinksAndPendingNeverLinks() throws {
        let page = try decode(#"""
        {"items":[
          {"id":"1","title":"A","status":"ACQUIRED","book":{"id":"90","cover_url":"https://e/c.jpg"}},
          {"id":"2","title":"B","status":"PENDING","book_id":"91","book":{"id":"91","cover_url":"https://e/d.jpg"}},
          {"id":"3","title":"C","status":"ACQUIRED","book_id":0,"book":{"id":"92","cover_url":"  "}}
        ]}
        """#)
        XCTAssertEqual(page.items[0].fulfilledBookID, "90")
        XCTAssertEqual(page.items[0].fulfilledCoverURL, "https://e/c.jpg")
        XCTAssertNil(page.items[1].fulfilledBookID)
        XCTAssertNil(page.items[1].fulfilledCoverURL)
        XCTAssertEqual(page.items[2].fulfilledBookID, "92")
        XCTAssertNil(page.items[2].fulfilledCoverURL)
    }

    func testOlderServerResponseKeepsWorking() throws {
        let page = try decode(#"{"book_requests":[{"id":"5","title":"T","author":"A","requested_by":"u","vote_count":2,"status":"ACQUIRED"}]}"#)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertNil(page.items[0].fulfilledBookID)
        XCTAssertNil(page.stats)
        XCTAssertFalse(page.hasMore)
        XCTAssertEqual(page.page, 1)
    }

    func testPagesWithoutExplicitFlagUseThePageCount() throws {
        XCTAssertTrue(try decode(#"{"items":[],"pagination":{"page":2,"pages":3}}"#).hasMore)
        XCTAssertFalse(try decode(#"{"items":[],"pagination":{"page":3,"pages":3}}"#).hasMore)
    }

    func testFirstPageRequestStaysQueryFree() {
        XCTAssertTrue(APIEndpoint.bookRequests.queryItems.isEmpty)
        XCTAssertTrue(APIEndpoint.bookRequests(page: 1).queryItems.isEmpty)
        XCTAssertEqual(APIEndpoint.bookRequests(page: 3).queryItems, [URLQueryItem(name: "page", value: "3")])
        XCTAssertEqual(APIEndpoint.bookRequests(page: 3).path, "book-requests")
    }

    private func decode(_ json: String) throws -> BookRequestsPageDTO {
        try JSONDecoder.ekitapligim.decode(BookRequestsPageDTO.self, from: Data(json.utf8))
    }
}
