import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class BookLibraryMutationTests: XCTestCase {
    func testFavoriteForANewBookCreatesItsLibraryItemWithBookMetadata() async throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let notifications = LibraryActivityCounter()
        defer { notifications.stop() }
        let book = try book()
        XCTAssertTrue(fixture.container.libraryItems.isEmpty)

        try await fixture.container.setBookFavorite(book: book, isFavorite: true)

        let saved = try XCTUnwrap(fixture.container.libraryItems.first)
        XCTAssertEqual(saved.bookId, book.id)
        XCTAssertEqual(saved.title, book.title)
        XCTAssertEqual(saved.author, book.author)
        XCTAssertEqual(saved.coverUrl, book.coverUrl)
        XCTAssertEqual(saved.pageCount, book.pageCount)
        XCTAssertFalse(saved.isDownloaded)
        XCTAssertTrue(saved.isFavorite)
        assertItem(fixture.container, state: "NONE", favorite: true, percent: 0, page: 0)
        XCTAssertEqual(fixture.container.favoriteBooks.map(\.bookId), [book.id])
        XCTAssertTrue(fixture.container.libraryUpdatingBookIDs.isEmpty)
        XCTAssertEqual(notifications.count, 1)
        let requests = await fixture.server.requests
        XCTAssertEqual(requests.map(\.form), [["is_favorite": "1"]])
    }

    func testFavoriteAdditionAndRemovalPreserveReadingShelfAndPosition() async throws {
        let fixture = try makeFixture(item: item())
        defer { fixture.close() }
        let notifications = LibraryActivityCounter()
        defer { notifications.stop() }
        let book = try book()

        try await fixture.container.setBookFavorite(book: book, isFavorite: true)

        XCTAssertEqual(fixture.container.favoriteBooks.map(\.bookId), [book.id])
        assertItem(fixture.container, state: "OKUYORUM", favorite: true, percent: 42, page: 17)
        XCTAssertTrue(fixture.container.libraryUpdatingBookIDs.isEmpty)

        try await fixture.container.setBookFavorite(book: book, isFavorite: false)

        XCTAssertTrue(fixture.container.favoriteBooks.isEmpty)
        assertItem(fixture.container, state: "OKUYORUM", favorite: false, percent: 42, page: 17)
        XCTAssertNil(fixture.container.libraryMutationErrors[101])
        XCTAssertEqual(notifications.count, 2)
        let requests = await fixture.server.requests
        XCTAssertEqual(requests.map(\.form), [["is_favorite": "1"], ["is_favorite": "0"]])
    }

    func testFavoriteToggleKeepsExplicitNoneShelfWithExistingReaderProgress() async throws {
        let fixture = try makeFixture(item: item(state: "NONE", percent: 37, page: 14))
        defer { fixture.close() }

        for value in [true, false] {
            try await fixture.container.setBookFavorite(book: book(), isFavorite: value)
            assertItem(fixture.container, state: "NONE", favorite: value, percent: 37, page: 14)
        }
    }

    func testReadingShelfChangesPreserveIndependentFavoriteAndProgress() async throws {
        let fixture = try makeFixture(item: item(favorite: true))
        defer { fixture.close() }
        for state in ["OKUYACAGIM", "OKUDUM", "NONE", "OKUYORUM"] {
            try await fixture.container.updateBookShelf(book: book(), state: state)
            assertItem(fixture.container, state: state, favorite: true, percent: 42, page: 17)
        }
        let requests = await fixture.server.requests
        XCTAssertEqual(requests.count, 4)
        for request in requests {
            XCTAssertNil(request.form["is_favorite"], "Reading shelf writes must leave favorite membership alone.")
            XCTAssertEqual(request.form["progress_percent"], "42")
            XCTAssertEqual(request.form["last_read_page"], "17")
        }
    }

    func testAuthorizedReadingPromotesLegacyFavoriteAndWantToReadWithoutLosingFavorite() async throws {
        for (state, favorite) in [("FAVORI", true), ("OKUYACAGIM", false), ("NONE", false)] {
            // Legacy FAVORI responses can omit the independent flag; shelf membership still counts.
            let fixture = try makeFixture(item: item(state: state, percent: 0, page: 0))
            let opened = await fixture.container.markBookReading(book: try book())
            XCTAssertTrue(opened)
            assertItem(fixture.container, state: "OKUYORUM", favorite: favorite, percent: 0, page: 0)
            XCTAssertGreaterThan(fixture.container.libraryItems.first?.lastReadAt ?? 0, 123)
            let requests = await fixture.server.requests
            XCTAssertEqual(requests.map { $0.form["shelf_state"] }, ["OKUYORUM"])
            fixture.close()
        }
    }

    func testOpeningAnAlreadyReadingOrFinishedBookDoesNotOverwriteItsShelf() async throws {
        for state in ["OKUYORUM", "OKUDUM"] {
            let fixture = try makeFixture(item: item(state: state, favorite: true))
            let notifications = LibraryActivityCounter()
            let opened = await fixture.container.markBookReading(book: try book())
            XCTAssertTrue(opened)
            assertItem(fixture.container, state: state, favorite: true, percent: 42, page: 17)
            let requests = await fixture.server.requests
            XCTAssertTrue(requests.isEmpty, "Opening an existing shelf must not reset shared library state.")
            XCTAssertEqual(notifications.count, 1, "Actual reader opens still invalidate the server-backed activity feed.")
            notifications.stop()
            fixture.close()
        }
    }

    func testRejectedWritesKeepExistingLibraryAndDoNotNotifyTheActivityFeed() async throws {
        let original = item()
        let fixture = try makeFixture(item: original, rejectWrites: true)
        defer { fixture.close() }
        let notifications = LibraryActivityCounter()
        defer { notifications.stop() }
        for favoriteWrite in [true, false] {
            do {
                if favoriteWrite {
                    try await fixture.container.setBookFavorite(book: book(), isFavorite: true)
                } else {
                    try await fixture.container.updateBookShelf(book: book(), state: "OKUDUM")
                }
                XCTFail("A rejected write must fail instead of changing the library.")
            } catch { }
            XCTAssertEqual(fixture.container.libraryItems, [original])
            XCTAssertNotNil(fixture.container.libraryMutationErrors[101])
            XCTAssertTrue(fixture.container.libraryUpdatingBookIDs.isEmpty)
        }
        XCTAssertEqual(notifications.count, 0)
    }

    func testAccountChangeDiscardsAnOldResponseWithoutMutatingTheNextLibrary() async throws {
        let started = expectation(description: "Old account favorite request suspended")
        let gate = LibraryMutationGate(started: started)
        let fixture = try makeFixture(item: item(), gates: [1: gate])
        defer { fixture.close() }
        let notifications = LibraryActivityCounter()
        defer { notifications.stop() }
        let mutation = Task { try await fixture.container.setBookFavorite(book: book(), isFavorite: true) }
        await fulfillment(of: [started], timeout: 3)

        await fixture.switchAccount()
        let nextAccountItem = item(state: "OKUYACAGIM", percent: 7, page: 2)
        fixture.container.upsertLibraryItem(nextAccountItem)
        await gate.release()

        do { try await mutation.value; XCTFail("The old account response must be cancelled.") }
        catch is CancellationError { }
        XCTAssertEqual(fixture.container.libraryItems, [nextAccountItem])
        XCTAssertTrue(fixture.container.libraryUpdatingBookIDs.isEmpty)
        XCTAssertNil(fixture.container.libraryMutationErrors[101])
        XCTAssertEqual(notifications.count, 0)
    }

    func testOldAccountCleanupCannotClearTheNextAccountsBusyOperation() async throws {
        let oldStarted = expectation(description: "Old account request suspended")
        let newStarted = expectation(description: "New account request suspended")
        let oldGate = LibraryMutationGate(started: oldStarted)
        let newGate = LibraryMutationGate(started: newStarted)
        let fixture = try makeFixture(item: item(), gates: [1: oldGate, 2: newGate])
        defer { fixture.close() }
        let notifications = LibraryActivityCounter()
        defer { notifications.stop() }
        let oldMutation = Task { try await fixture.container.setBookFavorite(book: book(), isFavorite: true) }
        await fulfillment(of: [oldStarted], timeout: 3)

        await fixture.switchAccount()
        fixture.container.upsertLibraryItem(item(state: "OKUYACAGIM", percent: 7, page: 2))
        let nextMutation = Task { try await fixture.container.setBookFavorite(book: book(), isFavorite: true) }
        await waitForBusy(fixture.container)
        await oldGate.release()
        await fulfillment(of: [newStarted], timeout: 3)

        do { try await oldMutation.value; XCTFail("Old mutation must not commit.") }
        catch is CancellationError { }
        XCTAssertEqual(fixture.container.libraryUpdatingBookIDs, [101])
        XCTAssertEqual(notifications.count, 0)
        await newGate.release()
        try await nextMutation.value

        assertItem(fixture.container, state: "OKUYACAGIM", favorite: true, percent: 7, page: 2)
        XCTAssertTrue(fixture.container.libraryUpdatingBookIDs.isEmpty)
        XCTAssertEqual(notifications.count, 1)
    }

    func testFavoriteAcknowledgementRebasesOntoReaderProgressChangedDuringTheRequest() async throws {
        let started = expectation(description: "Favorite request suspended while reader moves")
        let gate = LibraryMutationGate(started: started)
        let fixture = try makeFixture(item: item(), gates: [1: gate])
        defer { fixture.close() }
        let mutation = Task { try await fixture.container.setBookFavorite(book: book(), isFavorite: true) }
        await fulfillment(of: [started], timeout: 3)
        fixture.container.patchLibraryItem("101") {
            $0.updating(progressPercent: 74, lastReadPage: 41, isDownloaded: true, lastReadAt: 789)
        }
        await gate.release()
        try await mutation.value

        assertItem(fixture.container, state: "OKUYORUM", favorite: true, percent: 74, page: 41)
        XCTAssertEqual(fixture.container.libraryItems.first?.lastReadAt, 789)
        XCTAssertEqual(fixture.container.libraryItems.first?.isDownloaded, true)
    }

    func testShelfAcknowledgementRebasesOntoReaderProgressChangedDuringTheRequest() async throws {
        let started = expectation(description: "Shelf request suspended while reader moves")
        let gate = LibraryMutationGate(started: started)
        let fixture = try makeFixture(item: item(favorite: true), gates: [1: gate])
        defer { fixture.close() }
        let mutation = Task { try await fixture.container.updateBookShelf(book: book(), state: "OKUDUM") }
        await fulfillment(of: [started], timeout: 3)
        fixture.container.patchLibraryItem("101") {
            $0.updating(progressPercent: 74, lastReadPage: 41, lastReadAt: 789)
        }
        await gate.release()
        try await mutation.value

        assertItem(fixture.container, state: "OKUDUM", favorite: true, percent: 74, page: 41)
        XCTAssertEqual(fixture.container.libraryItems.first?.lastReadAt, 789)
    }

    func testQueuedShelfWriteReadsPositionAfterThePrecedingReaderWriteFinishes() async throws {
        let started = expectation(description: "Preceding reader operation suspended")
        let gate = LibraryMutationGate(started: started)
        let fixture = try makeFixture(item: item(favorite: true))
        defer { fixture.close() }
        fixture.container.readerWrites.enqueue {
            await gate.wait()
            fixture.container.patchLibraryItem("101") { $0.updating(progressPercent: 74, lastReadPage: 41) }
        }
        await fulfillment(of: [started], timeout: 3)
        let mutation = Task { try await fixture.container.updateBookShelf(book: book(), state: "OKUYACAGIM") }
        await waitForBusy(fixture.container)
        let requestsBeforeRelease = await fixture.server.requests
        XCTAssertTrue(requestsBeforeRelease.isEmpty)
        await gate.release()
        try await mutation.value

        let requests = await fixture.server.requests
        XCTAssertEqual(requests.first?.form["progress_percent"], "74")
        XCTAssertEqual(requests.first?.form["last_read_page"], "41")
        assertItem(fixture.container, state: "OKUYACAGIM", favorite: true, percent: 74, page: 41)
    }

    private func waitForBusy(_ container: AppContainer) async {
        for _ in 0..<1_000 {
            if container.libraryUpdatingBookIDs.contains(101) { return }
            await Task.yield()
        }
        XCTFail("Library operation did not enter its busy state.")
    }

    private func assertItem(_ container: AppContainer, state: String, favorite: Bool, percent: Int, page: Int,
        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(container.libraryItems.count, 1, file: file, line: line)
        XCTAssertEqual(container.libraryItems.first?.shelfState, state, file: file, line: line)
        XCTAssertEqual(container.libraryItems.first?.isFavoriteItem, favorite, file: file, line: line)
        XCTAssertEqual(container.libraryItems.first?.progressPercent, percent, file: file, line: line)
        XCTAssertEqual(container.libraryItems.first?.lastReadPage, page, file: file, line: line)
    }

    private func item(state: String = "OKUYORUM", favorite: Bool = false, percent: Int = 42, page: Int = 17) -> LibraryItemDTO {
        LibraryItemDTO(bookId: "101", shelfState: state, progressPercent: percent, lastReadPage: page,
            isDownloaded: false, isFavorite: favorite, title: "Fixture book", author: "Fixture author",
            coverUrl: "", pageCount: 100, lastReadAt: 123)
    }

    private func book() throws -> BookDTO {
        try JSONDecoder.ekitapligim.decode(BookDTO.self, from: Data(#"{"id":"101","title":"Fixture book","author":"Fixture author","publisher":"","isbn":"","category":"","language":"tr","publish_year":"","description":"","cover_url":"https://fixture.invalid/101.jpg","pdf_url":"","page_count":100,"is_premium_only":false}"#.utf8))
    }

    private func makeFixture(item: LibraryItemDTO? = nil, rejectWrites: Bool = false,
        gates: [Int: LibraryMutationGate] = [:]) throws -> LibraryMutationContext {
        let server = LibraryMutationServer(rejectWrites: rejectWrites, gates: gates)
        let fixtureID = UUID().uuidString
        LibraryMutationProtocolRegistry.install(server, id: fixtureID)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BookLibraryMutationProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let session = Session(accessToken: "library_mutation_fixture_a_\(fixtureID)", refreshToken: nil,
            username: "LibraryMutationFixture_\(fixtureID)", userID: fixtureID)
        let tokens = BookLibraryMutationTokens(session: session)
        let container = AppContainer(apiSession: urlSession, tokenStore: tokens)
        container.authState = .signedIn(session)
        #if canImport(StoreKit)
        container.storeKit.stopObservingTransactions()
        #endif
        if let item { container.upsertLibraryItem(item) }
        return LibraryMutationContext(container: container, server: server, tokens: tokens,
            urlSession: urlSession, fixtureID: fixtureID)
    }
}

@MainActor
private struct LibraryMutationContext {
    let container: AppContainer
    let server: LibraryMutationServer
    let tokens: BookLibraryMutationTokens
    let urlSession: URLSession
    let fixtureID: String

    func switchAccount() async {
        let next = Session(accessToken: "library_mutation_fixture_b_\(fixtureID)", refreshToken: nil,
            username: "LibraryMutationNextFixture_\(fixtureID)", userID: "next_\(fixtureID)")
        await tokens.save(session: next)
        container.authState = .signedIn(next)
        #if canImport(StoreKit)
        container.storeKit.stopObservingTransactions()
        #endif
    }

    func close() {
        container.authState = .signedOut
        urlSession.invalidateAndCancel()
        LibraryMutationProtocolRegistry.remove(id: fixtureID)
    }
}

private actor BookLibraryMutationTokens: TokenStore {
    private var session: Session?
    init(session: Session) { self.session = session }
    func accessToken() async throws -> String? { session?.accessToken }
    func loadSession() async throws -> Session? { session }
    func save(session: Session) { self.session = session }
    func clear() { session = nil }
    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool {
        guard self.session == expected else { return false }
        self.session = session
        return true
    }
}

private actor LibraryMutationGate {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    init(started: XCTestExpectation) { self.started = started }
    func wait() async {
        started.fulfill()
        guard !released else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { released = true; continuation?.resume(); continuation = nil }
}

private struct LibraryMutationRequest: Sendable {
    let form: [String: String]
    let bearer: String?
}

private actor LibraryMutationServer {
    private(set) var requests: [LibraryMutationRequest] = []
    let rejectWrites: Bool
    let gates: [Int: LibraryMutationGate]
    init(rejectWrites: Bool, gates: [Int: LibraryMutationGate]) { self.rejectWrites = rejectWrites; self.gates = gates }
    func response(for request: URLRequest) async throws -> Data {
        guard request.httpMethod == "PUT", request.url?.path.hasSuffix("/me/library/101") == true else {
            XCTFail("Unexpected request in library mutation test: \(request.httpMethod ?? "") \(request.url?.path ?? "")")
            throw URLError(.unsupportedURL)
        }
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        let raw = try Self.body(of: request)
        let text = String(decoding: raw, as: UTF8.self)
        let query = URLComponents(string: "https://fixture.invalid/?\(text)")?.queryItems ?? []
        let form = Dictionary(query.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, latest in latest })
        requests.append(LibraryMutationRequest(form: form, bearer: request.value(forHTTPHeaderField: "Authorization")))
        if let gate = gates[requests.count] { await gate.wait() }
        return Data((rejectWrites ? #"{"success":false,"message":"Fixture write rejected."}"# : #"{"success":true}"#).utf8)
    }

    private static func body(of request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw URLError(.cannotDecodeContentData) }
            if count == 0 { break }
            result.append(buffer, count: count)
            guard result.count <= 8_192 else { throw URLError(.dataLengthExceedsMaximum) }
        }
        return result
    }
}

private final class LibraryActivityCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    private var observer: NSObjectProtocol?
    init() {
        observer = NotificationCenter.default.addObserver(forName: .libraryActivityChanged, object: nil, queue: nil) { [weak self] _ in
            self?.increment()
        }
    }
    private func increment() { lock.lock(); defer { lock.unlock() }; value += 1 }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
    deinit { stop() }
}

