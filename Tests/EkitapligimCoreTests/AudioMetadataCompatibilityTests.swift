import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class AudioMetadataCompatibilityTests: XCTestCase {
    override func tearDown() { AudioMetadataStubProtocol.handler = nil; super.tearDown() }
    private func repository(tokens: AudioMetadataTestTokens = .init(), refresh: @escaping @Sendable (String) async throws -> String = { $0 }) throws -> AudioRepository {
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [AudioMetadataStubProtocol.self]
        return try AudioRepository(webBaseURL: XCTUnwrap(URL(string: "https://ekitapligim.com/")), tokens: tokens,
            refresh: refresh, session: URLSession(configuration: configuration))
    }
    func testMissingHeadLengthOrRangeAdvertisementUsesOnlyOneAuthenticatedByte() async throws {
        for omitted in [["Content-Length"], ["Accept-Ranges"], ["Content-Length", "Accept-Ranges"]] {
            let repository = try repository(), log = AudioMetadataRequestLog()
            var headers = ["Content-Length": "12345", "Content-Type": "audio/mpeg", "Accept-Ranges": "bytes"]
            for key in omitted { headers.removeValue(forKey: key) }
            let headHeaders = headers
            AudioMetadataStubProtocol.handler = { request in
                log.add(request)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ms_at_fixture")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Encoding"), "identity")
                XCTAssertNil(request.value(forHTTPHeaderField: "Cookie")); XCTAssertNil(request.value(forHTTPHeaderField: "XF-Api-Key"))
                if request.httpMethod == "HEAD" { return .init(code: 200, data: Data(), headers: headHeaders) }
                XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=0-0")
                return .init(code: 206, data: Data([42]), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 0-0/12345"])
            }
            let metadata = try await repository.mediaMetadata(bookID: 27, chapter: metadataChapter, account: "reader")
            XCTAssertEqual(metadata.length, 12345); XCTAssertTrue(metadata.supportsRanges)
            XCTAssertEqual(log.requests.map(\.httpMethod), ["HEAD", "GET"])
        }
    }
    func testMalformedHeadCannotStartAFallbackProbe() async throws {
        for headers in [["Content-Type": "audio/mpeg", "Content-Length": "bad"],
                        ["Content-Type": "audio/mpeg", "Content-Length": "0"],
                        ["Content-Type": "audio/mpeg", "Accept-Ranges": "none"],
                        ["Content-Type": "audio/mpeg", "Content-Encoding": "br"], ["Content-Type": "text/html"]] {
            let repository = try repository(), log = AudioMetadataRequestLog()
            AudioMetadataStubProtocol.handler = { request in log.add(request); return .init(code: 200, data: Data(), headers: headers) }
            do { _ = try await repository.mediaMetadata(bookID: 27, chapter: metadataChapter, account: "reader"); XCTFail("Malformed HEAD accepted") }
            catch { XCTAssertTrue([AudioError.invalidRange, .invalidResponse].contains(error as? AudioError ?? .invalidInput)) }
            XCTAssertEqual(log.requests.count, 1)
        }
    }
    func testMetadataProbeRejectsIgnoredRangesBadBoundsEncodingAndDifferentRepresentationLength() async throws {
        let invalid: [AudioMetadataStubResponse] = [
            .init(code: 200, data: Data([42]), headers: ["Content-Type": "audio/mpeg", "Content-Length": "12345"]),
            .init(code: 206, data: Data([42]), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 1-1/12345"]),
            .init(code: 206, data: Data([42]), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 0-0/*"]),
            .init(code: 206, data: Data([42, 43]), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 0-0/12345"]),
            .init(code: 206, data: Data(), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 0-0/12345"]),
            .init(code: 206, data: Data([42]), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 0-0/12345", "Content-Encoding": "gzip"]),
            .init(code: 206, data: Data([42]), headers: ["Content-Type": "text/html", "Content-Range": "bytes 0-0/12345"]),
            .init(code: 206, data: Data([42]), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 0-0/99999"])
        ]
        for probe in invalid {
            let repository = try repository(), log = AudioMetadataRequestLog()
            AudioMetadataStubProtocol.handler = { request in
                log.add(request)
                if request.httpMethod == "HEAD" { return .init(code: 200, data: Data(), headers: ["Content-Type": "audio/mpeg", "Content-Length": "12345"]) }
                return probe
            }
            do { _ = try await repository.mediaMetadata(bookID: 27, chapter: metadataChapter, account: "reader"); XCTFail("Invalid metadata probe accepted") }
            catch { XCTAssertTrue([AudioError.invalidRange, .invalidResponse].contains(error as? AudioError ?? .invalidInput)) }
            XCTAssertEqual(log.requests.count, 2)
        }
    }
    func testMetadataProbePreservesPremiumConflictAndRedirectWithoutRetries() async throws {
        for (status, expected) in [(403, AudioError.premiumRequired), (409, .sessionConflict), (302, .server(302))] {
            let repository = try repository(), log = AudioMetadataRequestLog()
            AudioMetadataStubProtocol.handler = { request in
                log.add(request)
                return request.httpMethod == "HEAD" ? .init(code: 200, data: Data(), headers: ["Content-Type": "audio/mpeg"]) : .init(code: status, data: Data(), headers: [:])
            }
            do { _ = try await repository.mediaMetadata(bookID: 27, chapter: metadataChapter, account: "reader"); XCTFail("Denied metadata probe accepted") }
            catch { XCTAssertEqual(error as? AudioError, expected) }
            XCTAssertEqual(log.requests.count, 2)
        }
    }
    func testMetadataProbeRefreshesOnceAndRetriesTheSameOneByteWithCurrentBearer() async throws {
        let tokens = AudioMetadataTestTokens(), log = AudioMetadataRequestLog()
        let repository = try repository(tokens: tokens, refresh: { rejected in
            XCTAssertEqual(rejected, "ms_at_fixture"); await tokens.rotate(); return "ms_at_rotated"
        })
        AudioMetadataStubProtocol.handler = { request in
            log.add(request)
            if request.httpMethod == "HEAD" { return .init(code: 200, data: Data(), headers: ["Content-Type": "audio/mpeg"]) }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=0-0")
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer ms_at_fixture" { return .init(code: 401, data: Data(), headers: [:]) }
            return .init(code: 206, data: Data([42]), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 0-0/12345"])
        }
        let metadata = try await repository.mediaMetadata(bookID: 27, chapter: metadataChapter, account: "reader")
        XCTAssertEqual(metadata.length, 12345); XCTAssertEqual(log.requests.count, 3)
        XCTAssertEqual(log.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer ms_at_rotated")
    }
    func testAccountSwitchDuringMetadataProbeCannotPublishMetadata() async throws {
        let tokens = AudioMetadataTestTokens(), log = AudioMetadataRequestLog(), repository = try repository(tokens: tokens)
        AudioMetadataStubProtocol.handler = { request in
            log.add(request)
            if request.httpMethod == "HEAD" { return .init(code: 200, data: Data(), headers: ["Content-Type": "audio/mpeg"]) }
            await tokens.switchAccount()
            return .init(code: 206, data: Data([42]), headers: ["Content-Type": "audio/mpeg", "Content-Range": "bytes 0-0/12345"])
        }
        do { _ = try await repository.mediaMetadata(bookID: 27, chapter: metadataChapter, account: "reader"); XCTFail("Old account metadata escaped") }
        catch { XCTAssertEqual(error as? AudioError, .accountChanged) }
        XCTAssertEqual(log.requests.count, 2)
    }
    private var metadataChapter: AudioChapterDTO {
        .init(id: 42, title: "Test", duration: 3, url: "https://ekitapligim.com/mobile-api/v1/audio-books/27/stream?chapter_id=42")
    }
}

private actor AudioMetadataTestTokens: SessionTokenManaging {
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
private final class AudioMetadataRequestLog: @unchecked Sendable {
    private let lock = NSLock(); private var values: [URLRequest] = []
    func add(_ request: URLRequest) { lock.lock(); defer { lock.unlock() }; values.append(request) }
    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return values }
}
private struct AudioMetadataStubResponse: Sendable {
    let code: Int; let data: Data; let headers: [String: String]
    static func json(_ text: String, code: Int = 200) -> Self { .init(code: code, data: Data(text.utf8), headers: ["Content-Type": "application/json"]) }
}
private final class AudioMetadataStubProtocol: URLProtocol, @unchecked Sendable {
    static var handler: (@Sendable (URLRequest) async throws -> AudioMetadataStubResponse)?
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
