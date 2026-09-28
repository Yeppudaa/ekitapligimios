import Foundation
import EkitapligimCore

enum BookFileTransferError: Error {
    case insecureSource
    case serverRejected
    case invalidFile
    case insufficientStorage
}

extension BookFileTransferError {
    var readerMessage: String {
        switch self {
        case .insecureSource:
            return L10n.readerAtsLinkMissing
        case .serverRejected:
            return L10n.downloadServerRejected
        case .invalidFile:
            return L10n.downloadValidationFailed
        case .insufficientStorage:
            return ReaderL10n.text("error.storage")
        }
    }
}

@MainActor
protocol BookFileTransferring {
    func download(from sourceURL: URL, fileType: String, to destinationURL: URL,
                  onProgress: @escaping @MainActor @Sendable (ReaderLoadingPhase) -> Void) async throws
    func validateFile(at url: URL, fileType: String) throws
}

@MainActor
final class ValidatedBookFileTransfer: BookFileTransferring {
    private let session: URLSession
    private let fileManager: FileManager
    private let tokenProvider: AccessTokenProviding?
    private let apiBaseURL: URL?

    init(
        session: URLSession? = nil,
        fileManager: FileManager = .default,
        tokenProvider: AccessTokenProviding? = nil,
        apiBaseURL: URL? = nil
    ) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 30 * 60
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        self.session = session ?? URLSession(configuration: configuration)
        self.fileManager = fileManager
        self.tokenProvider = tokenProvider
        self.apiBaseURL = apiBaseURL
    }

    func download(from sourceURL: URL, fileType: String, to destinationURL: URL,
                  onProgress: @escaping @MainActor @Sendable (ReaderLoadingPhase) -> Void = { _ in }) async throws {
        let fileExtension = try DownloadFilePolicy.fileExtension(for: fileType)
        guard let firstURL = ReaderSourcePolicy.downloadableURL(from: sourceURL) else {
            throw BookFileTransferError.insecureSource
        }

        var attemptedURLs = Set<URL>()
        var requestURL = firstURL
        // HTML/JSON responses can point at another download. Bound the whole chain,
        // including distinct URLs, so a server cannot keep the reader loading forever.
        while attemptedURLs.count < 4, attemptedURLs.insert(requestURL).inserted {
            try Task.checkCancellation()
            onProgress(.downloading(BookTransferProgress(receivedBytes: 0, expectedBytes: 0)))
            let progressDelivery = BookDownloadProgressDelivery(onProgress: onProgress)
            let delegate = BookDownloadProgressDelegate(apiBaseURL: apiBaseURL, progressDelivery: progressDelivery)
            let temporaryURL: URL
            let response: URLResponse
            do {
                (temporaryURL, response) = try await session.download(
                    for: await request(for: requestURL, fileExtension: fileExtension), delegate: delegate
                )
            } catch {
                progressDelivery.finish()
                if Self.isOutOfSpace(error) { throw BookFileTransferError.insufficientStorage }
                throw error
            }
            // Pending delegate callbacks must not overwrite validation/opening UI.
            progressDelivery.finish()
            defer { try? fileManager.removeItem(at: temporaryURL) }
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw BookFileTransferError.serverRejected
            }

            do {
                onProgress(.validating)
                try await unwrapJSONEnvelopeIfNeeded(at: temporaryURL)
                try Task.checkCancellation()
                try validateFile(at: temporaryURL, fileType: fileExtension)
            } catch {
                if error is CancellationError { throw error }
                if Self.isOutOfSpace(error) { throw BookFileTransferError.insufficientStorage }
                if let redirectURL = Self.jsonSourceURL(at: temporaryURL),
                   !attemptedURLs.contains(redirectURL) {
                    requestURL = redirectURL
                    continue
                }
                if let confirmURL = ReaderSourcePolicy.googleDriveConfirmURL(fromHTMLData: filePrefix(temporaryURL)),
                   !attemptedURLs.contains(confirmURL) {
                    requestURL = confirmURL
                    continue
                }
                let finalURL = http.url ?? requestURL
                if let directURL = ReaderSourcePolicy.downloadableURL(from: finalURL),
                   directURL != requestURL,
                   !attemptedURLs.contains(directURL) {
                    requestURL = directURL
                    continue
                }
                throw BookFileTransferError.invalidFile
            }
            // Installation failures (disk full/permissions) are not corrupt-book errors.
            do { try installFile(from: temporaryURL, to: destinationURL) }
            catch {
                if Self.isOutOfSpace(error) { throw BookFileTransferError.insufficientStorage }
                throw error
            }
            return
        }
        throw BookFileTransferError.invalidFile
    }

    /// The Android reader also accepts a small JSON response pointing to the real file.
    /// Never load a base64 book envelope into memory just to inspect a possible redirect.
    static func jsonSourceURL(at url: URL) -> URL? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 65_537), data.count <= 65_536,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let containers = [object, object["innerContent"] as? [String: Any]].compactMap { $0 }
        for container in containers {
            for key in ["source_url", "sourceUrl", "url"] {
                if let value = container[key] as? String,
                   let source = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
                   let secureURL = ReaderSourcePolicy.downloadableURL(from: source) {
                    return secureURL
                }
            }
        }
        return nil
    }

    static func isOutOfSpace(_ error: Error) -> Bool {
        var current = error as NSError
        for _ in 0..<8 {
            if current.domain == NSCocoaErrorDomain, current.code == NSFileWriteOutOfSpaceError { return true }
            // URLSession may wrap the POSIX ENOSPC error when its temporary file fills the disk.
            if current.domain == NSPOSIXErrorDomain, current.code == 28 { return true }
            guard let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError else { return false }
            current = underlying
        }
        return false
    }

    func validateFile(at url: URL, fileType: String) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 1_024) ?? Data()
        if DownloadFilePolicy.sniffedFileExtension(fromHeader: header) != nil {
            return
        }
        try DownloadFilePolicy.validateHeader(header, fileExtension: fileType)
    }

    private func request(for url: URL, fileExtension: String) async -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 180
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue(
            fileExtension == "epub" ? "application/epub+zip, application/octet-stream" : "application/pdf, application/octet-stream",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("Ekitapligim-iOS/1.0", forHTTPHeaderField: "User-Agent")
        if let apiBaseURL, ReaderSourcePolicy.shouldAttachAccessToken(to: url, apiBaseURL: apiBaseURL),
           let token = try? await tokenProvider?.accessToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func unwrapJSONEnvelopeIfNeeded(at url: URL) async throws {
        guard looksLikeJSONObject(filePrefix(url)) else { return }
        let worker = Task.detached(priority: .userInitiated) {
            let decoded = url.appendingPathExtension("decoded")
            defer { try? FileManager.default.removeItem(at: decoded) }
            try BookFileEnvelopeDecoder.decode(source: url, destination: decoded)
            try Task.checkCancellation()
            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: decoded, to: url)
        }
        try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }

    private func looksLikeJSONObject(_ data: Data) -> Bool {
        guard let first = data.first(where: {
            $0 != 0x20 && $0 != 0x09 && $0 != 0x0A && $0 != 0x0D
        }) else { return false }
        return first == 0x7B
    }

    private func filePrefix(_ url: URL) -> Data {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return Data() }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 16_384)) ?? Data()
    }

    private func installFile(from temporaryURL: URL, to destinationURL: URL) throws {
        let directory = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destinationURL.path
        )
    }
}

