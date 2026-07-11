import XCTest
@testable import EkitapligimCore

final class DeepLinkParserTests: XCTestCase {
    func testBookDeepLink() {
        XCTAssertEqual(
            DeepLinkParser().parse("https://ekitapligim.com/books/suc-ve-ceza.15582/"),
            .bookDetail(15582)
        )
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
        XCTAssertNil(
            parser.parseNotification(
                appRoute: nil,
                targetURL: "https://evil.example/threads/topic.99/",
                contentID: 42,
                type: "user"
            )
        )
    }
}
