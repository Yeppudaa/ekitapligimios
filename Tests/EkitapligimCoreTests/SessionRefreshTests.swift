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

    func testSecondResource401AfterRefreshPreservesRotatedSession() async throws {
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
            XCTFail("Expected resource authentication error")
        } catch APIClientError.httpStatus(let status, _) { XCTAssertEqual(status, 401) }
        let stored = await store.currentSession()
        XCTAssertEqual(stored?.accessToken, "refreshed-access")
        XCTAssertEqual(stored?.refreshToken, "refreshed-refresh")
    }

    func testGatewayAndPermissionRefreshErrorsPreserveSession() async throws {
        for (status, body) in [
            (401, "<html>Gateway authentication required</html>"),
            (403, #"{"errors":[{"code":"permission_denied","message":"Forbidden"}]}"#),
            (429, #"{"errors":[{"code":"rate_limit","message":"Try later"}]}"#)
        ] {
            let store = SessionRefreshTestStore()
            let invalidated = SessionRefreshFlag()
            let lifecycle = SessionLifecycleHandlers()
            lifecycle.configure(onInvalidated: { await invalidated.set() })
            let client = try makeClient(store: store, lifecycle: lifecycle)
            SessionRefreshStubProtocol.handler = { request in
                request.url?.path == "/ios-api/v1/auth/refresh" ? (status, body) : (401, "{}")
            }
            do {
                _ = try await client.request(.library, as: LibraryPageDTO.self)
                XCTFail("Expected refresh failure")
            } catch APIClientError.httpStatus(let code, _) { XCTAssertEqual(code, status) }
            let stored = await store.currentSession()
            let didInvalidate = await invalidated.isSetValue()
            XCTAssertEqual(stored?.accessToken, "expired")
            XCTAssertEqual(stored?.refreshToken, "refresh-token")
            XCTAssertFalse(didInvalidate)
        }
    }

    func testRefreshWithoutReplacementRefreshTokenPreservesExistingToken() async throws {
        for field in ["", #", "refresh_token":null"#, #", "refresh_token":"   ""#] {
            let store = SessionRefreshTestStore()
            let client = try makeClient(store: store)
            SessionRefreshStubProtocol.handler = { _ in
                (200, """
                {"access_token":"refreshed-access"\(field),"user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}
                """)
            }
            let token = try await client.refreshAccessToken(afterUnauthorized: "expired")
            let stored = await store.currentSession()
            XCTAssertEqual(token, "refreshed-access")
            XCTAssertEqual(stored?.refreshToken, "refresh-token")
        }
    }

    func testMalformedOrWrongAccountRefreshCannotReplaceStoredCredentials() async throws {
        for body in [
            "{}",
            #"{"access_token":" ","refresh_token":"next","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#,
            #"{"access_token":"other","refresh_token":"next","user":{"username":"other","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#
        ] {
            let store = SessionRefreshTestStore()
            let client = try makeClient(store: store)
            SessionRefreshStubProtocol.handler = { _ in (200, body) }
            do {
                _ = try await client.refreshAccessToken(afterUnauthorized: "expired")
                XCTFail("Expected invalid refresh payload")
            } catch APIClientError.invalidResponse {
            } catch APIClientError.decodingFailed {}
            let stored = await store.currentSession()
            XCTAssertEqual(stored?.accessToken, "expired")
            XCTAssertEqual(stored?.refreshToken, "refresh-token")
        }
    }

    func testRefreshUsesStableUserIDForRenamedAccountAndRejectsOtherID() async throws {
        for responseID in [7, 8] {
            let store = SessionRefreshTestStore()
            let original = Session(accessToken: "expired", refreshToken: "refresh-token", username: "reader", userID: "7")
            try await store.save(session: original)
            let client = try makeClient(store: store)
            SessionRefreshStubProtocol.handler = { _ in
                (200, """
                {"access_token":"refreshed-access","refresh_token":"next","user":{"user_id":\(responseID),"username":"renamed-reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}
                """)
            }
            do {
                _ = try await client.refreshAccessToken(afterUnauthorized: "expired")
                XCTAssertEqual(responseID, 7)
            } catch APIClientError.invalidResponse { XCTAssertEqual(responseID, 8) }
            let stored = await store.currentSession()
            XCTAssertEqual(stored?.userID, "7")
            XCTAssertEqual(stored?.accessToken, responseID == 7 ? "refreshed-access" : "expired")
        }
    }

    func testLoginRejectionDoesNotRefreshOrInvalidateExistingSession() async throws {
        let store = SessionRefreshTestStore()
        let client = try makeClient(store: store)
        SessionRefreshStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/ios-api/v1/auth/login")
            return (401, #"{"errors":[{"code":"login_invalid","message":"Invalid credentials"}]}"#)
        }
        do {
            _ = try await client.request(APIEndpoint(method: .post, path: "auth/login"), as: AuthResponseDTO.self)
            XCTFail("Expected login rejection")
        } catch APIClientError.httpStatus(let status, _) { XCTAssertEqual(status, 401) }
        let stored = await store.currentSession()
        XCTAssertEqual(stored?.accessToken, "expired")
    }

    func testLegacySessionWithoutRefreshTokenIsNotDeletedByResource401() async throws {
        let store = SessionRefreshTestStore()
        let original = Session(accessToken: "legacy", refreshToken: nil, username: "reader")
        try await store.save(session: original)
        let client = try makeClient(store: store)
        SessionRefreshStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/ios-api/v1/me/library")
            return (401, "{}")
        }
        do {
            _ = try await client.request(.library, as: LibraryPageDTO.self)
            XCTFail("Expected authentication error")
        } catch APIClientError.authenticationRequired {}
        let stored = await store.currentSession()
        XCTAssertEqual(stored, original)
    }

    func testRejectedFileTokenFromPreviousAccountCannotRefreshCurrentAccount() async throws {
        let store = SessionRefreshTestStore()
        let client = try makeClient(store: store)
        SessionRefreshStubProtocol.handler = { _ in
            XCTFail("An unknown stale token must never start a refresh")
            return (500, "{}")
        }
        do {
            _ = try await client.refreshAccessToken(afterUnauthorized: "previous-account-access")
            XCTFail("Expected stale request cancellation")
        } catch is CancellationError {}
        let stored = await store.currentSession()
        XCTAssertEqual(stored?.accessToken, "expired")
    }

    func testClosingCallerDuringRefreshStillPersistsRotatedCredentials() async throws {
        let store = SessionRefreshTestStore()
        let client = try makeClient(store: store)
        let started = expectation(description: "refresh started")
        let gate = SessionRefreshResponseGate()
        SessionRefreshStubProtocol.asyncHandler = { _ in
            started.fulfill()
            await gate.wait()
            return (200, #"{"access_token":"refreshed-access","refresh_token":"next","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#)
        }
        let caller = Task { try await client.refreshAccessToken(afterUnauthorized: "expired") }
        await fulfillment(of: [started], timeout: 3)
        caller.cancel()
        await gate.release()
        _ = try await caller.value
        let stored = await store.currentSession()
        XCTAssertEqual(stored?.accessToken, "refreshed-access")
        XCTAssertEqual(stored?.refreshToken, "next")
    }

    func testProtectedFileAndAPIRequestsShareOneRefresh() async throws {
        let store = SessionRefreshTestStore()
        let client = try makeClient(store: store)
        let gate = SessionRefreshResponseGate()
        let started = expectation(description: "file refresh started")
        let apiStarted = expectation(description: "API request started")
        let refreshCount = SessionRefreshCount()
        SessionRefreshStubProtocol.asyncHandler = { request in
            if request.url?.path == "/ios-api/v1/auth/refresh" {
                await refreshCount.increment()
                started.fulfill()
                await gate.wait()
                return (200, #"{"access_token":"refreshed-access","refresh_token":"next","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#)
            }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
                apiStarted.fulfill()
                return (401, "{}")
            }
            return (200, #"{"items":[]}"#)
        }
        let file = Task { try await client.refreshAccessToken(afterUnauthorized: "expired") }
        await fulfillment(of: [started], timeout: 3)
        let api = Task { try await client.request(.library, as: LibraryPageDTO.self) }
        await fulfillment(of: [apiStarted], timeout: 3)
        await gate.release()
        let token = try await file.value
        _ = try await api.value
        let count = await refreshCount.value
        XCTAssertEqual(token, "refreshed-access")
        XCTAssertEqual(count, 1)
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

    func testLateExplicitRefreshRejectionCannotClearNextAccount() async throws {
        try await assertStaleRefresh(status: 401,
            nextSession: Session(accessToken: "other", refreshToken: "other-refresh", username: "other"),
            failureBody: #"{"errors":[{"code":"refresh_token_invalid","message":"Expired"}]}"#)
    }

    func testLateTemporaryRefreshFailureIsCancelledAfterAccountSwitch() async throws {
        try await assertStaleRefresh(status: 503, nextSession: Session(accessToken: "other", refreshToken: "other-refresh", username: "other"))
    }

    func testLateTemporaryRefreshFailureIsCancelledAfterLogout() async throws {
        try await assertStaleRefresh(status: 503, nextSession: nil)
    }

    private func assertStaleRefresh(status: Int, nextSession: Session?, failureBody: String? = nil) async throws {
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
                return (status, failureBody ?? #"{"access_token":"late-access","refresh_token":"late-refresh","user":{"username":"reader","email":"reader@example.invalid","is_premium":false,"premium_plan_name":"member"}}"#)
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

private actor SessionRefreshCount {
    var value = 0
    func increment() { value += 1 }
}

private actor SessionRefreshResponseGate {
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        guard !released else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { released = true; continuation?.resume(); continuation = nil }
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
