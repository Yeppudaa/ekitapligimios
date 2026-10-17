import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class AudioBoundedMediaTransportTests: XCTestCase {
    override func tearDown() { BoundedAudioProtocol.plan = nil; super.tearDown() }

    func testValidPartialResponseIsCollectedInChunksAndFinalRangeIsClampedToFileLength() async throws {
        let log = BoundedAudioLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 2-5/6", "Content-Length": "4"], chunks: [Data([2, 3]), Data([4, 5])], log: log)
        let (data, response) = try await transport().data(for: request(), range: 2...9)
        XCTAssertEqual(response.statusCode, 206)
        XCTAssertEqual(data, Data([2, 3, 4, 5]))
        XCTAssertEqual(log.bytesSent, 4)
    }

    func testIgnoredRange200IsCancelledAtHeadersBeforeAnUnboundedWholeBookBody() async throws {
        let log = BoundedAudioLog()
        // The fake origin advertises a 512 MiB book; no large Data object is allocated by this test.
        BoundedAudioProtocol.plan = .init(status: 200, headers: ["Content-Length": "536870912", "Content-Type": "audio/mpeg"], chunks: [Data(repeating: 7, count: 16_384)], repeatChunks: 32_768, log: log)
        await assertInvalidRange(range: 0...3)
        XCTAssertEqual(log.bytesSent, 0)
    }

    func testDeclaredLengthLargerThanRequestedRangeIsRejectedBeforeBody() async throws {
        let log = BoundedAudioLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 0-3/10000000", "Content-Length": "10000000"], chunks: [Data(repeating: 1, count: 64)], log: log)
        await assertInvalidRange(range: 0...3)
        XCTAssertEqual(log.bytesSent, 0)
    }

    func testWrongContentRangeIsRejectedAtHeadersWithoutReadingBody() async throws {
        for header in ["bytes 1-4/10", "bytes -0-3/10", "bytes 0-3/*", "bytes 0-9/10", "bytes 0-3/0"] {
            let log = BoundedAudioLog()
            BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": header], chunks: [Data(repeating: 1, count: 64)], log: log)
            await assertInvalidRange(range: 0...3)
            XCTAssertEqual(log.bytesSent, 0, header)
        }
    }

    func testActualBodyOverflowWithoutContentLengthCancelsBeforeRemainingChunks() async throws {
        let log = BoundedAudioLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 0-3/10000"], chunks: [Data([1, 2, 3]), Data([4, 5]), Data(repeating: 9, count: 4096)], repeatChunks: 20, log: log)
        await assertInvalidRange(range: 0...3)
        XCTAssertLessThan(log.bytesSent, 4096)
    }

    func testPrematureEndDoesNotReturnTruncatedAudioAsSuccess() async throws {
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 0-3/10"], chunks: [Data([1, 2, 3])], log: .init())
        await assertInvalidRange(range: 0...3)
    }

    func testMetadataHeadReturnsHeadersAndNeverReadsBody() async throws {
        let log = BoundedAudioLog()
        BoundedAudioProtocol.plan = .init(status: 200, headers: ["Content-Length": "536870912", "Content-Type": "audio/mpeg", "Accept-Ranges": "bytes"], chunks: [Data(repeating: 7, count: 16_384)], repeatChunks: 32_768, log: log)
        var request = try request(); request.httpMethod = "HEAD"
        let (data, response) = try await transport().data(for: request, range: nil)
        XCTAssertEqual(data.count, 0)
        XCTAssertEqual(try AudioMediaMetadata(response: response).length, 536_870_912)
        XCTAssertEqual(log.bytesSent, 0)
    }

    func testAuthenticationAndRedirectStatusesRemainAvailableToRepositoryWithoutBodies() async throws {
        for status in [401, 403, 409, 302] {
            let log = BoundedAudioLog()
            BoundedAudioProtocol.plan = .init(status: status, headers: ["Content-Length": "10000000"], chunks: [Data(repeating: 7, count: 16_384)], repeatChunks: 100, log: log)
            let (data, response) = try await transport().data(for: request(), range: 0...3)
            XCTAssertEqual(response.statusCode, status)
            XCTAssertTrue(data.isEmpty)
            XCTAssertEqual(log.bytesSent, 0)
        }
    }

    func testCancellationReleasesPendingRequestAndDoesNotResumeTwice() async throws {
        let started = expectation(description: "Origin received range request")
        let log = BoundedAudioLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 0-3/10"], chunks: [Data([1, 2, 3, 4])], bodyDelay: 500_000_000, log: log, onStart: { started.fulfill() })
        let transport = transport(), request = try request()
        let job = Task { try await transport.data(for: request, range: 0...3) }
        await fulfillment(of: [started], timeout: 2)
        job.cancel()
        do { _ = try await job.value; XCTFail("Cancelled media request succeeded") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(log.bytesSent, 0)
    }

    func testMoreThan512KiBNeverStartsNetwork() async throws {
        let log = BoundedAudioLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: [:], chunks: [], log: log)
        await assertInvalidRange(range: 0...AudioRangePolicy.chunkSize)
        XCTAssertEqual(log.started, 0)
    }

    private func assertInvalidRange(range: ClosedRange<Int64>, file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await transport().data(for: request(), range: range); XCTFail("Invalid range succeeded", file: file, line: line) }
        catch { XCTAssertEqual(error as? AudioError, .invalidRange, file: file, line: line) }
    }
    private func transport() -> AudioBoundedMediaTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BoundedAudioProtocol.self]
        return AudioBoundedMediaTransport(configuration: configuration)
    }
    private func request() throws -> URLRequest {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://ekitapligim.com/mobile-api/v1/audio-books/27/stream?chapter_id=42")))
        request.httpMethod = "GET"
        request.setValue("Bearer ms_at_fixture", forHTTPHeaderField: "Authorization")
        request.setValue("bytes=0-3", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.httpShouldHandleCookies = false
        return request
    }
}

private struct BoundedAudioPlan: Sendable {
    let status: Int
    let headers: [String: String]
    let chunks: [Data]
    var repeatChunks = 1
    var bodyDelay: UInt64 = 30_000_000
    let log: BoundedAudioLog
    var onStart: (@Sendable () -> Void)? = nil
}
private final class BoundedAudioLog: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = 0
    private var requests = 0
    var bytesSent: Int { lock.lock(); defer { lock.unlock() }; return bytes }
    var started: Int { lock.lock(); defer { lock.unlock() }; return requests }
    func add(_ count: Int) { lock.lock(); bytes += count; lock.unlock() }
    func begin() { lock.lock(); requests += 1; lock.unlock() }
}
private final class BoundedAudioProtocol: URLProtocol, @unchecked Sendable {
    static var plan: BoundedAudioPlan?
    private var job: Task<Void, Never>?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let plan = Self.plan, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: plan.status, httpVersion: nil, headerFields: plan.headers) else {
            client?.urlProtocol(self, didFailWithError: AudioError.invalidResponse); return
        }
        plan.log.begin(); plan.onStart?()
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        job = Task { [self] in
            do {
                try await Task.sleep(nanoseconds: plan.bodyDelay)
                for _ in 0..<plan.repeatChunks {
                    for chunk in plan.chunks {
                        try Task.checkCancellation()
                        plan.log.add(chunk.count)
                        client?.urlProtocol(self, didLoad: chunk)
                        try await Task.sleep(nanoseconds: 5_000_000)
                    }
                }
                client?.urlProtocolDidFinishLoading(self)
            } catch { /* URLSession cancellation owns completion; no extra callback after stopLoading. */ }
        }
    }
    override func stopLoading() { job?.cancel() }
}
