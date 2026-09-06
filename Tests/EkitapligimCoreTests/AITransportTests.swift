import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class AITransportTests: XCTestCase {
    override func tearDown() { AIStubProtocol.handler = nil; super.tearDown() }
    private func make(_ tokens: (any AccessTokenProviding)? = nil) throws -> (APIClient, AIAssistantRepository) {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [AIStubProtocol.self]
        let session = URLSession(configuration: config)
        let client = APIClient(config: try AppConfig.production(), session: session, tokenProvider: tokens, assistantSession: session)
        return (client, AIAssistantRepository(client: client, guestKeys: AITestGuestKey()))
    }
    func testPreferencesPostAcceptsActualServerEnvelopeAndPreservesCategories() async throws {
        let (_, repository) = try make(InMemoryTokenProvider(token: "test-access"))
        AIStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/mobile-api/v1/ai/preferences")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = request.aiTestBody
            XCTAssertTrue(body.contains("personalization_enabled=1"))
            XCTAssertTrue(body.contains("category_ids%5B0%5D=8") || body.contains("category_ids[0]=8"))
            return (200, "{\"success\":true,\"digest\":null}")
        }
        var digest = AIDigestPreferenceDTO(); digest.categoryIds = [8, 9]
        try await repository.savePreferences(personalized: true, digest: digest)
    }
    func testSilentGuestBootstrapRefreshesOnlyThroughIOSAuth() async throws {
        let store = AITestSessionStore()
        let (_, repository) = try make(store)
        let requests = AIRequestRecorder()
        AIStubProtocol.handler = { request in
            requests.record(request.url?.path ?? "")
            if request.url?.path == "/ios-api/v1/auth/refresh" {
                return (200, """
                {"access_token":"refreshed","refresh_token":"refresh-new","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}
                """)
            }
            let authenticated = request.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed"
            return (200, "{\"authenticated\":\(authenticated),\"enabled\":true}")
        }
        let result = try await repository.bootstrap(signedIn: true)
        XCTAssertTrue(result.authenticated)
        XCTAssertEqual(requests.paths, ["/mobile-api/v1/ai/bootstrap", "/ios-api/v1/auth/refresh", "/mobile-api/v1/ai/bootstrap"])
    }
    func test401MessageIsNotReplayedAndDoesNotConsumeRefreshToken() async throws {
        let (_, repository) = try make(AITestSessionStore())
        let requests = AIRequestRecorder()
        AIStubProtocol.handler = { request in
            requests.record(request.url?.path ?? "")
            return (401, "{\"errors\":[{\"code\":\"login_required\",\"message\":\"Login\"}]}")
        }
        do { _ = try await repository.send("Hello", conversationID: 1, bookID: nil); XCTFail("Expected 401") }
        catch APIClientError.httpStatus(401, _) {}
        XCTAssertEqual(requests.paths, ["/mobile-api/v1/ai/conversations/1"])
    }
    func testFailedDeleteResponseIsNotReportedAsSuccess() async throws {
        let (_, repository) = try make()
        AIStubProtocol.handler = { _ in (200, "{\"success\":false}") }
        do { try await repository.deleteConversation(1); XCTFail("Expected failure") }
        catch { XCTAssertTrue(error is APIClientError) }
    }
    func testExpiredConfirmationDoesNotMakeNetworkRequest() async throws {
        let (_, repository) = try make(InMemoryTokenProvider(token: "test-access"))
        AIStubProtocol.handler = { _ in XCTFail("Expired action must not be sent"); return (200, "{}") }
        let action = try JSONDecoder.ekitapligim.decode(AIPendingActionDTO.self, from: Data("""
        {"action_id":1,"preview":"Update shelf","confirmation_token":"test-only","expires_at":1}
        """.utf8))
        do { try await repository.confirm(action); XCTFail("Expected expiration") }
        catch AIAssistantError.expiredAction {}
    }
}

private struct AITestGuestKey: AIGuestKeyProviding {
    func guestKey() async throws -> String { String(repeating: "c", count: 64) }
}
private actor AITestSessionStore: SessionTokenManaging {
    var session: Session? = Session(accessToken: "expired", refreshToken: "refresh", username: "reader")
    func accessToken() async throws -> String? { session?.accessToken }
    func loadSession() async throws -> Session? { session }
    func save(session: Session) async throws { self.session = session }
    func clear() async throws { session = nil }
}
private final class AIRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    var paths: [String] { lock.lock(); defer { lock.unlock() }; return values }
    func record(_ path: String) { lock.lock(); defer { lock.unlock() }; values.append(path) }
}
private final class AIStubProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        let (status, body) = handler(request)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private extension URLRequest {
    var aiTestBody: String {
        if let httpBody { return String(data: httpBody, encoding: .utf8) ?? "" }
        guard let stream = httpBodyStream else { return "" }
        stream.open(); defer { stream.close() }
        var result = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }; result.append(contentsOf: buffer.prefix(count))
        }
        return String(data: result, encoding: .utf8) ?? ""
    }
}
