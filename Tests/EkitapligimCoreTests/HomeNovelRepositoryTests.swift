import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class HomeNovelRepositoryTests: XCTestCase {
    func testRandomPageKeepsRomanLatestFiltersAndUsesOnlyItsFourValidBooks() async throws {
        let (repository, session) = try makeRepository(scenario: .selectedPage) { range in
            XCTAssertEqual(range, 1...3)
            return 3
        }
        defer { session.invalidateAndCancel() }

        let books = try await repository.books()

        XCTAssertEqual(books.count, 4)
        XCTAssertEqual(Set(books.map(\.id)), Set(["301", "302", "303", "304"]),
                       "A full random page must not be mixed with the first Roman page")
        XCTAssertTrue(books.allSatisfy { $0.category == "Roman" })
    }

    func testSinglePageSelectionIsValidUniqueAndNeverExceedsFourBooks() async throws {
        for scenario in [HomeNovelFixture.singlePageFull, .singlePageSparse] {
            let (repository, session) = try makeRepository(scenario: scenario) { range in
                XCTAssertEqual(range, 1...1)
                return 1
            }
            defer { session.invalidateAndCancel() }

            let books = try await repository.books()
            let identifiers = Set(books.map(\.id))
            let validIdentifiers: Set<String> = scenario == .singlePageFull
                ? ["201", "202", "203", "204", "205", "206"]
                : ["801", "802"]

            XCTAssertEqual(books.count, min(4, validIdentifiers.count))
            XCTAssertEqual(identifiers.count, books.count)
            XCTAssertTrue(identifiers.isSubset(of: validIdentifiers))
            XCTAssertTrue(books.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
    }

    func testEmptyRandomPageFallsBackToTheFirstRomanPage() async throws {
        let (repository, session) = try makeRepository(scenario: .emptySelectedPage) { range in
            XCTAssertEqual(range, 1...3)
            return 3
        }
        defer { session.invalidateAndCancel() }

        let books = try await repository.books()

        XCTAssertEqual(books.count, 4)
        XCTAssertEqual(Set(books.map(\.id)), Set(["101", "102", "103", "104"]))
        XCTAssertTrue(books.allSatisfy { $0.category == "Roman" })
    }

    func testFailedRandomPageFallsBackToTheFirstRomanPage() async throws {
        let (repository, session) = try makeRepository(scenario: .failedSelectedPage) { range in
            XCTAssertEqual(range, 1...3)
            return 3
        }
        defer { session.invalidateAndCancel() }

        let books = try await repository.books()

        XCTAssertEqual(books.count, 4)
        XCTAssertEqual(Set(books.map(\.id)), Set(["101", "102", "103", "104"]))
        XCTAssertTrue(books.allSatisfy { $0.category == "Roman" })
    }

    private func makeRepository(
        scenario: HomeNovelFixture,
        choosePage: @escaping @Sendable (ClosedRange<Int>) -> Int
    ) throws -> (HomeNovelRepository, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HomeNovelFixtureProtocol.self]
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        let config = AppConfig(
            environment: .staging,
            apiBaseURL: try XCTUnwrap(URL(string: "https://\(scenario.host)/ios-api/v1/")),
            webBaseURL: try XCTUnwrap(URL(string: "https://\(scenario.host)/"))
        )
        let client = APIClient(config: config, session: session, assistantSession: session)
        let catalog = BookRepository(apiClient: client)
        return (HomeNovelRepository(catalog: catalog, choosePage: choosePage), session)
    }
}

/// Immutable host/query fixtures keep parallel test cases independent of shared handlers.
private enum HomeNovelFixture: String {
    case selectedPage = "selected-page"
    case singlePageFull = "single-page-full"
    case singlePageSparse = "single-page-sparse"
    case emptySelectedPage = "empty-selected-page"
    case failedSelectedPage = "failed-selected-page"

    var host: String { "\(rawValue).example.invalid" }

    static func response(for request: URLRequest) throws -> (Int, Data) {
        let url = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let scenario = try XCTUnwrap(Self.allFixtures.first { $0.host == url.host })
        let query = components.queryItems ?? []
        let page = try XCTUnwrap(Int(query.first(where: { $0.name == "page" })?.value ?? ""))

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.path, "/ios-api/v1/books")
        XCTAssertEqual(query.count, 3, "Only the selected page and Roman/latest catalog filters are expected")
        XCTAssertEqual(query.first(where: { $0.name == "category" })?.value, "6",
                       "Every initial, selected and fallback request must stay in the Roman category")
        XCTAssertEqual(query.first(where: { $0.name == "order" })?.value, "latest",
                       "The server does not implement order=random")
        XCTAssertEqual(Set(query.map(\.name)), Set(["page", "category", "order"]))

        let singlePage = scenario == .singlePageFull || scenario == .singlePageSparse
        guard page == 1 || (!singlePage && page == 3) else {
            XCTFail("Unexpected fixture page \(page) for \(scenario.rawValue)")
            throw URLError(.unsupportedURL)
        }
        if scenario == .failedSelectedPage, page == 3 {
            return (503, Data(#"{"errors":[{"code":"temporarily_unavailable","message":"Try again"}]}"#.utf8))
        }

        let books: [[String: Any]]
        if scenario == .singlePageFull {
            books = (201...206).map { book(id: String($0)) }
        } else if scenario == .singlePageSparse {
            books = [book(id: "801"), book(id: "801"), book(id: "802"),
                     book(id: "  "), book(id: "803", title: " \n ")]
        } else if page == 1 {
            books = (101...104).map { book(id: String($0)) }
        } else if scenario == .emptySelectedPage {
            books = []
        } else {
            books = (301...304).map { book(id: String($0)) }
        }
        let payload: [String: Any] = [
            "books": books,
            "pagination": ["page": page, "pages": singlePage ? 1 : 3, "total": singlePage ? books.count : 60]
        ]
        return (200, try JSONSerialization.data(withJSONObject: payload))
    }

    private static var allFixtures: [Self] {
        [.selectedPage, .singlePageFull, .singlePageSparse, .emptySelectedPage, .failedSelectedPage]
    }

    private static func book(id: String, title: String? = nil) -> [String: Any] {
        ["id": id, "title": title ?? "Roman \(id)", "author": "Örnek Yazar", "publisher": "",
         "isbn": "", "category": "Roman", "language": "tr", "publishYear": "",
         "description": "", "coverUrl": "", "pdfUrl": "", "pageCount": 120, "isPremiumOnly": false]
    }
}

private final class HomeNovelFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, data) = try HomeNovelFixture.response(for: request)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
