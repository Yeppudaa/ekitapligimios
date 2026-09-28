import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class SessionRefreshTests: XCTestCase {
    override func tearDown() {
        SessionRefreshStubProtocol.handler = nil
        SessionRefreshStubProtocol.asyncHandler = nil
        super.tearDown()
    }

    func testRefresh401ClearsStoredSession() async throws {
        let store = SessionRefreshTestStore()
        let client = try makeClient(store: store)
        SessionRefreshStubProtocol.handler = { request in
            switch request.url?.path {
            case "/ios-api/v1/me/library":
                return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
            case "/ios-api/v1/auth/refresh":
                return (401, #"{"errors":[{"code":"refresh_invalid","message":"Expired"}]}"#)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "")")
                return (500, "{}")
            }
        }

        do {
            _ = try await client.request(.library, as: LibraryPageDTO.self)
            XCTFail("Expected authenticationRequired")
        } catch APIClientError.authenticationRequired {
            // expected
        }

        let currentSession = await store.currentSession()
        XCTAssertNil(currentSession)
    }

    func testRefreshNetworkErrorPreservesStoredSession() async throws {
        let store = SessionRefreshTestStore()
        let client = try makeClient(store: store)
        SessionRefreshStubProtocol.handler = { request in
            switch request.url?.path {
            case "/ios-api/v1/me/library":
                return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
            case "/ios-api/v1/auth/refresh":
                throw URLError(.notConnectedToInternet)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "")")
                return (500, "{}")
            }
        }

        do {
            _ = try await client.request(.library, as: LibraryPageDTO.self)
            XCTFail("Expected network error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }

        let session = await store.currentSession()
        XCTAssertEqual(session?.accessToken, "expired")
        XCTAssertEqual(session?.refreshToken, "refresh-token")
    }

    func testRefresh503PreservesStoredSession() async throws {
        let store = SessionRefreshTestStore()
        let client = try makeClient(store: store)
        SessionRefreshStubProtocol.handler = { request in
            switch request.url?.path {
            case "/ios-api/v1/me/library":
                return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
            case "/ios-api/v1/auth/refresh":
                return (503, #"{"errors":[{"code":"server_error","message":"Unavailable"}]}"#)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "")")
                return (500, "{}")
            }
        }

        do {
            _ = try await client.request(.library, as: LibraryPageDTO.self)
            XCTFail("Expected httpStatus 503")
        } catch APIClientError.httpStatus(let code, _) {
            XCTAssertEqual(code, 503)
        }

        let session = await store.currentSession()
        XCTAssertEqual(session?.accessToken, "expired")
        XCTAssertEqual(session?.refreshToken, "refresh-token")
    }

    func testSuccessfulRefreshPersistsRotatedSession() async throws {
        let store = SessionRefreshTestStore()
        let refreshedSession = SessionRefreshCapture()
        let lifecycle = SessionLifecycleHandlers()
        lifecycle.configure(onRefreshed: { session in
            await refreshedSession.set(session)
        })
        let client = try makeClient(store: store, lifecycle: lifecycle)
        SessionRefreshStubProtocol.handler = { request in
            switch request.url?.path {
            case "/ios-api/v1/me/library":
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-access" {
                    return (200, #"{"items":[]}"#)
                }
                return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
            case "/ios-api/v1/auth/refresh":
                return (200, """
                {"access_token":"refreshed-access","refresh_token":"refreshed-refresh","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}
                """)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "")")
                return (500, "{}")
            }
        }

        _ = try await client.request(.library, as: LibraryPageDTO.self)

        let session = await store.currentSession()
        XCTAssertEqual(session?.accessToken, "refreshed-access")
        XCTAssertEqual(session?.refreshToken, "refreshed-refresh")
        let notifiedSession = await refreshedSession.value()
        XCTAssertEqual(notifiedSession?.accessToken, "refreshed-access")
    }

    func testInvalidRefreshNotifiesLifecycleHandler() async throws {
        let store = SessionRefreshTestStore()
        let invalidated = SessionRefreshFlag()
        let lifecycle = SessionLifecycleHandlers()
        lifecycle.configure(onInvalidated: {
            await invalidated.set()
        })
        let client = try makeClient(store: store, lifecycle: lifecycle)
        SessionRefreshStubProtocol.handler = { request in
            switch request.url?.path {
            case "/ios-api/v1/me/library":
                return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
            case "/ios-api/v1/auth/refresh":
                return (403, #"{"errors":[{"code":"refresh_forbidden","message":"Forbidden"}]}"#)
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "")")
                return (500, "{}")
            }
        }

        do {
            _ = try await client.request(.library, as: LibraryPageDTO.self)
            XCTFail("Expected authenticationRequired")
        } catch APIClientError.authenticationRequired {
            // expected
        }

        let didInvalidate = await invalidated.isSetValue()
        let currentSession = await store.currentSession()
        XCTAssertTrue(didInvalidate)
        XCTAssertNil(currentSession)
    }

    func testPermissionDeniedAfterSuccessfulRefreshKeepsSession() async throws {
        let store = SessionRefreshTestStore()
        let invalidated = SessionRefreshFlag()
        let lifecycle = SessionLifecycleHandlers()
        lifecycle.configure(onInvalidated: { await invalidated.set() })
        let client = try makeClient(store: store, lifecycle: lifecycle)
        SessionRefreshStubProtocol.handler = { request in
            if request.url?.path == "/ios-api/v1/auth/refresh" {
                return (200, #"{"access_token":"refreshed-access","refresh_token":"refreshed-refresh","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#)
            }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-access" {
                return (403, #"{"errors":[{"code":"permission_denied","message":"Not permitted"}]}"#)
            }
            return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
        }
        do {
            _ = try await client.request(.library, as: LibraryPageDTO.self)
            XCTFail("Expected a resource permission error")
        } catch APIClientError.httpStatus(let code, _) {
            XCTAssertEqual(code, 403)
        }
        let session = await store.currentSession()
        let didInvalidate = await invalidated.isSetValue()
        XCTAssertEqual(session?.accessToken, "refreshed-access")
        XCTAssertFalse(didInvalidate)
    }

    func testLateSuccessfulRefreshCannotRestoreLoggedOutSession() async throws {
        try await assertStaleRefresh(status: 200, nextSession: nil)
    }

    func testSecond401AfterRefreshInvalidatesOnlyThatSession() async throws {
        let store = SessionRefreshTestStore()
        let client = try makeClient(store: store)
        SessionRefreshStubProtocol.handler = { request in
            if request.url?.path == "/ios-api/v1/auth/refresh" {
                return (200, #"{"access_token":"refreshed-access","refresh_token":"refreshed-refresh","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#)
            }
            return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
        }
        do {
            _ = try await client.request(.library, as: LibraryPageDTO.self)
            XCTFail("Expected authenticationRequired")
        } catch APIClientError.authenticationRequired {}
        let stored = await store.currentSession()
        XCTAssertNil(stored)
    }

    func testLateParallel401UsesAlreadyRotatedSessionWithoutRefreshingAgain() async throws {
        let store = SessionRefreshTestStore()
        let gate = ParallelRefreshGate()
        let started = expectation(description: "both old requests sent")
        let rotated = expectation(description: "rotation finished")
        let lifecycle = SessionLifecycleHandlers()
        lifecycle.configure(onRefreshed: { _ in rotated.fulfill() })
        let client = try makeClient(store: store, lifecycle: lifecycle)
        SessionRefreshStubProtocol.asyncHandler = { request in
            if request.url?.path == "/ios-api/v1/auth/refresh" {
                await gate.recordRefresh()
                return (200, #"{"access_token":"refreshed-access","refresh_token":"refreshed-refresh","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#)
            }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-access" { return (200, #"{"items":[]}"#) }
            await gate.holdOldResponse(started: started)
            return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
        }
        let first = Task { try await client.request(.library, as: LibraryPageDTO.self) }
        let second = Task { try await client.request(.library, as: LibraryPageDTO.self) }
        await fulfillment(of: [started], timeout: 3)
        await gate.releaseFirst()
        await fulfillment(of: [rotated], timeout: 3)
        await gate.releaseSecond()
        _ = try await first.value
        _ = try await second.value
        let refreshes = await gate.refreshes
        XCTAssertEqual(refreshes, 1)
    }

    func testLateSuccessfulRefreshCannotOverwriteNextAccount() async throws {
        try await assertStaleRefresh(status: 200, nextSession: Session(accessToken: "other", refreshToken: "other-refresh", username: "other"))
    }

    func testLateRejectedRefreshCannotClearNextAccount() async throws {
        try await assertStaleRefresh(status: 401, nextSession: Session(accessToken: "other", refreshToken: "other-refresh", username: "other"))
    }

    private func assertStaleRefresh(status: Int, nextSession: Session?) async throws {
        let store = SessionRefreshTestStore()
        let invalidated = SessionRefreshFlag()
        let refreshed = SessionRefreshCapture()
        let lifecycle = SessionLifecycleHandlers()
        lifecycle.configure(onRefreshed: { await refreshed.set($0) }, onInvalidated: { await invalidated.set() })
        let client = try makeClient(store: store, lifecycle: lifecycle)
        SessionRefreshStubProtocol.asyncHandler = { request in
            if request.url?.path == "/ios-api/v1/auth/refresh" {
                // The account changes after refresh starts and before its HTTP response arrives.
                if let nextSession { try await store.save(session: nextSession) }
                else { try await store.clear() }
                return (status, #"{"access_token":"late-access","refresh_token":"late-refresh","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer expired",
                           "An old request must not replay under the next account")
            return (401, #"{"errors":[{"code":"login_required","message":"Login"}]}"#)
        }
        do {
            _ = try await client.request(.library, as: LibraryPageDTO.self)
            XCTFail("A superseded refresh must be discarded")
        } catch is CancellationError {}
        let stored = await store.currentSession()
        let notified = await refreshed.value()
        let didInvalidate = await invalidated.isSetValue()
        XCTAssertEqual(stored, nextSession)
        XCTAssertNil(notified)
        XCTAssertFalse(didInvalidate)
    }

    private func makeClient(
        store: SessionRefreshTestStore,
        lifecycle: SessionLifecycleHandlers = SessionLifecycleHandlers()
    ) throws -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SessionRefreshStubProtocol.self]
        let session = URLSession(configuration: config)
        return APIClient(
            config: try AppConfig(
                environment: .staging,
                apiBaseURL: XCTUnwrap(URL(string: "https://staging.ekitapligim.com/ios-api/v1/")),
                webBaseURL: XCTUnwrap(URL(string: "https://ekitapligim.com/"))
            ),
            session: session,
            tokenProvider: store,
            sessionLifecycle: lifecycle
        )
    }
}

private actor SessionRefreshTestStore: SessionTokenManaging {
    private var session: Session? = Session(accessToken: "expired", refreshToken: "refresh-token", username: "reader")

    func currentSession() -> Session? { session }
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

private actor SessionRefreshCapture {
    private var session: Session?

    func set(_ session: Session) { self.session = session }
    func value() -> Session? { session }
}

private actor ParallelRefreshGate {
    var refreshes = 0
    var waiters: [CheckedContinuation<Void, Never>] = []
    func recordRefresh() { refreshes += 1 }
    func holdOldResponse(started: XCTestExpectation) async {
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
            if waiters.count == 2 { started.fulfill() }
        }
    }
    func releaseFirst() { if !waiters.isEmpty { waiters.removeFirst().resume() } }
    func releaseSecond() { if !waiters.isEmpty { waiters.removeFirst().resume() } }
}

private actor SessionRefreshFlag {
    private var isSet = false

    func set() { isSet = true }
    func isSetValue() -> Bool { isSet }
}

private final class SessionRefreshStubProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) throws -> (Int, String))?
    static var asyncHandler: ((URLRequest) async throws -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let handler = Self.asyncHandler {
            Task {
                do {
                    let (status, body) = try await handler(request)
                    guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
                        throw URLError(.badServerResponse)
                    }
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocol(self, didLoad: Data(body.utf8))
                    client?.urlProtocolDidFinishLoading(self)
                } catch { client?.urlProtocol(self, didFailWithError: error) }
            }
            return
        }
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (status, body) = try handler(request)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
