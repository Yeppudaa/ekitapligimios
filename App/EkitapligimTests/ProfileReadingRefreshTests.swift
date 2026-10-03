import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class ProfileReadingRefreshTests: XCTestCase {
    override func tearDown() {
        ProfileReadingProtocol.handler = nil
        super.tearDown()
    }

    func testOlderSessionRefreshCannotOverwriteLaterContinueReadingPage() async throws {
        let responses = LibraryResponseGate()
        let started = expectation(description: "older library request started")
        let container = makeContainer { request in
            guard request.url?.path.hasSuffix("/me/library") == true else { return "{}" }
            return await responses.library(firstStarted: started)
        }
        let older = Task { await container.refreshSessionData() }
        await fulfillment(of: [started], timeout: 3)
        await container.refreshSessionData()
        XCTAssertEqual(container.continueReadingItem?.lastReadPage, 40)
        await responses.release()
        await older.value
        XCTAssertEqual(container.continueReadingItem?.lastReadPage, 40)
    }

    func testPreparedBookPublishesContinueCardBeforeAnyNewPageIsRecorded() async throws {
        let container = makeContainer { request in
            if request.url?.path.hasSuffix("/books/7/reader/progress") == true {
                return #"{"progress":{"position_type":"pdf","position_value":"25","progress_percent":25,"last_read_date":300},"revision":"server"}"#
            }
            return "{}"
        }
        defer { try? container.readerProgressSync.eraseCurrentAccount() }
        let book = try JSONDecoder.ekitapligim.decode(BookDTO.self,
            from: Data(#"{"id":"7","title":"Restored book","author":"Author","publisher":"Publisher","isbn":"","category":"Novel","language":"tr","publish_year":"2026","description":"Description","cover_url":"","pdf_url":"","page_count":100,"is_premium_only":false}"#.utf8))
        _ = try await container.prepareReaderProgress(book: book)
        XCTAssertEqual(container.continueReadingItem?.bookId, "7")
        XCTAssertEqual(container.continueReadingItem?.title, "Restored book")
        XCTAssertEqual(container.continueReadingItem?.lastReadPage, 25)
    }

    func testSameAccountTokenRotationPreservesInFlightLibraryRefresh() async throws {
        let responses = LibraryResponseGate()
        let started = expectation(description: "library request before token rotation")
        let container = makeContainer { request in
            guard request.url?.path.hasSuffix("/me/library") == true else { return "{}" }
            return await responses.library(firstStarted: started)
        }
        let refresh = Task { await container.refreshLibrary() }
        await fulfillment(of: [started], timeout: 3)
        guard case .signedIn(let session) = container.authState else { return XCTFail("Expected signed-in account") }
        container.authState = .signedIn(Session(accessToken: "rotated-access", refreshToken: "rotated-refresh", username: session.username))
        await responses.release()
        let refreshed = await refresh.value
        XCTAssertTrue(refreshed)
        XCTAssertEqual(container.continueReadingItem?.lastReadPage, 25)
    }

    private func makeContainer(handler: @escaping @Sendable (URLRequest) async -> String) -> AppContainer {
        ProfileReadingProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProfileReadingProtocol.self]
        let session = Session(accessToken: "test-access", refreshToken: "test-refresh", username: UUID().uuidString)
        let container = AppContainer(apiSession: URLSession(configuration: configuration), tokenStore: ProfileReadingTokenStore(session: session))
        container.authState = .signedIn(session)
        return container
    }
}

private actor ProfileReadingTokenStore: TokenStore {
    var session: Session?
    init(session: Session) { self.session = session }
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

private actor LibraryResponseGate {
    private var requests = 0
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?

    func library(firstStarted: XCTestExpectation) async -> String {
        requests += 1
        let requestNumber = requests
        if requestNumber == 1 {
            firstStarted.fulfill()
            if !released { await withCheckedContinuation { continuation = $0 } }
        }
        let page = requestNumber == 1 ? 25 : 40
        return "{\"items\":[{\"book_id\":\"7\",\"shelf_state\":\"OKUYORUM\",\"last_read_page\":\(page),\"progress_percent\":\(page),\"last_read_date\":\(100 + requestNumber),\"title\":\"Book\"}]}"
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

private final class ProfileReadingProtocol: URLProtocol, @unchecked Sendable {
    static var handler: (@Sendable (URLRequest) async -> String)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        Task {
            let body = await handler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
