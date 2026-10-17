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
        let metrics = BoundedAudioMetricsLog()
        let (data, response) = try await transport(metrics: metrics).data(for: request(), range: 2...9)
        XCTAssertEqual(response.statusCode, 206)
        XCTAssertEqual(data, Data([2, 3, 4, 5]))
        XCTAssertEqual(log.bytesSent, 4)
        let snapshot = try XCTUnwrap(metrics.latest)
        XCTAssertTrue(snapshot.bodyHeadersAccepted)
        XCTAssertEqual(snapshot.expectedBodyBytes, 4)
        XCTAssertEqual(snapshot.maximumBufferedBytes, 4)
        XCTAssertEqual(snapshot.bufferedBytesAtFinish, 4)
        XCTAssertEqual(metrics.count, 1)
    }

    func testExactly512KiBIsAcceptedWithoutReducingTheAllowedRangeBudget() async throws {
        let length = Int(AudioRangePolicy.chunkSize)
        let log = BoundedAudioLog(), metrics = BoundedAudioMetricsLog()
        BoundedAudioProtocol.plan = .init(status: 206,
            headers: ["Content-Range": "bytes 0-\(length - 1)/\(length)", "Content-Length": String(length)],
            chunks: [Data(repeating: 42, count: length / 4)], repeatChunks: 4, bodyDelay: 0, log: log)
        let (data, response) = try await transport(metrics: metrics).data(for: request(), range: 0...(AudioRangePolicy.chunkSize - 1))
        XCTAssertEqual(response.statusCode, 206)
        XCTAssertEqual(data.count, length)
        XCTAssertEqual(data.first, 42)
        XCTAssertEqual(data.last, 42)
        XCTAssertEqual(log.bytesSent, length)
        let snapshot = try XCTUnwrap(metrics.latest)
        XCTAssertEqual(snapshot.maximumBufferedBytes, length)
        XCTAssertEqual(snapshot.bufferedBytesAtFinish, length)
        XCTAssertEqual(snapshot.expectedBodyBytes, length)
    }

    func testIgnoredRange200IsCancelledAtHeadersBeforeAnUnboundedWholeBookBody() async throws {
        let stopped = expectation(description: "Whole-book producer was cancelled")
        let log = BoundedAudioLog(onStop: { stopped.fulfill() }), metrics = BoundedAudioMetricsLog()
        // URLProtocol can enqueue upstream bytes before Darwin processes the response disposition.
        // Assert that the application's Data buffer accepts none and that the producer is stopped.
        BoundedAudioProtocol.plan = .init(status: 200, headers: ["Content-Length": "536870912", "Content-Type": "audio/mpeg"], chunks: [Data(repeating: 7, count: 16_384)], repeatChunks: 32_768, bodyDelay: 0, log: log)
        await assertInvalidRange(range: 0...3, metrics: metrics)
        assertNoBodyAccepted(metrics)
        await fulfillment(of: [stopped], timeout: 5)
        XCTAssertLessThan(log.bytesSent, 536_870_912)
    }

    func testDeclaredLengthLargerThanRequestedRangeIsRejectedBeforeBody() async throws {
        let log = BoundedAudioLog(), metrics = BoundedAudioMetricsLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 0-3/10000000", "Content-Length": "10000000"], chunks: [Data(repeating: 1, count: 64)], bodyDelay: 0, log: log)
        await assertInvalidRange(range: 0...3, metrics: metrics)
        assertNoBodyAccepted(metrics)
    }

    func testWrongContentRangeIsRejectedAtHeadersWithoutReadingBody() async throws {
        for header in ["bytes 1-4/10", "bytes -0-3/10", "bytes 0-3/*", "bytes 0-9/10", "bytes 0-3/0"] {
            let log = BoundedAudioLog(), metrics = BoundedAudioMetricsLog()
            BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": header], chunks: [Data(repeating: 1, count: 64)], bodyDelay: 0, log: log)
            await assertInvalidRange(range: 0...3, metrics: metrics)
            assertNoBodyAccepted(metrics)
        }
    }

    func testActualBodyOverflowWithoutContentLengthCancelsBeforeRemainingChunks() async throws {
        let stopped = expectation(description: "Overflowing producer was cancelled")
        let log = BoundedAudioLog(onStop: { stopped.fulfill() }), metrics = BoundedAudioMetricsLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 0-3/10000"], chunks: [Data([1, 2, 3]), Data([4, 5]), Data(repeating: 9, count: 4096)], repeatChunks: 10_000, bodyDelay: 0, log: log)
        await assertInvalidRange(range: 0...3, metrics: metrics)
        let snapshot = try XCTUnwrap(metrics.latest)
        XCTAssertTrue(snapshot.bodyHeadersAccepted)
        XCTAssertEqual(snapshot.expectedBodyBytes, 4)
        // Darwin may coalesce queued chunks: an oversized first delivery is rejected with a zero peak.
        XCTAssertLessThanOrEqual(snapshot.maximumBufferedBytes, 4)
        XCTAssertLessThanOrEqual(snapshot.bufferedBytesAtFinish, 4)
        await fulfillment(of: [stopped], timeout: 5)
        XCTAssertLessThan(log.bytesSent, 41_010_000)
    }

    func testPrematureEndDoesNotReturnTruncatedAudioAsSuccess() async throws {
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 0-3/10"], chunks: [Data([1, 2, 3])], log: .init())
        await assertInvalidRange(range: 0...3)
    }

    func testMetadataHeadReturnsHeadersAndNeverReadsBody() async throws {
        let log = BoundedAudioLog(), metrics = BoundedAudioMetricsLog()
        BoundedAudioProtocol.plan = .init(status: 200, headers: ["Content-Length": "536870912", "Content-Type": "audio/mpeg", "Accept-Ranges": "bytes"], chunks: [Data(repeating: 7, count: 16_384)], repeatChunks: 32_768, bodyDelay: 0, log: log)
        var request = try request(); request.httpMethod = "HEAD"
        let (data, response) = try await transport(metrics: metrics).data(for: request, range: nil)
        XCTAssertEqual(data.count, 0)
        XCTAssertEqual(try AudioMediaMetadata(response: response).length, 536_870_912)
        assertNoBodyAccepted(metrics)
    }

    func testAuthenticationAndRedirectStatusesRemainAvailableToRepositoryWithoutBodies() async throws {
        for status in [401, 403, 409, 302] {
            let log = BoundedAudioLog(), metrics = BoundedAudioMetricsLog()
            BoundedAudioProtocol.plan = .init(status: status, headers: ["Content-Length": "10000000"], chunks: [Data(repeating: 7, count: 16_384)], repeatChunks: 100, bodyDelay: 0, log: log)
            let (data, response) = try await transport(metrics: metrics).data(for: request(), range: 0...3)
            XCTAssertEqual(response.statusCode, status)
            XCTAssertTrue(data.isEmpty)
            assertNoBodyAccepted(metrics)
        }
    }

    func testCancellationReleasesPendingRequestAndDoesNotResumeTwice() async throws {
        let started = expectation(description: "Origin received range request")
        let stopped = expectation(description: "Stalled producer was cancelled")
        let log = BoundedAudioLog(onStop: { stopped.fulfill() }), metrics = BoundedAudioMetricsLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: ["Content-Range": "bytes 0-3/10"], chunks: [Data([1, 2, 3, 4])], bodyDelay: 30_000_000_000, log: log, onStart: { started.fulfill() })
        let transport = transport(metrics: metrics), request = try request()
        let job = Task { try await transport.data(for: request, range: 0...3) }
        await fulfillment(of: [started], timeout: 2)
        job.cancel()
        do { _ = try await job.value; XCTFail("Cancelled media request succeeded") }
        catch { XCTAssertTrue(error is CancellationError) }
        await fulfillment(of: [stopped], timeout: 5)
        XCTAssertEqual(log.bytesSent, 0)
        let snapshot = try XCTUnwrap(metrics.latest)
        XCTAssertEqual(snapshot.maximumBufferedBytes, 0)
        XCTAssertEqual(snapshot.bufferedBytesAtFinish, 0)
        XCTAssertEqual(metrics.count, 1)
    }

    func testMoreThan512KiBNeverStartsNetwork() async throws {
        let log = BoundedAudioLog()
        BoundedAudioProtocol.plan = .init(status: 206, headers: [:], chunks: [], log: log)
        await assertInvalidRange(range: 0...AudioRangePolicy.chunkSize)
        XCTAssertEqual(log.started, 0)
    }

    private func assertInvalidRange(range: ClosedRange<Int64>, metrics: BoundedAudioMetricsLog? = nil, file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await transport(metrics: metrics).data(for: request(), range: range); XCTFail("Invalid range succeeded", file: file, line: line) }
        catch { XCTAssertEqual(error as? AudioError, .invalidRange, file: file, line: line) }
    }
    private func assertNoBodyAccepted(_ metrics: BoundedAudioMetricsLog, file: StaticString = #filePath, line: UInt = #line) {
        guard let snapshot = metrics.latest else { XCTFail("Missing terminal transfer metrics", file: file, line: line); return }
        XCTAssertFalse(snapshot.bodyHeadersAccepted, file: file, line: line)
        XCTAssertEqual(snapshot.expectedBodyBytes, 0, file: file, line: line)
        XCTAssertEqual(snapshot.maximumBufferedBytes, 0, file: file, line: line)
        XCTAssertEqual(snapshot.bufferedBytesAtFinish, 0, file: file, line: line)
        XCTAssertEqual(metrics.count, 1, file: file, line: line)
    }
    private func transport(metrics: BoundedAudioMetricsLog? = nil) -> AudioBoundedMediaTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BoundedAudioProtocol.self]
        return AudioBoundedMediaTransport(configuration: configuration, onTransferFinished: { metrics?.record($0) })
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
private final class BoundedAudioMetricsLog: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [AudioMediaTransferMetrics] = []
    var latest: AudioMediaTransferMetrics? { lock.lock(); defer { lock.unlock() }; return snapshots.last }
    var count: Int { lock.lock(); defer { lock.unlock() }; return snapshots.count }
    func record(_ value: AudioMediaTransferMetrics) { lock.lock(); snapshots.append(value); lock.unlock() }
}
private final class BoundedAudioLog: @unchecked Sendable {
    private let lock = NSLock()
    private let onStop: (@Sendable () -> Void)?
    private var bytes = 0
    private var requests = 0
    private var stopped = false
    init(onStop: (@Sendable () -> Void)? = nil) { self.onStop = onStop }
    var bytesSent: Int { lock.lock(); defer { lock.unlock() }; return bytes }
    var started: Int { lock.lock(); defer { lock.unlock() }; return requests }
    func add(_ count: Int) { lock.lock(); bytes += count; lock.unlock() }
    func begin() { lock.lock(); requests += 1; lock.unlock() }
    func stop() {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
        lock.unlock()
        onStop?()
    }
}
private final class BoundedAudioProtocol: URLProtocol, @unchecked Sendable {
    static var plan: BoundedAudioPlan?
    private let stateLock = NSLock()
    private var job: Task<Void, Never>?
    private var stopped = false
    private var activeLog: BoundedAudioLog?
    private var isStopped: Bool { stateLock.lock(); defer { stateLock.unlock() }; return stopped }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let plan = Self.plan, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: plan.status, httpVersion: nil, headerFields: plan.headers) else {
            client?.urlProtocol(self, didFailWithError: AudioError.invalidResponse); return
        }
        stateLock.lock()
        guard !stopped else { stateLock.unlock(); return }
        activeLog = plan.log
        stateLock.unlock()
        plan.log.begin(); plan.onStart?()
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let job = Task { [self] in
            do {
                try await Task.sleep(nanoseconds: plan.bodyDelay)
                for _ in 0..<plan.repeatChunks {
                    for chunk in plan.chunks {
                        try Task.checkCancellation()
                        guard !isStopped else { return }
                        plan.log.add(chunk.count)
                        client?.urlProtocol(self, didLoad: chunk)
                        try await Task.sleep(nanoseconds: 5_000_000)
                    }
                }
                if !isStopped { client?.urlProtocolDidFinishLoading(self) }
            } catch { /* URLSession cancellation owns completion; no extra callback after stopLoading. */ }
        }
        stateLock.lock()
        self.job = job
        let cancelImmediately = stopped
        stateLock.unlock()
        if cancelImmediately { job.cancel() }
    }
    override func stopLoading() {
        stateLock.lock()
        stopped = true
        let job = self.job, log = activeLog
        stateLock.unlock()
        job?.cancel()
        log?.stop()
    }
}
