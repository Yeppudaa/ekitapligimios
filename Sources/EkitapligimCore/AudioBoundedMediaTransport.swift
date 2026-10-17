import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Media is streamed into a bounded buffer. Headers are rejected before any MP3 body is accepted.
/// In particular an origin/proxy ignoring Range cannot turn a 512 KiB read into a whole-book download.
final class AudioBoundedMediaTransport: @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private let onTransferFinished: (@Sendable (AudioMediaTransferMetrics) -> Void)?

    init(configuration: URLSessionConfiguration, onTransferFinished: (@Sendable (AudioMediaTransferMetrics) -> Void)? = nil) {
        let copy = configuration.copy() as? URLSessionConfiguration ?? .ephemeral
        copy.httpCookieStorage = nil
        copy.httpShouldSetCookies = false
        copy.urlCredentialStorage = nil
        copy.urlCache = nil
        self.configuration = copy
        self.onTransferFinished = onTransferFinished
    }

    func data(for request: URLRequest, range: ClosedRange<Int64>?) async throws -> (Data, HTTPURLResponse) {
        if let range {
            guard range.lowerBound >= 0, range.upperBound >= range.lowerBound,
                  range.upperBound - range.lowerBound < AudioRangePolicy.chunkSize else { throw AudioError.invalidRange }
        } else if request.httpMethod != "HEAD" { throw AudioError.invalidInput }
        let operation = AudioBoundedMediaOperation(configuration: configuration, request: request, range: range,
                                                  onTransferFinished: onTransferFinished)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { operation.start($0) }
        } onCancel: { operation.cancel() }
    }
}

/// Content-free diagnostics of the application's own Data buffer, not upstream/socket bytes.
/// URLProtocol may enqueue bytes before URLSession asynchronously processes a header rejection.
/// The optional internal observer is unset by production callers and cannot alter transfer policy.
struct AudioMediaTransferMetrics: Equatable, Sendable {
    let bodyHeadersAccepted: Bool
    let expectedBodyBytes: Int
    let maximumBufferedBytes: Int
    let bufferedBytesAtFinish: Int
}

private final class AudioBoundedMediaOperation: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    typealias Output = (Data, HTTPURLResponse)
    private let lock = NSLock()
    private let configuration: URLSessionConfiguration
    private let request: URLRequest
    private let range: ClosedRange<Int64>?
    private let onTransferFinished: (@Sendable (AudioMediaTransferMetrics) -> Void)?
    private var continuation: CheckedContinuation<Output, Error>?
    private var terminal: Result<Output, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var response: HTTPURLResponse?
    private var buffer = Data()
    private var expectedLength = 0
    private var maximumBufferedBytes = 0

    init(configuration: URLSessionConfiguration, request: URLRequest, range: ClosedRange<Int64>?,
         onTransferFinished: (@Sendable (AudioMediaTransferMetrics) -> Void)?) {
        self.configuration = configuration
        self.request = request
        self.range = range
        self.onTransferFinished = onTransferFinished
    }

    func start(_ continuation: CheckedContinuation<Output, Error>) {
        lock.lock()
        if let terminal {
            lock.unlock()
            continuation.resume(with: terminal)
            return
        }
        self.continuation = continuation
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        self.session = session
        self.task = task
        lock.unlock()
        task.resume()
    }

    func cancel() { finish(.failure(CancellationError())) }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, http.url == request.url else {
            completionHandler(.cancel)
            finish(.failure(AudioError.invalidResponse))
            return
        }
        // Preserve the repository's single refresh and typed status handling without reading error bodies.
        guard (200..<300).contains(http.statusCode) else {
            completionHandler(.cancel)
            finish(.success((Data(), http)))
            return
        }
        do {
            guard let range else {
                _ = try AudioMediaMetadata(response: http)
                completionHandler(.cancel)
                finish(.success((Data(), http)))
                return
            }
            let length = try Self.validatedLength(response: http, range: range)
            lock.lock()
            let active = terminal == nil
            if active { self.response = http; expectedLength = length; buffer.reserveCapacity(length) }
            lock.unlock()
            completionHandler(active ? .allow : .cancel)
        } catch {
            completionHandler(.cancel)
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard terminal == nil else { lock.unlock(); return }
        guard response != nil, expectedLength > 0, data.count <= expectedLength - buffer.count else {
            lock.unlock()
            finish(.failure(AudioError.invalidRange))
            return
        }
        buffer.append(data)
        maximumBufferedBytes = max(maximumBufferedBytes, buffer.count)
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        guard terminal == nil else { lock.unlock(); return }
        let response = self.response
        let data = buffer
        let length = expectedLength
        lock.unlock()
        if let error { finish(.failure(error)); return }
        guard let response, data.count == length else { finish(.failure(AudioError.invalidRange)); return }
        finish(.success((data, response)))
    }

    private func finish(_ result: Result<Output, Error>) {
        lock.lock()
        guard terminal == nil else { lock.unlock(); return }
        terminal = result
        let continuation = self.continuation
        let task = self.task
        let session = self.session
        let metrics = AudioMediaTransferMetrics(bodyHeadersAccepted: response != nil,
            expectedBodyBytes: expectedLength, maximumBufferedBytes: maximumBufferedBytes,
            bufferedBytesAtFinish: buffer.count)
        self.continuation = nil
        self.task = nil
        self.session = nil
        buffer = Data()
        lock.unlock()
        task?.cancel()
        session?.invalidateAndCancel()
        onTransferFinished?(metrics)
        continuation?.resume(with: result)
    }

    private static func validatedLength(response: HTTPURLResponse, range: ClosedRange<Int64>) throws -> Int {
        guard response.statusCode == 206,
              let header = response.value(forHTTPHeaderField: "Content-Range"), header.hasPrefix("bytes ") else { throw AudioError.invalidRange }
        let parts = header.dropFirst(6).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, let total = Int64(parts[1]), total > 0 else { throw AudioError.invalidRange }
        let bounds = parts[0].split(separator: "-", omittingEmptySubsequences: false)
        guard bounds.count == 2, let start = Int64(bounds[0]), let end = Int64(bounds[1]),
              start == range.lowerBound, end == min(range.upperBound, total - 1), end >= start, end < total,
              end - start < AudioRangePolicy.chunkSize else { throw AudioError.invalidRange }
        let length = end - start + 1
        if let declared = response.value(forHTTPHeaderField: "Content-Length") {
            guard Int64(declared.trimmingCharacters(in: .whitespacesAndNewlines)) == length else { throw AudioError.invalidRange }
        }
        if let encoding = response.value(forHTTPHeaderField: "Content-Encoding") {
            guard encoding.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "identity" else { throw AudioError.invalidRange }
        }
        return Int(length)
    }
}
