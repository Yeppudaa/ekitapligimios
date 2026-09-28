import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class SessionResponseIsolationTests: XCTestCase {
    override func tearDown() {
        SessionResponseProtocol.handler = nil
        super.tearDown()
    }

    func testLateUnreadCountsDoNotRepopulateSignedOutAccount() async throws {
        let gate = SessionResponseGate()
        let started = expectation(description: "counts started")
        let container = makeContainer(gate: gate, started: started)
        container.authState = .signedIn(Session(accessToken: "a", refreshToken: "refresh-a", username: "reader-a"))
        let task = Task { await container.refreshUnreadCounts() }
        await fulfillment(of: [started], timeout: 2)
        container.markRemoteSessionInvalidated()
        await gate.release()
        await task.value
        XCTAssertEqual(container.authState, .expired)
        XCTAssertEqual(container.unreadNotifications, 0)
        XCTAssertEqual(container.unreadMessages, 0)
    }

    func testLateProfileRefreshDoesNotOverwriteNextAccount() async throws {
        let gate = SessionResponseGate()
        let started = expectation(description: "session refresh pending")
        let container = makeContainer(gate: gate, started: started)
        container.authState = .signedIn(Session(accessToken: "a", refreshToken: "refresh-a", username: "reader-a"))
        let task = Task { await container.refreshSessionData() }
        await fulfillment(of: [started], timeout: 2)
        container.markRemoteSessionInvalidated()
        container.authState = .signedIn(Session(accessToken: "b", refreshToken: "refresh-b", username: "reader-b"))
        let nextProfile = try JSONDecoder.ekitapligim.decode(ProfileDTO.self, from: Data(#"{"id":2,"username":"reader-b"}"#.utf8))
        container.updateProfile(nextProfile)
        await gate.release()
        await task.value
        XCTAssertEqual(container.profileState?.username, "reader-b")
        XCTAssertEqual(container.unreadNotifications, 0)
        XCTAssertFalse(container.isRefreshingSession)
    }

    private func makeContainer(gate: SessionResponseGate, started: XCTestExpectation) -> AppContainer {
        SessionResponseProtocol.handler = { request in
            if request.url?.path.hasSuffix("/me/notifications/counts") == true {
                started.fulfill()
                await gate.wait()
                return #"{"unread":9,"unviewed":0,"conversations_unread":4}"#
            }
            if request.url?.path.hasSuffix("/me") == true {
                return #"{"id":1,"username":"reader-a"}"#
            }
            return "{}"
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SessionResponseProtocol.self]
        return AppContainer(apiSession: URLSession(configuration: config), tokenStore: IsolatedSessionStore())
    }
}

private actor IsolatedSessionStore: TokenStore {
    var session: Session? = Session(accessToken: "a", refreshToken: "refresh-a", username: "reader-a")
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

private actor SessionResponseGate {
    var released = false
    var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        guard !released else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { released = true; continuation?.resume(); continuation = nil }
}

private final class SessionResponseProtocol: URLProtocol, @unchecked Sendable {
    static var handler: (@Sendable (URLRequest) async -> String)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        Task {
            let body = await handler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
