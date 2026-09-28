import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class GiftWheelTransportTests: XCTestCase {
    override func tearDown() { WheelStubProtocol.handler = nil; super.tearDown() }
    private func repository(tokens: WheelTestTokens = WheelTestTokens(),
                            refresh: @escaping @Sendable () async throws -> Void = {}) throws -> GiftWheelRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WheelStubProtocol.self]
        return GiftWheelRepository(webBaseURL: try XCTUnwrap(URL(string: "https://ekitapligim.com/")), tokens: tokens,
                                   refresh: refresh, session: URLSession(configuration: configuration))
    }
    func testBearerOnlyRequestsNeverUseMobileAPIOrCookies() async throws {
        let repository = try repository()
        WheelStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/hediye-carki-api/status")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ms_at_fixture")
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertNil(request.value(forHTTPHeaderField: "XF-Api-Key"))
            XCTAssertNil(request.value(forHTTPHeaderField: "XF-Api-User"))
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            return (200, WheelFixtures.status)
        }
        let status = try await repository.status(account: "reader")
        XCTAssertTrue(status.canSpin)
    }
    func testUnauthorizedRefreshRetriesIdenticalSpinKeyAndBody() async throws {
        let tokens = WheelTestTokens(), recorder = WheelRequestLog()
        let repository = try repository(tokens: tokens, refresh: { await tokens.rotate() })
        WheelStubProtocol.handler = { request in
            recorder.append(request.wheelBody)
            XCTAssertEqual(request.url?.path, "/hediye-carki-api/spin")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/x-www-form-urlencoded") ?? false)
            return request.value(forHTTPHeaderField: "Authorization") == "Bearer ms_at_rotated" ? (200, WheelFixtures.spin) : (401, "{}")
        }
        let pending = PendingGiftSpin(key: String(repeating: "a", count: 32), revision: 2)
        let result = try await repository.spin(account: "reader", pending: pending)
        XCTAssertEqual(result.result.days, 7)
        XCTAssertEqual(recorder.values, Array(repeating: "request_key=\(pending.key)&revision=2", count: 2))
    }
    func testServerRejectionsAreTypedAndNotAutomaticallyReplayed() async throws {
        let repository = try repository(), recorder = WheelRequestLog()
        WheelStubProtocol.handler = { request in
            recorder.append(request.url?.path ?? "")
            return (409, "{\"error\":{\"code\":\"spin_unavailable\",\"message\":\"Bekle\"}}")
        }
        do { _ = try await repository.spin(account: "reader", pending: PendingGiftSpin(revision: 2)); XCTFail("Expected rejection") }
        catch { XCTAssertEqual(error as? GiftWheelError, .server(409, "Bekle")) }
        XCTAssertEqual(recorder.values.count, 1)
    }
    func testRepeated401StopsAfterOneRefresh() async throws {
        let repository = try repository(), recorder = WheelRequestLog()
        WheelStubProtocol.handler = { _ in recorder.append("request"); return (401, "{}") }
        do { _ = try await repository.status(account: "reader"); XCTFail("Expected authentication error") }
        catch { XCTAssertEqual(error as? GiftWheelError, .authenticationRequired) }
        XCTAssertEqual(recorder.values.count, 2)
    }
    func testSessionSwitchDuringRefreshCannotReplayForAnotherAccount() async throws {
        let tokens = WheelTestTokens(), recorder = WheelRequestLog()
        let repository = try repository(tokens: tokens, refresh: { await tokens.switchAccount() })
        WheelStubProtocol.handler = { _ in recorder.append("request"); return (401, "{}") }
        do { _ = try await repository.spin(account: "reader", pending: PendingGiftSpin(revision: 2)); XCTFail("Expected account guard") }
        catch { XCTAssertEqual(error as? GiftWheelError, .authenticationRequired) }
        XCTAssertEqual(recorder.values.count, 1)
    }
    func testGuestsAndLegacyTokensNeverSendRequests() async throws {
        WheelStubProtocol.handler = { _ in XCTFail("No network request expected"); return (200, WheelFixtures.status) }
        for token in [nil, "legacy"] as [String?] {
            let repository = try repository(tokens: WheelTestTokens(token: token))
            do { _ = try await repository.status(account: "reader"); XCTFail("Expected authentication error") }
            catch { XCTAssertEqual(error as? GiftWheelError, .authenticationRequired) }
        }
    }
    func testRejectsInsecureForeignAndCredentialedOrigins() throws {
        for raw in ["http://localhost/ekitapligim/", "https://127.0.0.1/", "https://example.com/", "https://user@ekitapligim.com/"] {
            let repository = GiftWheelRepository(webBaseURL: try XCTUnwrap(URL(string: raw)), tokens: WheelTestTokens(), refresh: {})
            XCTAssertThrowsError(try repository.makeRequest(action: "status", token: "ms_at_fixture"))
        }
        let repository = try repository()
        XCTAssertThrowsError(try repository.makeRequest(action: "../premium", token: "ms_at_fixture"))
    }
    func testWinnersUseDedicatedEnvelopeAndRejectHTMLOrUnknownVersion() async throws {
        let repository = try repository()
        WheelStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/hediye-carki-api/winners")
            return (200, "{\"api_version\":1,\"winners\":[{\"username\":\"Okur\",\"days\":30,\"created_at\":1790504500}]}")
        }
        let winners = try await repository.winners(account: "reader")
        XCTAssertEqual(winners.first?.username, "Okur")
        for body in ["<html>Login</html>", "{\"api_version\":2,\"winners\":[]}"] {
            WheelStubProtocol.handler = { _ in (200, body) }
            do { _ = try await repository.winners(account: "reader"); XCTFail("Expected decoding error") }
            catch { XCTAssertEqual(error as? GiftWheelError, .invalidResponse) }
        }
    }
}

private actor WheelTestTokens: SessionTokenManaging {
    var session: Session?
    init(token: String? = "ms_at_fixture") { session = token.map { Session(accessToken: $0, refreshToken: "fixture", username: "reader") } }
    func rotate() { session = Session(accessToken: "ms_at_rotated", refreshToken: "fixture", username: "reader") }
    func switchAccount() { session = Session(accessToken: "ms_at_other", refreshToken: "fixture", username: "other") }
    func accessToken() async throws -> String? { session?.accessToken }
    func loadSession() async throws -> Session? { session }
    func save(session: Session) async throws { self.session = session }
    func clear() async throws { session = nil }
    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool {
        guard self.session == expected else { return false }
        self.session = session
        return true
    }
}
private final class WheelRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [String] = []
    var values: [String] { lock.lock(); defer { lock.unlock() }; return requests }
    func append(_ value: String) { lock.lock(); defer { lock.unlock() }; requests.append(value) }
}
private final class WheelStubProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        let (status, body) = handler(request)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private extension URLRequest {
    var wheelBody: String {
        if let httpBody { return String(data: httpBody, encoding: .utf8) ?? "" }
        guard let stream = httpBodyStream else { return "" }
        stream.open(); defer { stream.close() }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            result.append(contentsOf: buffer.prefix(count))
        }
        return String(data: result, encoding: .utf8) ?? ""
    }
}
