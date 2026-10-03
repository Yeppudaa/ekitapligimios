import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class ChatInteractionTests: XCTestCase {
    func testReplyUsesOriginalMessageIDAndPlainMessagesKeepExistingBody() throws {
        let plain = APIEndpoint.sendChatMessage(roomID: "4", message: "Selam")
        XCTAssertEqual(plain.body, .form(["message": "Selam"]))
        let reply = APIEndpoint.sendChatMessage(roomID: "4", message: "Yanıt & devam", quoteMessageID: "81")
        XCTAssertEqual(reply.path, "chat/rooms/4/messages")
        XCTAssertTrue(reply.requiresAuthentication)
        XCTAssertEqual(reply.body, .form(["message": "Yanıt & devam", "quote_message_id": "81"]))
        let request = try APIClient(config: .production()).makeURLRequest(reply)
        let body = try XCTUnwrap(String(data: XCTUnwrap(request.httpBody), encoding: .utf8))
        XCTAssertTrue(body.contains("quote_message_id=81"))
        XCTAssertTrue(body.contains("%26"))
        XCTAssertFalse(body.contains("user_id="))
    }

    func testReactionsUseConfiguredIDAndExplicitZeroRemoval() {
        for id in [1, 7, 0] {
            let endpoint = APIEndpoint.setChatReaction(roomID: "4", messageID: "81", reactionID: id)
            XCTAssertEqual(endpoint.method, .post)
            XCTAssertEqual(endpoint.path, "chat/rooms/4/messages/81/reactions")
            XCTAssertEqual(endpoint.body, .form(["reaction_id": String(id)]))
            XCTAssertTrue(endpoint.requiresAuthentication)
        }
    }

    func testLegacyResponsesDisableInteractionsWithoutBreakingChat() throws {
        let message = try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self, from: Data(Self.legacy.utf8))
        XCTAssertEqual(message.id, "81")
        XCTAssertFalse(message.canQuote)
        XCTAssertFalse(message.canReact)
        XCTAssertEqual(message.visitorReactionId, 0)
        XCTAssertTrue(message.reactions.isEmpty)
        XCTAssertNil(message.quotedMessage)
        let rooms = try JSONDecoder.ekitapligim.decode(ChatRoomsDTO.self, from: Data(#"{"items":[],"capabilities":{}}"#.utf8))
        XCTAssertTrue(rooms.reactionOptions.isEmpty)
    }

    func testQuoteAndConfiguredReactionsDecodeFlexibleNumericFields() throws {
        let message = try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self, from: Data(Self.interaction.utf8))
        XCTAssertTrue(message.canQuote)
        XCTAssertTrue(message.canReact)
        XCTAssertEqual(message.visitorReactionId, 7)
        XCTAssertEqual(message.reactionCount, 2)
        XCTAssertEqual(message.reactions.first?.reactionId, 7)
        XCTAssertEqual(message.reactions.first?.emoji, "❤️")
        XCTAssertEqual(message.quotedMessage?.messageId, "80")
        XCTAssertEqual(message.quotedMessage?.userId, "9")
        XCTAssertEqual(message.quotedMessage?.message, "Önceki mesaj\nİkinci satır")
        let historical = try JSONDecoder.ekitapligim.decode(ChatQuotedMessageDTO.self,
            from: Data(#"{"username":"Eski okur","message":"Web alıntısı"}"#.utf8))
        XCTAssertEqual(historical.messageId, "0")
        XCTAssertEqual(historical.userId, "0")
    }

    func testRoomAndPageReactionOptionsSupportBothServerEnvelopes() throws {
        for key in ["reaction_options", "available_reactions"] {
            let payload = "{\"items\":[],\"\(key)\":[{\"reaction_id\":7,\"title\":\"Love\",\"emoji\":\"❤️\"}]}"
            let rooms = try JSONDecoder.ekitapligim.decode(ChatRoomsDTO.self, from: Data(payload.utf8))
            let page = try JSONDecoder.ekitapligim.decode(ChatMessagesPageDTO.self, from: Data(payload.utf8))
            XCTAssertEqual(rooms.reactionOptions.first?.id, 7)
            XCTAssertEqual(page.reactionOptions, rooms.reactionOptions)
        }
    }

    func testNewServerBodyPreventsDuplicateQuoteAndSupportsQuoteOnlyMessages() throws {
        let payload = #"{"id":81,"room_id":4,"user_id":9,"message":"Önceki mesaj\nYanıt","message_body":"Yanıt","quoted_message":{"message_id":80,"user_id":8,"username":"Ada","message":"Önceki mesaj"}}"#
        let message = try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self, from: Data(payload.utf8))
        XCTAssertEqual(message.message, "Yanıt")
        XCTAssertEqual(message.quotedMessage?.message, "Önceki mesaj")

        let quoteOnly = payload.replacingOccurrences(of: #""message_body":"Yanıt""#, with: #""message_body":"""#)
        let quoted = try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self, from: Data(quoteOnly.utf8))
        XCTAssertEqual(quoted.message, "")
        XCTAssertEqual(quoted.quotedMessage?.message, "Önceki mesaj")
    }

    func testOldClientDecodesNewServerWithoutLosingQuoteContext() throws {
        let payload = #"{"id":81,"room_id":4,"user_id":9,"message":"Önceki mesaj\nYanıt","message_body":"Yanıt","quoted_message":{"message_id":80,"user_id":8,"username":"Ada","message":"Önceki mesaj"}}"#
        // This models the shipped client's only displayed field. Unknown fields
        // must remain additive, while message keeps both the quote and reply.
        struct LegacyMessage: Decodable { let message: String }
        let old = try JSONDecoder.ekitapligim.decode(LegacyMessage.self, from: Data(payload.utf8))
        XCTAssertEqual(old.message, "Önceki mesaj\nYanıt")
        let legacy = try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self, from: Data(Self.legacy.utf8))
        XCTAssertEqual(legacy.message, "Selam")
    }

    func testRepositoryReturnsUpdatedMessageForReactionAndQuote() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChatStubProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let repository = ChatRepository(apiClient: APIClient(config: try .production(), session: session, tokenProvider: ChatTokens()))
        let reply = try await repository.send(roomID: "4", message: "Yanıt", quoteMessageID: "80")
        XCTAssertEqual(reply.quotedMessage?.messageId, "80")
        let reaction = try await repository.setReaction(roomID: "4", messageID: "81", reactionID: 7)
        XCTAssertEqual(reaction.visitorReactionId, 7)
    }

    func testGuestCannotSendQuoteOrReaction() async throws {
        let client = APIClient(config: try .production())
        for endpoint in [APIEndpoint.sendChatMessage(roomID: "4", message: "Yanıt", quoteMessageID: "80"),
                         .setChatReaction(roomID: "4", messageID: "81", reactionID: 7)] {
            do {
                _ = try await client.authenticatedRequest(endpoint)
                XCTFail("Authentication is required")
            } catch APIClientError.authenticationRequired { }
        }
    }

    fileprivate static let legacy = #"{"id":81,"room_id":4,"user_id":9,"username":"Okur","message":"Selam","message_date":1791000000}"#
    fileprivate static let interaction = #"{"id":"81","room_id":4,"user_id":9,"username":"Okur","message":"Yanıt","message_date":1791000000,"can_quote":1,"can_react":true,"visitor_reaction_id":"7","reactions":[{"reaction_id":"7","title":"Love","emoji":"❤️","count":"2"}],"quoted_message":{"message_id":80,"user_id":"9","username":"Ada","message":"Önceki mesaj\nİkinci satır"}}"#
}

private struct ChatTokens: AccessTokenProviding {
    func accessToken() async throws -> String? { "ms_at_chat_test" }
}

private final class ChatStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ms_at_chat_test")
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        let payload = "{\"success\":true,\"message\":\(ChatInteractionTests.interaction)}"
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(payload.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
