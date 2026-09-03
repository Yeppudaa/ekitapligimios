import XCTest
@testable import EkitapligimCore

final class DeepLinkParserTests: XCTestCase {
    func testBookDeepLink() {
        XCTAssertEqual(
            DeepLinkParser().parse("https://ekitapligim.com/books/suc-ve-ceza.15582/"),
            .bookDetail(15582)
        )
    }

    func testSupportedUniversalLinkFamilies() {
        let parser = DeepLinkParser()

        XCTAssertEqual(parser.parse("https://www.ekitapligim.com/threads/duyuru.47/"), .thread(47))
        XCTAssertEqual(parser.parse("https://ekitapligim.com/forums/genel.12/"), .forumDetail(12))
        XCTAssertEqual(parser.parse("https://ekitapligim.com/book-authors/orhan-pamuk/"), .authors)
        XCTAssertEqual(parser.parse("https://ekitapligim.com/book-publishers/yapi-kredi/"), .publishers)
        XCTAssertEqual(parser.parse("https://ekitapligim.com/book-requests/"), .requests)
    }

    func testRejectsOtherHosts() {
        XCTAssertNil(DeepLinkParser().parse("https://example.com/books/foo.1/"))
    }

    func testNativeNotificationRoutes() {
        let parser = DeepLinkParser()

        XCTAssertEqual(parser.parseNativeRoute("detail/15582"), .bookDetail(15582))
        XCTAssertEqual(parser.parseNativeRoute("thread/47"), .thread(47))
        XCTAssertEqual(parser.parseNativeRoute("forum/12"), .forumDetail(12))
        XCTAssertEqual(parser.parseNativeRoute("requests"), .requests)
        XCTAssertNil(parser.parseNativeRoute("https://evil.example/threads/1"))
        XCTAssertNil(parser.parseNativeRoute("unknown/1"))
    }

    func testNotificationPrefersNativeRouteThenTargetURLAndSafeFallback() {
        let parser = DeepLinkParser()

        XCTAssertEqual(
            parser.parseNotification(appRoute: "detail/15582", targetURL: "https://ekitapligim.com/threads/topic.99/"),
            .bookDetail(15582)
        )
        XCTAssertEqual(
            parser.parseNotification(appRoute: nil, targetURL: "https://ekitapligim.com/threads/topic.99/"),
            .thread(99)
        )
        XCTAssertEqual(
            parser.parseNotification(appRoute: nil, targetURL: nil, contentID: 42, type: "post"),
            .thread(42)
        )
        XCTAssertEqual(
            parser.parseNotification(
                appRoute: nil,
                targetURL: "https://evil.example/threads/topic.99/",
                contentID: 42,
                type: "user"
            ),
            .member(42)
        )
        XCTAssertNil(
            parser.parseNotification(
                appRoute: nil,
                targetURL: "https://evil.example/threads/topic.99/",
                contentID: 42,
                type: "unknown"
            )
        )
    }

    func testNotificationOpensVisitorProfileForProfileVisitAlerts() {
        let parser = DeepLinkParser()

        XCTAssertEqual(
            parser.parseNotification(
                appRoute: "notifications",
                targetURL: nil,
                contentID: 7,
                type: "user",
                action: "profile_visit",
                actorUserID: 42
            ),
            .member(42)
        )
        XCTAssertEqual(
            parser.parseNotification(
                appRoute: "thread/99",
                targetURL: nil,
                contentID: 7,
                type: "user",
                action: "following",
                actorUserID: 42
            ),
            .member(42)
        )
    }

    func testNotificationRoutesConversationChatAndSocialAlerts() {
        let parser = DeepLinkParser()

        XCTAssertEqual(
            parser.parseNotification(appRoute: "conversation/18", targetURL: nil, type: "conversation_message"),
            .conversation(18)
        )
        XCTAssertEqual(
            parser.parseNotification(appRoute: nil, targetURL: nil, contentID: 3, type: "siropu_chat_room_message"),
            .chatRoom(3)
        )
        XCTAssertEqual(
            parser.parseNotification(appRoute: nil, targetURL: nil, contentID: 19, type: "ek_social_post"),
            .bookAgendaPost(19)
        )
        XCTAssertEqual(
            parser.parseNotification(appRoute: "messages", targetURL: nil, type: "conversation_message"),
            .messages
        )
    }
}
