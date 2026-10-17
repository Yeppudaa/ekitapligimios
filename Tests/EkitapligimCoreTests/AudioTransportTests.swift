import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class AudioTransportTests: XCTestCase {
    override func tearDown() { AudioStubProtocol.handler = nil; super.tearDown() }
    private func repository(tokens: AudioTestTokens = .init(), refresh: @escaping @Sendable (String) async throws -> String = { $0 }) throws -> AudioRepository {
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [AudioStubProtocol.self]
        return try AudioRepository(webBaseURL: XCTUnwrap(URL(string: "https://ekitapligim.com/")), tokens: tokens,
            refresh: refresh, session: URLSession(configuration: configuration))
    }
    func testCatalogIsNativeJSONAndContainsNoCookiesAPIKeysOrImpersonationHeaders() async throws {
        let repository = try repository()
        AudioStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/mobile-api/v1/audio-books")
            XCTAssertEqual(request.httpMethod, "GET"); XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ms_at_fixture")
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie")); XCTAssertNil(request.value(forHTTPHeaderField: "XF-Api-Key")); XCTAssertNil(request.value(forHTTPHeaderField: "XF-Api-User"))
            XCTAssertFalse(request.httpShouldHandleCookies); XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            return .json(AudioFixtures.catalog)
        }
        let catalog = try await repository.catalog(); XCTAssertEqual(catalog.books.count, 1)
    }
    func testGuestCanBrowseButPrivateManifestNeverTouchesNetwork() async throws {
        let repository = try repository(tokens: AudioTestTokens(session: nil)); let log = AudioRequestLog()
        AudioStubProtocol.handler = { request in log.add(request); XCTAssertNil(request.value(forHTTPHeaderField: "Authorization")); return .json(AudioFixtures.catalog) }
        _ = try await repository.catalog()
        do { _ = try await repository.manifest(bookID: 27, account: "reader"); XCTFail("Private request accepted guest") }
        catch { XCTAssertEqual(error as? AudioError, .authenticationRequired) }
        XCTAssertEqual(log.requests.count, 1)
    }
    func testManifestPostUsesExistingAccountBearerAndValidatesEveryStreamBeforePlayback() async throws {
        let repository = try repository()
        AudioStubProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(request.url?.path, "/mobile-api/v1/audio-books/27/manifest")
            XCTAssertEqual(request.audioBody, "resume=0"); return .json(AudioFixtures.manifest)
        }
        let manifest = try await repository.manifest(bookID: 27, account: "reader"); XCTAssertEqual(manifest.chapters[0].id, 42)
        AudioStubProtocol.handler = { _ in .json(AudioFixtures.manifest.replacingOccurrences(of: "https://ekitapligim.com/mobile-api/v1/audio-books/27/stream", with: "https://evil.example/steal")) }
        do { _ = try await repository.manifest(bookID: 27, account: "reader"); XCTFail("Foreign stream accepted") }
        catch { XCTAssertEqual(error as? AudioError, .invalidResponse) }
    }
    func test401RefreshReusesExistingIOSRotationAndRetriesOnlyOnce() async throws {
        let tokens = AudioTestTokens(), log = AudioRequestLog()
        let repository = try repository(tokens: tokens, refresh: { rejected in
            XCTAssertEqual(rejected, "ms_at_fixture"); await tokens.rotate(); return "ms_at_rotated"
        })
        AudioStubProtocol.handler = { request in
            log.add(request); return request.value(forHTTPHeaderField: "Authorization") == "Bearer ms_at_rotated" ? .json(AudioFixtures.manifest) : .json("{}", code: 401)
        }
        _ = try await repository.manifest(bookID: 27, account: "reader")
        XCTAssertEqual(log.requests.count, 2); XCTAssertEqual(log.requests[0].audioBody, log.requests[1].audioBody)
    }
    func testSessionSwitchWhileResponseIsInFlightIsRejected() async throws {
        let tokens = AudioTestTokens(); let repository = try repository(tokens: tokens)
        AudioStubProtocol.handler = { _ in await tokens.switchAccount(); return .json(AudioFixtures.catalog) }
        do { _ = try await repository.catalog(); XCTFail("Old account response escaped") }
        catch { XCTAssertEqual(error as? AudioError, .accountChanged) }
    }
    func testSignInDuringGuestResponseCannotPublishGuestPermissionState() async throws {
        let tokens = AudioTestTokens(session: nil); let repository = try repository(tokens: tokens)
        AudioStubProtocol.handler = { _ in await tokens.rotate(); return .json(AudioFixtures.catalog) }
        do { _ = try await repository.catalog(); XCTFail("Old guest response escaped") }
        catch { XCTAssertEqual(error as? AudioError, .accountChanged) }
    }
    func testSessionSwitchDuringRefreshCannotReplayPrivatePost() async throws {
        let tokens = AudioTestTokens(), log = AudioRequestLog()
        let repository = try repository(tokens: tokens, refresh: { _ in await tokens.switchAccount(); return "ms_at_other" })
        AudioStubProtocol.handler = { request in log.add(request); return .json("{}", code: 401) }
        do { _ = try await repository.manifest(bookID: 27, account: "reader"); XCTFail("Other account replayed") }
        catch { XCTAssertEqual(error as? AudioError, .accountChanged) }
        XCTAssertEqual(log.requests.count, 1)
    }
    func testPremiumConflictUnavailableAndRedirectAreTypedFailuresWithoutRetries() async throws {
        let repository = try repository(); let log = AudioRequestLog()
        for (status, expected) in [(403, AudioError.premiumRequired), (409, .sessionConflict), (503, .unavailable), (302, .server(302))] {
            AudioStubProtocol.handler = { request in log.add(request); return .json("{}", code: status) }
            do { _ = try await repository.manifest(bookID: 27, account: "reader"); XCTFail("Rejected status accepted") }
            catch { XCTAssertEqual(error as? AudioError, expected) }
        }
        XCTAssertEqual(log.requests.count, 4)
    }
    func testShelfAndAnnotationMutationsPreserveExactContractAndTextEncoding() async throws {
        let repository = try repository(), log = AudioRequestLog()
        AudioStubProtocol.handler = { request in
            log.add(request)
            if request.url?.lastPathComponent == "shelf" { return .json(#"{"saved":true}"#) }
            if request.audioBody.contains("delete=") { return .json(#"{"deleted":true}"#) }
            return .json(#"{"bookmark_id":9,"chapter_id":42,"position":12,"label":"Not: Çay + kitap & huzur"}"#)
        }
        try await repository.shelf(bookID: 27, field: .favorite, value: true, account: "reader")
        let bookmark = try await repository.bookmark(bookID: 27, chapterID: 42, position: 12, label: "Not: Çay + kitap & huzur", account: "reader")
        try await repository.deleteBookmark(bookID: 27, bookmarkID: bookmark.id, account: "reader")
        XCTAssertEqual(log.requests[0].audioBody, "field=favorite&value=1")
        XCTAssertTrue(log.requests[1].audioBody.contains("%2B")); XCTAssertTrue(log.requests[1].audioBody.contains("%26"))
        XCTAssertEqual(bookmark.displayText, "Çay + kitap & huzur")
        XCTAssertEqual(log.requests[2].audioBody, "delete=9")
    }
    func testMediaUsesCurrentBearerForEveryRangeWithoutDiskCacheOrRedirectFallback() async throws {
        let tokens = AudioTestTokens(); let repository = try repository(tokens: tokens); let log = AudioRequestLog()
        let chapter = AudioChapterDTO(id: 42, title: "Test", duration: 3, url: "https://ekitapligim.com/mobile-api/v1/audio-books/27/stream?chapter_id=42")
        AudioStubProtocol.handler = { request in
            log.add(request); XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Encoding"), "identity")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store"); XCTAssertFalse(request.httpShouldHandleCookies)
            if request.httpMethod == "HEAD" { return AudioStubResponse(code: 200, data: Data(), headers: ["Content-Length": "6", "Content-Type": "audio/mpeg", "Accept-Ranges": "bytes"]) }
            return AudioStubResponse(code: 206, data: Data([1, 2, 3]), headers: ["Content-Range": "bytes 0-2/6", "Content-Type": "audio/mpeg"])
        }
        _ = try await repository.mediaMetadata(bookID: 27, chapter: chapter, account: "reader")
        await tokens.rotate()
        let bytes = try await repository.mediaData(bookID: 27, chapter: chapter, account: "reader", start: 0, end: 2)
        XCTAssertEqual(bytes, Data([1, 2, 3]))
        XCTAssertEqual(log.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer ms_at_fixture")
        XCTAssertEqual(log.requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer ms_at_rotated")
        XCTAssertEqual(log.requests[1].value(forHTTPHeaderField: "Range"), "bytes=0-2")
    }
    func testRange200NeverAcceptedAsValidSeekAndInvalidIDsDoNotWrite() async throws {
        let repository = try repository(); let log = AudioRequestLog()
        AudioStubProtocol.handler = { request in log.add(request); return AudioStubResponse(code: 200, data: Data([1, 2, 3]), headers: [:]) }
        let chapter = AudioChapterDTO(id: 42, title: "Test", duration: 3, url: "https://ekitapligim.com/mobile-api/v1/audio-books/27/stream?chapter_id=42")
        do { _ = try await repository.mediaData(bookID: 27, chapter: chapter, account: "reader", start: 0, end: 2); XCTFail("Ignored Range accepted") }
        catch { XCTAssertEqual(error as? AudioError, .invalidRange) }
        do { try await repository.shelf(bookID: 0, field: .saved, value: true, account: "reader"); XCTFail("Invalid ID wrote") } catch { XCTAssertEqual(error as? AudioError, .invalidInput) }
        XCTAssertEqual(log.requests.count, 1)
    }
}

private actor AudioTestTokens: SessionTokenManaging {
    var session: Session?
    init(session: Session? = .init(accessToken: "ms_at_fixture", refreshToken: "fixture", username: "reader", userID: "7")) { self.session = session }
    func rotate() { session = Session(accessToken: "ms_at_rotated", refreshToken: "fixture", username: "reader", userID: "7") }
    func switchAccount() { session = Session(accessToken: "ms_at_other", refreshToken: "fixture", username: "other", userID: "8") }
    func accessToken() async throws -> String? { session?.accessToken }
    func loadSession() async throws -> Session? { session }
    func save(session: Session) async throws { self.session = session }
    func clear() async throws { session = nil }
    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool { guard self.session == expected else { return false }; self.session = session; return true }
}
private final class AudioRequestLog: @unchecked Sendable {
    private let lock = NSLock(); private var values: [URLRequest] = []
    func add(_ request: URLRequest) { lock.lock(); defer { lock.unlock() }; values.append(request) }
    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return values }
}
private struct AudioStubResponse: Sendable {
    let code: Int; let data: Data; let headers: [String: String]
    static func json(_ text: String, code: Int = 200) -> Self { .init(code: code, data: Data(text.utf8), headers: ["Content-Type": "application/json"]) }
}
private final class AudioStubProtocol: URLProtocol, @unchecked Sendable {
    static var handler: (@Sendable (URLRequest) async throws -> AudioStubResponse)?
    private var job: Task<Void, Never>?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        job = Task { [self] in
            do {
                guard let handler = Self.handler, let url = request.url else { throw AudioError.invalidResponse }
                let result = try await handler(request); try Task.checkCancellation()
                guard let response = HTTPURLResponse(url: url, statusCode: result.code, httpVersion: nil, headerFields: result.headers) else { throw AudioError.invalidResponse }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: result.data); client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() { job?.cancel() }
}
private extension URLRequest {
    var audioBody: String {
        if let httpBody { return String(data: httpBody, encoding: .utf8) ?? "" }
        guard let stream = httpBodyStream else { return "" }; stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let read = stream.read(&buffer, maxLength: buffer.count); if read <= 0 { break }; data.append(buffer, count: read) }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
