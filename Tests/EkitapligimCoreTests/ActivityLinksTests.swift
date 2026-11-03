import XCTest
@testable import EkitapligimCore

final class ActivityLinksTests: XCTestCase {
    func testBookAndMemberNamesHaveIndependentDestinations() throws {
        let item = try decode(#"{"id":"event1","type":"comment","actor":{"id":19,"username":"Ada"},"book":{"id":42,"title":"İnce Memed"},"app_route":"thread/71"}"#)
        XCTAssertEqual(item.memberDestination, .member(19))
        XCTAssertEqual(item.bookDestination, .bookDetail(42))
        XCTAssertEqual(item.nativeDestination, .thread(71))
        let runs = ActivityLinks.runs(message: "Ada, İnce Memed kitabına yorum yaptı.", actor: "Ada", memberRoute: item.memberDestination,
                                      book: "İnce Memed", bookRoute: item.bookDestination)
        XCTAssertEqual(runs.filter { $0.route != nil }.map(\.route), [.member(19), .bookDetail(42)])
        XCTAssertEqual(runs.map(\.text).joined(), "Ada, İnce Memed kitabına yorum yaptı.")
    }

    func testAudioAliasesAndEmptyAudioIDKeepAudioNamespace() throws {
        for type in ActivityPresentation.audioTypes {
            let item = try decode("""
                {"id":"a","type":"\(type)","audio_book_id":"","actor":{"id":2},"book":{"id":31},"app_route":"member/2"}
                """)
            XCTAssertEqual(item.bookDestination, .audiobook(31), type)
        }
        let content = try decode(#"{"id":"a","type":"favorite","content_type":"audio_book","book":{"id":13}}"#)
        XCTAssertEqual(content.bookDestination, .audiobook(13))
    }

    func testInvalidIDsAndMissingBookCannotNavigateToWrongTable() throws {
        for id in ["0", "-2", "999999999999999999999"] {
            let item = try decode("""
                {"id":"event","actor":{"id":"\(id)"},"book":{"id":"\(id)"}}
                """)
            XCTAssertNil(item.memberDestination)
            XCTAssertNil(item.bookDestination)
        }
        let audio = try decode(#"{"id":"a","type":"audio_started","app_route":"detail/42"}"#)
        XCTAssertNil(audio.bookDestination)
    }

    func testSameActorAndBookLabelLinkDifferentOccurrences() {
        let message = "Ada, Ada kitabını okudu."
        let runs = ActivityLinks.runs(message: message, actor: "Ada", memberRoute: .member(2), book: "Ada", bookRoute: .bookDetail(9))
        XCTAssertEqual(runs.map(\.text).joined(), message)
        XCTAssertEqual(runs.filter { $0.route != nil }.map(\.route), [.member(2), .bookDetail(9)])
    }

    func testUsernameSubstringInsideBookTitleDoesNotBecomeMemberLink() {
        let runs = ActivityLinks.runs(message: "Ali Baba kitabı okundu.", actor: "Ali", memberRoute: .member(2),
                                      book: "Ali Baba", bookRoute: .bookDetail(9))
        XCTAssertEqual(runs.filter { $0.route != nil }.map(\.route), [.bookDetail(9)])
        let other = ActivityLinks.runs(message: "Adana hakkında yazdı.", actor: "Ada", memberRoute: .member(2), book: "", bookRoute: nil)
        XCTAssertTrue(other.allSatisfy { $0.route == nil })
    }

    func testUnicodePunctuationAndUnmatchedTextRemainIntact() {
        let message = "📚 Çağrı, ‘Şeker Portakalı’ kitabını okuyor. https://example.invalid/"
        let runs = ActivityLinks.runs(message: message, actor: "Çağrı", memberRoute: .member(7),
                                      book: "Şeker Portakalı", bookRoute: .bookDetail(8))
        XCTAssertEqual(runs.map(\.text).joined(), message)
        XCTAssertEqual(runs.filter { $0.route != nil }.count, 2)
        XCTAssertEqual(ActivityLinks.runs(message: "", actor: "", memberRoute: nil, book: "", bookRoute: nil), [])
    }

    private func decode(_ json: String) throws -> LiveActivityItemDTO {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(LiveActivityItemDTO.self, from: Data(json.utf8))
    }
}
