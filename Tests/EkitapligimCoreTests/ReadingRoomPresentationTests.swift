import Foundation
import XCTest
@testable import EkitapligimCore

final class ReadingRoomPresentationTests: XCTestCase {
    func testActualServerMessageRawPreservesLabelledLinksAndImageMetadata() throws {
        let raw = #"{"id":"1","conversation_id":7,"message":"Kitabı aç","message_raw":"[URL=https://ekitapligim.com/books/7/]Kitabı aç[/URL]","images":[{"id":21,"filename":"photo.jpg"}]}"#
        let dto = try JSONDecoder.ekitapligim.decode(ConversationMessageDTO.self, from: Data(raw.utf8))
        XCTAssertEqual(ConversationContentPresentation(dto.richMessage ?? "").links.first?.bookID, 7)
        XCTAssertEqual(dto.images.first?.id, "21")
    }

    func testConversationPaginationMatchesDeployedContract() throws {
        let dto = try JSONDecoder.ekitapligim.decode(ConversationDetailDTO.self, from: Data(#"{"conversation":{"id":7},"messages":[],"pagination":{"page":3,"pages":3,"total":109}}"#.utf8))
        XCTAssertEqual(dto.currentPage, 3); XCTAssertEqual(dto.lastPage, 3)
        let endpoint = APIEndpoint.conversation(id: "7", page: 2)
        XCTAssertEqual(endpoint.path, "conversation-detail/7")
        XCTAssertEqual(endpoint.queryItems, [URLQueryItem(name: "page", value: "2")])
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertTrue(APIEndpoint.conversation(id: "7").queryItems.isEmpty)
    }

    func testCardLimitDoesNotDiscardRemainingURLsFromMessage() {
        let value = ConversationContentPresentation((1...12).map { "https://example.com/\($0)" }.joined(separator: " "))
        XCTAssertEqual(value.links.count, 10)
        XCTAssertTrue(value.text.contains("https://example.com/11"))
        XCTAssertTrue(value.text.contains("https://example.com/12"))
        XCTAssertFalse(value.text.contains("https://example.com/9 "))
    }

    func testParenthesizedLinkHasOneCardWithoutRepeatedRawURL() {
        let value = ConversationContentPresentation("Bak (https://ekitapligim.com/books/7/)")
        XCTAssertEqual(value.links.first?.bookID, 7)
        XCTAssertFalse(value.text.contains("https://"))
    }

    func testLabelledLinksPastCardLimitRetainTheirDestination() {
        let raw = (1...12).map { "[URL=https://example.com/\($0)]Link \($0)[/URL]" }.joined(separator: "\n")
        let value = ConversationContentPresentation(raw)
        XCTAssertEqual(value.links.count, 10)
        XCTAssertTrue(value.text.contains("Link 11 https://example.com/11"))
        XCTAssertTrue(value.text.contains("Link 12 https://example.com/12"))
    }

    func testLegacyRequestsResponseDoesNotInventQuotaOrBlockCreation() throws {
        let page = try JSONDecoder.ekitapligim.decode(BookRequestsPageDTO.self, from: Data(#"{"items":[]}"#.utf8))
        XCTAssertNil(page.requestQuota)
        XCTAssertTrue(page.items.isEmpty)
    }

    func testServerQuotaSelectsExplanationWithoutChangingMembership() throws {
        let normal = try quota(premium: false, remaining: 0, canRequest: false, limit: 0)
        XCTAssertEqual(normal.explanation, .membership)
        let available = try quota(premium: true, remaining: 2, canRequest: true)
        XCTAssertNil(available.explanation)
        let exhausted = try quota(premium: true, remaining: 0, canRequest: false)
        XCTAssertEqual(exhausted.explanation, .exhausted(exhausted))
        XCTAssertEqual(exhausted.explanation?.quota?.limit, 5)
    }

    func testOtherRequestRestrictionsDoNotPretendMonthlyQuotaIsExhausted() throws {
        let value = try quota(premium: true, remaining: 3, canRequest: false)
        XCTAssertNil(value.explanation)
    }

    func testRenewalUsesServerTimezoneEvenWhenDeviceTimezoneDiffers() throws {
        let value = try quota(premium: true, remaining: 0, canRequest: false)
        let label = try XCTUnwrap(value.explanation?.renewalLabel(locale: Locale(identifier: "en_US")))
        XCTAssertTrue(label.contains("December 1, 2026"), label)
        XCTAssertTrue(label.contains("12:00"), label)
    }

    func testBookEmbedBecomesNativeCardWithCleanCaption() throws {
        let value = ConversationContentPresentation("Bunu okuyalım. [EMBED content=\"thread-42\"]https://ekitapligim.com/konular/kitap.42/[/EMBED]")
        XCTAssertEqual(value.text, "Bunu okuyalım.")
        XCTAssertEqual(value.links.count, 1)
        XCTAssertEqual(value.links.first?.bookID, 42)
        XCTAssertEqual(value.links.first?.route, .bookDetail(42))
    }

    func testHTMLAndBBCodeKeepHumanLinkLabelsAndUnicode() {
        let value = ConversationContentPresentation("İyi okumalar 📚 <a href=\"https://ekitapligim.com/books/7/\">İnce Memed</a> [URL=https://example.com/story]Hikâye[/URL]")
        XCTAssertEqual(value.text, "İyi okumalar 📚 İnce Memed Hikâye")
        XCTAssertEqual(value.links.count, 2)
        XCTAssertEqual(value.links.first?.bookID, 7)
        XCTAssertNil(value.links.last?.route)
    }

    func testImageOnlyMessageProvidesImageCardAndNoBBCode() {
        let value = ConversationContentPresentation("[IMG]https://ekitapligim.com/data/reading.png[/IMG]")
        XCTAssertTrue(value.text.isEmpty)
        XCTAssertEqual(value.links.first?.inlineImageURL?.path, "/data/reading.png")
    }

    func testExternalImagesNeverAutoLoadInlineAndLookalikeHostsAreNotNative() {
        let value = ConversationContentPresentation("[IMG]https://example.com/image.png[/IMG] https://ekitapligim.com.attacker.example/konular/book.42/")
        XCTAssertEqual(value.links.count, 2)
        XCTAssertNil(value.links.first?.inlineImageURL)
        XCTAssertNil(value.links.last?.route)
    }

    func testExecutableCredentialLocalAndInsecureLinksAreNeverActionable() {
        for value in ["javascript:alert(1)", "file:///secret", "http://example.com", "https://user:pass@example.com", "https://127.0.0.1/x", "https://[::1]/x", "https://host.local/x", "https://host.internal/x", "https://example.com:8443/x", "detail/42"] {
            XCTAssertNil(ConversationContentPresentation.safeURL(value), value)
        }
    }

    func testLinksAreDeduplicatedAndBoundedForLongMessages() {
        let raw = (1...30).map { "https://example.com/\($0)" }.joined(separator: " ")
        XCTAssertEqual(ConversationContentPresentation(raw).links.count, 10)
        let duplicate = ConversationContentPresentation("[URL]https://example.com/a[/URL] https://example.com/a")
        XCTAssertEqual(duplicate.links.count, 1)
    }

    func testTruncatedPreviewDoesNotShowBrokenMarkup() {
        let value = ConversationContentPresentation("Merhaba [B]okur[/B] [EMBED content=\"thread-42")
        XCTAssertEqual(value.text, "Merhaba okur")
    }

    func testRichMessageIsOptionalForExistingConversationPayloads() throws {
        let old = #"{"id":"1","conversation_id":2,"user_id":3,"username":"Okur","message":"Merhaba","message_date":1,"avatar_url":"","is_mine":false}"#
        let dto = try JSONDecoder.ekitapligim.decode(ConversationMessageDTO.self, from: Data(old.utf8))
        XCTAssertNil(dto.richMessage)
        XCTAssertEqual(dto.message, "Merhaba")
        let rich = old.dropLast() + #","rich_message":"[URL]https://ekitapligim.com/books/7/[/URL]"}"#
        let updated = try JSONDecoder.ekitapligim.decode(ConversationMessageDTO.self, from: Data(rich.utf8))
        XCTAssertEqual(ConversationContentPresentation(updated.richMessage ?? "").links.first?.bookID, 7)
    }

    private func quota(premium: Bool, remaining: Int, canRequest: Bool, limit: Int = 5) throws -> BookRequestQuotaDTO {
        let raw = """
        {"items":[],"request_quota":{"is_premium":\(premium),"limit":\(limit),"used":\(max(0, limit - remaining)),"remaining":\(remaining),"can_request":\(canRequest),"resets_at":1796072400,"timezone":"Europe/Istanbul"}}
        """
        return try XCTUnwrap(JSONDecoder.ekitapligim.decode(BookRequestsPageDTO.self, from: Data(raw.utf8)).requestQuota)
    }
}
