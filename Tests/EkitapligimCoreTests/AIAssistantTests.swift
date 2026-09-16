import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class AIAssistantTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String, as type: T.Type = T.self) throws -> T {
        try JSONDecoder.ekitapligim.decode(type, from: Data(json.utf8))
    }
    func testMissingPermissionsFailClosed() throws {
        let b: AIBootstrapDTO = try decode("{}")
        XCTAssertFalse(b.enabled); XCTAssertFalse(b.features.widget)
        XCTAssertEqual(b.usage.remaining, 0)
        XCTAssertFalse(AIPolicy.canSend(bootstrap: b, signedIn: false, contextBookID: nil, busy: false))
    }
    func testServerQuotaAndContextFlagsDriveAllSendPaths() throws {
        let b: AIBootstrapDTO = try decode(Self.bootstrap)
        XCTAssertEqual(b.usage.limit, 2)
        XCTAssertEqual(b.constraints.maxMessageLength, 1000)
        XCTAssertTrue(AIPolicy.canSend(bootstrap: b, signedIn: false, contextBookID: nil, busy: false))
        XCTAssertFalse(AIPolicy.canSend(bootstrap: b, signedIn: true, contextBookID: nil, busy: false))
        XCTAssertFalse(AIPolicy.canSend(bootstrap: b, signedIn: false, contextBookID: nil, busy: true))
        XCTAssertFalse(AIPolicy.canSend(bootstrap: b, signedIn: false, contextBookID: 7, busy: false))
        let noQuota: AIBootstrapDTO = try decode(Self.bootstrap.replacingOccurrences(of: "\"remaining\":2", with: "\"remaining\":0"))
        XCTAssertFalse(AIPolicy.canSend(bootstrap: noQuota, signedIn: false, contextBookID: nil, busy: false))
        let off: AIBootstrapDTO = try decode(Self.bootstrap.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":false"))
        XCTAssertFalse(AIPolicy.canSend(bootstrap: off, signedIn: false, contextBookID: nil, busy: false))
    }
    func testServerGroupValuesAreNotReplacedWithLocalTierDefaults() throws {
        for (tier, limit) in [("member", 7), ("premium", 123), ("admin", 3)] {
            let b: AIBootstrapDTO = try decode("""
            {"enabled":true,"authenticated":true,"constraints":{"max_message_length":1000},
             "usage":{"tier":"\(tier)","limit":\(limit),"remaining":\(limit)}}
            """)
            XCTAssertEqual(b.usage.limit, limit)
            XCTAssertTrue(AIPolicy.canSend(bootstrap: b, signedIn: true, contextBookID: nil, busy: false))
        }
    }
    func testNestedConversationPayloadAndAliases() throws {
        let c: AIConversationDTO = try decode("""
        {"conversation_id":9,"title":"Sohbet","context":{"thread_id":8},"messages":[
          {"message_id":3,"role":"assistant","content":"Önerim", "payload":{
            "book_cards":[{"book_id":8,"book_title":"Kitap","book_author":"Yazar","book_pages":120}],
            "evidence":[{"title":"Kaynak","url":"https://ekitapligim.com/books/8"}],
            "presentation":{"follow_ups":[{"prompt":"Devam et"}]},
            "pending_action":{"action_id":4,"action_type":"shelf","preview":"Rafa ekle","confirmation_token":"test-only","expires_date":2000000000}
          }}]}
        """)
        XCTAssertEqual(c.contextThreadId, 8)
        XCTAssertEqual(c.messages.first?.bookCards.first?.title, "Kitap")
        XCTAssertEqual(c.messages.first?.presentation?.followUps.first?.label, "Devam et")
        XCTAssertFalse(try XCTUnwrap(c.messages.first?.evidence.first).verified)
        let action = try XCTUnwrap(c.messages.first?.pendingAction)
        XCTAssertTrue(action.canConfirm(at: Date(timeIntervalSince1970: 1)))
        XCTAssertFalse(action.canConfirm(at: Date(timeIntervalSince1970: 2000000000)))
    }
    func testInvalidPendingPreviewCannotBeConfirmed() throws {
        let action: AIPendingActionDTO = try decode("""
        {"action_id":2,"preview":{"private":"unsupported"},"confirmation_token":"test-only","expires_at":2000000000}
        """)
        XCTAssertFalse(action.canConfirm(at: Date(timeIntervalSince1970: 1)))
    }
    func testServerFollowUpSuggestionsAlias() throws {
        let presentation: AIPresentationDTO = try decode("""
        {"follow_up_suggestions":[{"label":"Benzer kitaplar","prompt":"Benzer kitaplar öner."}]}
        """)
        XCTAssertEqual(presentation.followUps.first?.prompt, "Benzer kitaplar öner.")
    }
    func testGuestHeaderOnlyGoesToAnonymousAssistantRequests() async throws {
        let config = try AppConfig.production()
        let key = String(repeating: "a", count: 64)
        let endpoint = APIEndpoint(method: .get, path: "bootstrap", service: .assistant, guestKey: key)
        let anonymous = APIClient(config: config)
        let request = try await anonymous.authenticatedRequest(endpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Guest-Key"), key)
        XCTAssertEqual(request.url?.absoluteString, "https://ekitapligim.com/mobile-api/v1/ai/bootstrap")
        let primary = try await anonymous.authenticatedRequest(APIEndpoint(method: .get, path: "me", guestKey: key))
        XCTAssertNil(primary.value(forHTTPHeaderField: "X-Guest-Key"))
        XCTAssertEqual(primary.url?.absoluteString, "https://ekitapligim.com/ios-api/v1/me")
        let member = APIClient(config: config, tokenProvider: InMemoryTokenProvider(token: "test-access"))
        let memberRequest = try await member.authenticatedRequest(endpoint)
        XCTAssertNil(memberRequest.value(forHTTPHeaderField: "X-Guest-Key"))
        XCTAssertEqual(memberRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-access")
    }
    func testAITransportDoesNotChangePrimaryTimeoutOrRefreshRoute() throws {
        let client = APIClient(config: try AppConfig.production())
        let ai = try client.makeURLRequest(APIEndpoint(method: .post, path: "conversations/4",
            body: .form(["message":"Bir & kitap+öner", "entry_point":"ios"]), service: .assistant, timeout: 180))
        XCTAssertEqual(ai.timeoutInterval, 180)
        XCTAssertEqual(ai.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(ai.value(forHTTPHeaderField: "Cache-Control"), "no-cache, no-store")
        XCTAssertTrue(String(data: ai.httpBody ?? Data(), encoding: .utf8)?.contains("%26") == true)
        let refresh = try client.makeURLRequest(.refreshSession(refreshToken: "test-refresh"))
        XCTAssertEqual(refresh.timeoutInterval, 30)
        XCTAssertEqual(refresh.url?.path, "/ios-api/v1/auth/refresh")
    }
    func testLinksRejectInvalidIDsSlugsAndInsecureSources() {
        let p = DeepLinkParser()
        XCTAssertEqual(p.parseNativeRoute("ai-assistant"), .aiAssistant(bookID: nil))
        XCTAssertEqual(p.parseNativeRoute("ai-assistant/123"), .aiAssistant(bookID: 123))
        XCTAssertNil(p.parseNativeRoute("ai-assistant/0"))
        XCTAssertNil(p.parseNativeRoute("ai-assistant/1/2"))
        XCTAssertEqual(p.parse("https://ekitapligim.com/asistan/"), .aiAssistant(bookID: nil))
        XCTAssertEqual(p.parseNativeRoute("ai-collections/kisa-kitaplar"), .aiCollections(slug: "kisa-kitaplar"))
        XCTAssertEqual(p.parse("https://ekitapligim.com/koleksiyonlar/kisa-kitaplar/"), .aiCollections(slug: "kisa-kitaplar"))
        XCTAssertNil(p.parseNativeRoute("ai-collections/../preferences"))
        XCTAssertNil(AIPolicy.secureSource("javascript:alert(1)"))
        XCTAssertNil(AIPolicy.secureSource("http://ekitapligim.com"))
        XCTAssertNil(AIPolicy.secureSource("https://user:pass@example.com"))
        XCTAssertEqual(p.parseNotification(appRoute: nil, targetURL: nil, type: "ek_ai_digest"), .aiAssistant(bookID: nil))
    }
    func testErrorsAreLocalizedWithoutLeakingServerMessages() {
        for code in [401,403,404,422,429,503] {
            let error = APIClientError.httpStatus(code, APIErrorEnvelope(errors: [APIErrorDetail(code: "x", message: "sensitive")]))
            XCTAssertFalse(AIErrorMessage.text(error).contains("sensitive"))
        }
        let logger = RedactedLogger()
        XCTAssertEqual(logger.redact(headers: ["X-Guest-Key":"secret"])["X-Guest-Key"], "[REDACTED]")
        XCTAssertFalse(logger.redact(message: "confirmation_token=secret").contains("secret"))
        XCTAssertEqual(AIL10n.newConversation, "Yeni sohbet")
    }
    static let bootstrap = """
    {"enabled":true,"authenticated":false,"features":{"widget":true},
     "constraints":{"max_message_length":1000},"usage":{"limit":2,"used":0,"remaining":2,"tier":"guest"}}
    """
}
