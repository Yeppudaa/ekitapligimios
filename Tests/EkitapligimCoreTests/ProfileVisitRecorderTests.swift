import XCTest
@testable import EkitapligimCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ProfileVisitRecorderTests: XCTestCase {
    func testCapturedRequestPostsOnlyToSharedPolicyRoute() throws {
        let root = try XCTUnwrap(URL(string: "https://ekitapligim.com/"))
        let request = try ProfileVisitRecorder.request(webBaseURL: root, memberID: 42, token: "ms_at_fixture")
        XCTAssertEqual(request.url?.absoluteString, "https://ekitapligim.com/mobile-api/v1/members/42/visit")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.httpBody, Data())
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ms_at_fixture")
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertEqual(request.timeoutInterval, 5)
    }

    func testRequestRejectsInvalidTargetAndHeaderInjection() throws {
        let root = try XCTUnwrap(URL(string: "https://ekitapligim.com/"))
        for id in [0, -1, Int(Int32.max) + 1] {
            XCTAssertThrowsError(try ProfileVisitRecorder.request(webBaseURL: root, memberID: id, token: "fixture"))
        }
        for token in ["", "abc\r\nX: bad", "a b"] {
            XCTAssertThrowsError(try ProfileVisitRecorder.request(webBaseURL: root, memberID: 42, token: token))
        }
        let insecure = try XCTUnwrap(URL(string: "http://ekitapligim.com/"))
        XCTAssertThrowsError(try ProfileVisitRecorder.request(webBaseURL: insecure, memberID: 42, token: "fixture"))
    }

    func testGuestAndOwnProfileNeverContactServer() async throws {
        let root = try XCTUnwrap(URL(string: "https://ekitapligim.com/"))
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [PVResponseProtocol.self]
        let mockSession = URLSession(configuration: configuration)
        defer { mockSession.invalidateAndCancel() }
        let guest = try ProfileVisitRecorder(webBaseURL: root, tokens: PVTokens(nil), session: mockSession)
        let guestResult = await guest.record(memberID: 42, account: nil)
        XCTAssertFalse(guestResult)
        let member = try ProfileVisitRecorder(webBaseURL: root, tokens: PVTokens(Session(accessToken: "fixture", refreshToken: nil, username: "reader", userID: "42")), session: mockSession)
        let ownResult = await member.record(memberID: 42, account: "reader")
        let switched = await member.record(memberID: 9, account: "oldAccount")
        XCTAssertFalse(ownResult); XCTAssertFalse(switched)
    }

    func testAcknowledgedVisitAndOlderServerFailureAreBestEffort() async throws {
        let root = try XCTUnwrap(URL(string: "https://ekitapligim.com/"))
        let tokens = PVTokens(Session(accessToken: "fixture", refreshToken: nil, username: "reader", userID: "7"))
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [PVResponseProtocol.self]
        let session = URLSession(configuration: configuration)
        let recorder = try ProfileVisitRecorder(webBaseURL: root, tokens: tokens, session: session)
        let accepted = await recorder.record(memberID: 42, account: "reader")
        let unavailable = await recorder.record(memberID: 99, account: "reader")
        XCTAssertTrue(accepted); XCTAssertFalse(unavailable)
        let stored = await tokens.loadSession()
        XCTAssertEqual(stored?.username, "reader")
        session.invalidateAndCancel()
    }
}

private actor PVTokens: SessionTokenManaging {
    private var session: Session?
    init(_ value: Session?) { session = value }
    func loadSession() -> Session? { session }
    func accessToken() -> String? { session?.accessToken }
    func save(session: Session) { self.session = session }
    func clear() { session = nil }
    func replaceSession(_ value: Session?, ifMatching expected: Session) -> Bool {
        guard session == expected else { return false }; session = value; return true
    }
}

private final class PVResponseProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: url.path.contains("/42/") ? 200 : 404, httpVersion: nil, headerFields: ["Content-Type":"application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"success":true,"recorded":false}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
