import XCTest
@testable import EkitapligimCore

/// Locks scoped UGC/library write contracts to Android `EKitapligimApi` + ios-api/v1 field names.
final class AndroidUGCParityContractTests: XCTestCase {
    func testBookRequestCreateAndVoteMatchAndroidSocialApi() {
        let create = APIEndpoint.createBookRequest(title: "Dune", author: "Frank Herbert", isbn: "9780441172719")
        XCTAssertEqual(create.path, "book-requests")
        XCTAssertEqual(create.method, .post)
        XCTAssertTrue(create.requiresAuthentication)
        XCTAssertEqual(form(create), [
            "title": "Dune",
            "author": "Frank Herbert",
            "isbn": "9780441172719"
        ])

        let withoutISBN = APIEndpoint.createBookRequest(title: "Dune", author: "Frank Herbert", isbn: "")
        XCTAssertEqual(form(withoutISBN), ["title": "Dune", "author": "Frank Herbert"])

        let vote = APIEndpoint.voteBookRequest(id: "42")
        XCTAssertEqual(vote.path, "book-requests/42/vote")
        XCTAssertEqual(vote.method, .post)
        XCTAssertTrue(vote.requiresAuthentication)
        XCTAssertNil(vote.body)
    }

    func testForumCreateAndReplyMatchAndroidAndIosApi() {
        let create = APIEndpoint.createForumThread(forumID: 12, title: "Başlık", message: "İlk mesaj")
        XCTAssertEqual(create.path, "forums/12/threads")
        XCTAssertEqual(create.method, .post)
        XCTAssertTrue(create.requiresAuthentication)
        XCTAssertEqual(form(create), ["title": "Başlık", "message": "İlk mesaj"])

        let reply = APIEndpoint.replyToThread(threadID: 99, message: "Cevap")
        XCTAssertEqual(reply.path, "threads/99/posts")
        XCTAssertEqual(reply.method, .post)
        XCTAssertTrue(reply.requiresAuthentication)
        XCTAssertEqual(form(reply), ["message": "Cevap"])
    }

    func testChatSendMatchesAndroidChatApi() {
        let send = APIEndpoint.sendChatMessage(roomID: "3", message: "Selam")
        XCTAssertEqual(send.path, "chat/rooms/3/messages")
        XCTAssertEqual(send.method, .post)
        XCTAssertTrue(send.requiresAuthentication)
        XCTAssertEqual(form(send), ["message": "Selam"])
    }

    func testBookCommentsMatchAndroidBookDetailApi() {
        let create = APIEndpoint.createBookComment(bookID: 15585, message: "Güzel kitap", rating: 5)
        XCTAssertEqual(create.path, "books/15585/comments")
        XCTAssertEqual(create.method, .post)
        XCTAssertTrue(create.requiresAuthentication)
        XCTAssertEqual(form(create), ["message": "Güzel kitap", "rating": "5"])
    }

    func testShelfUpdateMatchesAndroidLibraryApi() {
        let update = APIEndpoint.updateLibraryItem(
            bookID: 15582,
            shelfState: "OKUYORUM",
            progressPercent: 40,
            lastReadPage: 12
        )
        XCTAssertEqual(update.path, "me/library/15582")
        XCTAssertEqual(update.method, .put)
        XCTAssertTrue(update.requiresAuthentication)
        XCTAssertEqual(form(update), [
            "shelf_state": "OKUYORUM",
            "progress_percent": "40",
            "last_read_page": "12"
        ])
    }

    func testAgendaPostMatchesAndroidBookAgendaApi() {
        XCTAssertEqual(BookAgendaPostType.allCases.map(\.rawValue), [
            "standard", "book", "quotation", "review", "progress"
        ])

        let post = APIEndpoint.createBookAgendaPost(
            message: "Harika bir sahne",
            postType: .quotation,
            visibility: .public,
            bookThreadID: "15582",
            quotePostID: "88",
            reviewTitle: "Kısa not",
            rating: 4,
            pageNumber: 19,
            progressCurrent: 19,
            progressTotal: 320
        )
        XCTAssertEqual(post.path, "book-agenda")
        XCTAssertEqual(post.method, .post)
        XCTAssertEqual(form(post), [
            "message": "Harika bir sahne",
            "post_type": "quotation",
            "visibility": "public",
            "book_thread_id": "15582",
            "quote_post_id": "88",
            "review_title": "Kısa not",
            "rating": "4",
            "page_number": "19",
            "progress_current": "19",
            "progress_total": "320"
        ])
    }

    func testAgendaProgressValidationMatchesAndroidEmptyTotalAsZero() {
        XCTAssertFalse(BookAgendaComposerRules.isProgressCurrentExceedingTotal("", total: ""))
        XCTAssertFalse(BookAgendaComposerRules.isProgressCurrentExceedingTotal("10", total: "320"))
        XCTAssertTrue(BookAgendaComposerRules.isProgressCurrentExceedingTotal("5", total: ""))
        XCTAssertTrue(BookAgendaComposerRules.isProgressCurrentExceedingTotal("50", total: "40"))
        XCTAssertFalse(BookAgendaComposerRules.isProgressCurrentExceedingTotal("", total: "100"))
    }


    func testBookShareTextMatchesAndroidChooserPayload() {
        XCTAssertEqual(
            BookShareFormatting.urlString(pdfURL: "https://cdn.example/a.pdf", bookID: "15582"),
            "https://cdn.example/a.pdf"
        )
        XCTAssertEqual(
            BookShareFormatting.urlString(pdfURL: "  ", bookID: "15582"),
            "https://ekitapligim.com/threads/15582/"
        )
        XCTAssertEqual(
            BookShareFormatting.body(title: "Dune", author: "Frank Herbert", pdfURL: "", bookID: "42"),
            "Dune — Frank Herbert\nhttps://ekitapligim.com/threads/42/"
        )
    }

    private func form(_ endpoint: APIEndpoint) -> [String: String] {
        guard case let .form(fields)? = endpoint.body else {
            XCTFail("expected form body on \(endpoint.path)")
            return [:]
        }
        return fields
    }
}
