import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class SessionRefreshTests: XCTestCase {
    override func tearDown() {
        SessionRefreshStubProtocol.handler = nil
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
}

private actor SessionRefreshCapture {
    private var session: Session?

    func set(_ session: Session) { self.session = session }
    func value() -> Session? { session }
}

private actor SessionRefreshFlag {
    private var isSet = false

    func set() { isSet = true }
    func isSetValue() -> Bool { isSet }
}

private final class SessionRefreshStubProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) throws -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
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