/// Only the main actor owns presentation state, including the end of a transfer.
@MainActor
final class BookDownloadProgressDelivery {
    private var active = true
    private let onProgress: @MainActor @Sendable (ReaderLoadingPhase) -> Void

    init(onProgress: @escaping @MainActor @Sendable (ReaderLoadingPhase) -> Void) {
        self.onProgress = onProgress
    }

    func receive(_ progress: BookTransferProgress) {
        guard active else { return }
        onProgress(.downloading(progress))
    }

    func finish() { active = false }
}

/// URLSession writes large downloads directly to disk. No full-file Data buffer or timer-based percentage.
private final class BookDownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let apiBaseURL: URL?
    private let progressDelivery: BookDownloadProgressDelivery
    private var lastPercent: Int?
    private var lastBytes: Int64 = 0
    init(apiBaseURL: URL?, progressDelivery: BookDownloadProgressDelivery) {
        self.apiBaseURL = apiBaseURL; self.progressDelivery = progressDelivery
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let value = BookTransferProgress(receivedBytes: totalBytesWritten, expectedBytes: totalBytesExpectedToWrite)
        guard value.percent != lastPercent || totalBytesWritten - lastBytes >= 262_144 else { return }
        lastPercent = value.percent; lastBytes = totalBytesWritten
        Task { @MainActor [progressDelivery] in progressDelivery.receive(value) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, url.scheme?.lowercased() == "https" else { completionHandler(nil); return }
        var safeRequest = request
        if apiBaseURL.map({ ReaderSourcePolicy.shouldAttachAccessToken(to: url, apiBaseURL: $0) }) != true {
            safeRequest.setValue(nil, forHTTPHeaderField: "Authorization")
        }
        safeRequest.setValue(nil, forHTTPHeaderField: "Cookie")
        completionHandler(safeRequest)
    }
}
