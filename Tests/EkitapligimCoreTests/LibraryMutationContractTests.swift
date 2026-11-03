import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class LibraryMutationContractTests: XCTestCase {
    func testFavoriteMutationSendsOnlyExplicitFavoriteWithoutChangingShelfOrProgress() async throws {
        let client = APIClient(config: try config(), tokenProvider: LibraryMutationTokens())
        for value in [true, false] {
            let endpoint = APIEndpoint.setLibraryFavorite(bookID: 41, isFavorite: value)
            XCTAssertEqual(endpoint.method, .put)
            XCTAssertEqual(endpoint.path, "me/library/41")
            XCTAssertTrue(endpoint.requiresAuthentication)
            XCTAssertEqual(endpoint.body, .form(["is_favorite": value ? "1" : "0"]))
            let request = try await client.authenticatedRequest(endpoint)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer library_fixture_token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
            XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), value ? "is_favorite=1" : "is_favorite=0")
        }
    }

    func testFavoriteRequiresAuthentication() async throws {
        let client = APIClient(config: try config())
        do {
            _ = try await client.authenticatedRequest(.setLibraryFavorite(bookID: 41, isFavorite: true))
            XCTFail("A guest must not write to another library.")
        } catch APIClientError.authenticationRequired { }
    }

    func testRepositoryAcceptsOnlyAcknowledgedFavoriteAndShelfWrites() async throws {
        let session = fixtureSession()
        defer { session.invalidateAndCancel() }
        let repository = BookRepository(apiClient: APIClient(config: try config(), session: session, tokenProvider: LibraryMutationTokens()))
        try await repository.setLibraryFavorite(bookID: 41, isFavorite: true)
        try await repository.setLibraryFavorite(bookID: 41, isFavorite: false)
        try await repository.updateLibraryItem(bookID: 41, shelfState: "OKUYORUM", progressPercent: 42, lastReadPage: 17)
    }

    func testRejectedAndUnacknowledgedWritesNeverReturnSuccess() async throws {
        let session = fixtureSession()
        defer { session.invalidateAndCancel() }
        let repository = BookRepository(apiClient: APIClient(config: try config(), session: session, tokenProvider: LibraryMutationTokens()))
        // false+message, success+errors, missing acknowledgement, HTTP denial, explicit zero, empty body.
        for id in 42...47 {
            for favoriteWrite in [true, false] {
                do {
                    if favoriteWrite {
                        try await repository.setLibraryFavorite(bookID: id, isFavorite: true)
                    } else {
                        try await repository.updateLibraryItem(bookID: id, shelfState: "OKUYORUM", progressPercent: 42, lastReadPage: 17)
                    }
                    XCTFail("Rejected library write \(id) was acknowledged.")
                } catch let error as APIClientError {
                    switch id {
                    case 42:
                        XCTAssertEqual(error.serverMessage, "Shelf change rejected.")
                    case 43:
                        guard case .httpStatus(200, let envelope) = error else { XCTFail("Expected error envelope"); continue }
                        XCTAssertEqual(envelope?.errors.first?.code, "shelf_error")
                    case 45:
                        guard case .httpStatus(403, _) = error else { XCTFail("Expected permission denial"); continue }
                    case 47:
                        guard case .decodingFailed = error else { XCTFail("Expected missing body rejection"); continue }
                    default:
                        XCTAssertEqual(error, .invalidResponse)
                    }
                }
            }
        }
    }

    func testLibraryCollectionAcceptsAndroidCompatibleEnvelopes() throws {
        let item = #"{"book_id":"41","shelf_state":"OKUYORUM","is_favorite":true,"progress_percent":"42","last_read_page":"17"}"#
        for payload in ["[\(item)]", "{\"items\":[\(item)]}", "{\"library\":[\(item)]}", "{\"data\":{\"items\":[\(item)]}}", "{\"data\":{\"library\":[\(item)]}}"] {
            let page = try JSONDecoder.ekitapligim.decode(LibraryPageDTO.self, from: Data(payload.utf8))
            let book = try XCTUnwrap(page.items.first)
            XCTAssertEqual(page.items.count, 1)
            XCTAssertTrue(book.isFavoriteItem)
            XCTAssertTrue(book.isOnReadingShelf)
            XCTAssertEqual(book.progressPercent, 42)
            XCTAssertEqual(book.lastReadPage, 17)
        }
        for payload in ["[]", #"{"items":[]}"#, #"{"library":[]}"#, #"{"data":{"items":[]}}"#] {
            XCTAssertTrue(try JSONDecoder.ekitapligim.decode(LibraryPageDTO.self, from: Data(payload.utf8)).items.isEmpty)
        }
    }

    func testMalformedLibraryCannotMasqueradeAsEmptyFavorites() {
        for payload in ["{}", #"{"success":true}"#, #"{"data":{}}"#, #"{"items":null}"#,
                        #"{"items":{}}"#, #"{"items":[{"title":"Missing identifier"}]}"#,
                        #"{"items":[{"book_id":"  "}]}"#, #"{"items":[{"book_id":"41"},null]}"#] {
            XCTAssertThrowsError(try JSONDecoder.ekitapligim.decode(LibraryPageDTO.self, from: Data(payload.utf8)), payload)
        }
    }

    private func config() throws -> AppConfig {
        AppConfig(environment: .staging,
            apiBaseURL: try XCTUnwrap(URL(string: "https://library-fixture.invalid/ios-api/v1/")),
            webBaseURL: try XCTUnwrap(URL(string: "https://library-fixture.invalid/")))
    }

    private func fixtureSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LibraryMutationStubProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private struct LibraryMutationTokens: AccessTokenProviding {
    func accessToken() async throws -> String? { "library_fixture_token" }
}

private final class LibraryMutationStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer library_fixture_token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        guard let url = request.url else { client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return }
        let id = Int(url.lastPathComponent) ?? 0
        let code = id == 45 ? 403 : 200
        let payload: String
        switch id {
        case 41: payload = #"{"success":true,"item":{"book_id":"41","shelf_state":"OKUYORUM","is_favorite":true}}"#
        case 42: payload = #"{"success":false,"message":"Shelf change rejected."}"#
        case 43: payload = #"{"success":true,"errors":[{"code":"shelf_error","message":"No change applied."}]}"#
        case 44: payload = "{}"
        case 45: payload = #"{"errors":[{"code":"no_permission","message":"Permission denied."}]}"#
        case 46: payload = #"{"success":"0"}"#
        case 47: payload = ""
        default: payload = "{}"
        }
        guard let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !payload.isEmpty { client?.urlProtocol(self, didLoad: Data(payload.utf8)) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