private enum LibraryMutationProtocolRegistry {
    private static let lock = NSLock()
    private static var servers: [String: LibraryMutationServer] = [:]
    static func install(_ server: LibraryMutationServer, id: String) {
        lock.lock(); defer { lock.unlock() }
        for prefix in ["a", "b"] { servers["Bearer library_mutation_fixture_\(prefix)_\(id)"] = server }
    }
    static func remove(id: String) {
        lock.lock(); defer { lock.unlock() }
        for prefix in ["a", "b"] { servers["Bearer library_mutation_fixture_\(prefix)_\(id)"] = nil }
    }
    static func server(for request: URLRequest) -> LibraryMutationServer? {
        lock.lock(); defer { lock.unlock() }
        guard let bearer = request.value(forHTTPHeaderField: "Authorization") else { return nil }
        return servers[bearer]
    }
}

private final class BookLibraryMutationProtocol: URLProtocol, @unchecked Sendable {
    private var responseTask: Task<Void, Never>?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        responseTask = Task { [self] in
            do {
                guard let server = LibraryMutationProtocolRegistry.server(for: request), let url = request.url,
                    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]) else { throw URLError(.badURL) }
                let data = try await server.response(for: request)
                try Task.checkCancellation()
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() { responseTask?.cancel() }
}
