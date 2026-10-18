import XCTest
@testable import EkitapligimCore

final class MyAudioCommentsTests: XCTestCase {
    func testEndpointUsesAuthenticatedNativeAPIAndRequestedPage() throws {
        let endpoint = APIEndpoint.myAudioComments(page: 3)
        let base = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        let url = try endpoint.url(relativeTo: base)

        XCTAssertEqual(endpoint.method, .get)
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertEqual(endpoint.path, "me/audio-comments")
        XCTAssertEqual(url.path, "/ios-api/v1/me/audio-comments")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                       [URLQueryItem(name: "page", value: "3")])
        XCTAssertNil(endpoint.body)
    }

    func testEndpointClampsInvalidPagesToFirstPage() {
        for page in [Int.min, -1, 0, 1] {
            XCTAssertEqual(APIEndpoint.myAudioComments(page: page).queryItems,
                           [URLQueryItem(name: "page", value: "1")])
        }
    }

    func testScopedPageDecodesNativeCommentAndSnakeCasePagination() throws {
        let result = try decode([
            "scope": "audio",
            "comments": [["post_id": 41, "thread_id": 52, "thread_title": "Kitap",
                          "message": "Güzel bir seslendirme.", "post_date": 1_792_280_000]],
            "pagination": ["current_page": 2, "pages": 4, "total": 61]
        ])

        XCTAssertEqual(result.comments.map(\.id), ["41"])
        XCTAssertEqual(result.comments.first?.threadId, "52")
        XCTAssertEqual(result.comments.first?.threadTitle, "Kitap")
        XCTAssertEqual(result.comments.first?.message, "Güzel bir seslendirme.")
        XCTAssertEqual(result.currentPage, 2)
        XCTAssertEqual(result.lastPage, 4)
        XCTAssertEqual(result.total, 61)
    }

    func testItemsAndPageAliasesAreSupportedForEmptyResults() throws {
        let result = try decode(["scope": "audio", "items": [],
                                 "pagination": ["page": 1, "pages": 1, "total": 0]])
        XCTAssertTrue(result.comments.isEmpty)
        XCTAssertEqual(result.currentPage, 1)
        XCTAssertEqual(result.lastPage, 1)
        XCTAssertEqual(result.total, 0)
    }

    func testMissingOrDifferentScopeCannotBecomePersonalAudioHistory() {
        let pagination = ["page": 1, "pages": 1]
        XCTAssertThrowsError(try decode(["comments": [], "pagination": pagination]))
        for scope in ["forum", "all", "Audio", ""] {
            XCTAssertThrowsError(try decode(["scope": scope, "comments": [], "pagination": pagination]))
        }
    }

    func testMalformedCommentIdentifiersAreRejected() {
        let invalidIDs: [(Any, Any)] = [
            (0, 2), (-1, 2), ("invalid", 2), (1, 0), (1, -1),
            (1, "invalid"), (1, Int64(Int32.max) + 1)
        ]
        for (postID, threadID) in invalidIDs {
            XCTAssertThrowsError(try decode([
                "scope": "audio", "comments": [["id": postID, "thread_id": threadID]],
                "pagination": ["page": 1, "pages": 1]
            ]), "Invalid identifiers must not create audiobook navigation destinations")
        }
    }

    func testMissingOrMalformedPaginationIsRejected() {
        let invalidPagination: [[String: Any]] = [
            [:], ["page": 1], ["pages": 1], ["page": 0, "pages": 1],
            ["page": -1, "pages": 1], ["page": 1, "pages": 0],
            ["page": 1, "pages": -1], ["page": 2, "pages": 1],
            ["page": 1, "pages": 1, "total": -1], ["page": "one", "pages": 1]
        ]
        for pagination in invalidPagination {
            XCTAssertThrowsError(try decode(["scope": "audio", "comments": [], "pagination": pagination]))
        }
        XCTAssertThrowsError(try decode(["scope": "audio", "comments": []]))
    }

    private func decode(_ payload: [String: Any]) throws -> MyAudioCommentsPageDTO {
        try JSONDecoder.ekitapligim.decode(MyAudioCommentsPageDTO.self,
            from: JSONSerialization.data(withJSONObject: payload))
    }
}
