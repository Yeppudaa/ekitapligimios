import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// No cookies, credentials, disk cache or redirects. Bounds compressed data before image decoding.
final class AgendaImageTransport: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var terminal: Result<Data, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var accepted = false
    private var expectedLength: Int64 = -1

    static func data(for request: URLRequest, configuration: URLSessionConfiguration) async throws -> Data {
        let operation = AgendaImageTransport()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { operation.start(request, configuration, $0) }
        } onCancel: { operation.finish(.failure(CancellationError())) }
    }

    private func start(_ request: URLRequest, _ configuration: URLSessionConfiguration, _ continuation: CheckedContinuation<Data, Error>) {
        lock.lock()
        if let terminal { lock.unlock(); continuation.resume(with: terminal); return }
        let config = configuration.copy() as? URLSessionConfiguration ?? .ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.httpAdditionalHeaders = [:]
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.continuation = continuation
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        self.session = session
        self.task = task
        lock.unlock()
        task.resume()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel); finish(.failure(AgendaMediaError.invalidImage)); return
        }
        guard (200..<300).contains(http.statusCode) else {
            completionHandler(.cancel); finish(.failure(APIClientError.httpStatus(http.statusCode, nil))); return
        }
        guard ["image/jpeg", "image/png", "image/webp", "image/gif", "image/heic", "image/heif"].contains(http.mimeType?.lowercased() ?? ""),
              http.expectedContentLength <= Int64(AgendaMediaPolicy.maximumDownloadBytes) else {
            completionHandler(.cancel); finish(.failure(AgendaMediaError.invalidImage)); return
        }
        lock.lock()
        let active = terminal == nil
        accepted = active
        expectedLength = http.value(forHTTPHeaderField: "Content-Encoding") == nil ? http.expectedContentLength : -1
        lock.unlock()
        completionHandler(active ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard terminal == nil else { lock.unlock(); return }
        guard accepted, data.count <= AgendaMediaPolicy.maximumDownloadBytes - buffer.count else {
            lock.unlock(); finish(.failure(AgendaMediaError.invalidImage)); return
        }
        buffer.append(data)
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let data = buffer
        let valid = accepted && !data.isEmpty && (expectedLength < 0 || Int64(data.count) == expectedLength)
        lock.unlock()
        if let error { finish(.failure(error)) }
        else if valid { finish(.success(data)) }
        else { finish(.failure(AgendaMediaError.invalidImage)) }
    }

    private func finish(_ result: Result<Data, Error>) {
        lock.lock()
        guard terminal == nil else { lock.unlock(); return }
        terminal = result
        let continuation = self.continuation
        let task = self.task
        let session = self.session
        self.continuation = nil
        self.task = nil
        self.session = nil
        buffer = Data()
        lock.unlock()
        task?.cancel()
        session?.invalidateAndCancel()
        continuation?.resume(with: result)
    }
}
