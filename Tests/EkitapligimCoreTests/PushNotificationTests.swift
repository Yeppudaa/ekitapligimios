import XCTest
@testable import EkitapligimCore

final class PushNotificationTests: XCTestCase {

    // MARK: - Device Token Endpoint Tests

    func testRegisterDeviceTokenEndpoint() {
        let endpoint = APIEndpoint.registerDeviceToken("abc123hex")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.path, "me/device-token")
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertEqual(endpoint.body, .form(["device_token": "abc123hex", "platform": "ios"]))
    }

    func testUnregisterDeviceTokenEndpoint() {
        let endpoint = APIEndpoint.unregisterDeviceToken("abc123hex")
        XCTAssertEqual(endpoint.method, .delete)
        XCTAssertEqual(endpoint.path, "me/device-token")
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertEqual(endpoint.body, .form(["device_token": "abc123hex"]))
    }

    // MARK: - Push Payload Deep Link Routing

    func testPushPayloadRoutesToBookAgendaPost() {
        let parser = DeepLinkParser()
        let route = parser.parseNotification(
            appRoute: "book-agenda/42",
            targetURL: nil,
            contentID: 42,
            type: "ek_social_post",
            action: nil,
            actorUserID: nil
        )
        XCTAssertEqual(route, .bookAgendaPost(42))
    }

    func testPushPayloadRoutesToConversation() {
        let parser = DeepLinkParser()
        let route = parser.parseNotification(
            appRoute: "conversation/7",
            targetURL: nil,
            contentID: 7,
            type: "conversation",
            action: nil,
            actorUserID: nil
        )
        XCTAssertEqual(route, .conversation(7))
    }

    func testPushPayloadRoutesToThread() {
        let parser = DeepLinkParser()
        let route = parser.parseNotification(
            appRoute: "thread/15",
            targetURL: nil,
            contentID: 15,
            type: "post",
            action: nil,
            actorUserID: nil
        )
        XCTAssertEqual(route, .thread(15))
    }

    func testPushPayloadRoutesToNotificationsForEmptyRoute() {
        let parser = DeepLinkParser()
        let route = parser.parseNotification(
            appRoute: "notifications",
            targetURL: nil,
            contentID: nil,
            type: nil,
            action: nil,
            actorUserID: nil
        )
        // "notifications" native route returns .notifications but parseNotification skips stale notifications route
        // and falls back -- since there's no other data, returns nil
        XCTAssertNil(route)
    }

    func testPushPayloadRoutesToMemberForFollowAction() {
        let parser = DeepLinkParser()
        let route = parser.parseNotification(
            appRoute: nil,
            targetURL: nil,
            contentID: nil,
            type: "user",
            action: "follow",
            actorUserID: 99
        )
        XCTAssertEqual(route, .member(99))
    }

    func testPushPayloadRoutesToBookRequests() {
        let parser = DeepLinkParser()
        let route = parser.parseNotification(
            appRoute: nil,
            targetURL: nil,
            contentID: nil,
            type: nil,
            action: "book_request_new",
            actorUserID: nil
        )
        XCTAssertEqual(route, .requests)
    }

    func testPushPayloadRoutesToChatRoom() {
        let parser = DeepLinkParser()
        let route = parser.parseNotification(
            appRoute: "chat/5",
            targetURL: nil,
            contentID: 5,
            type: "siropu_chat_room_message",
            action: nil,
            actorUserID: nil
        )
        XCTAssertEqual(route, .chatRoom(5))
    }
}
