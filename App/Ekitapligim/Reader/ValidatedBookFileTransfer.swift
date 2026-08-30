import Foundation
import EkitapligimCore

enum BookFileTransferError: Error {
    case insecureSource
    case serverRejected
    case invalidFile
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
        }
    }
}

@MainActor
final class ValidatedBookFileTransfer {
    private let session: URLSession
    private let fileManager: FileManager
    private let tokenProvider: AccessTokenProviding?
    private let apiBaseURL: URL?

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        tokenProvider: AccessTokenProviding? = nil,
        apiBaseURL: URL? = nil
    ) {
        self.session = session
        self.fileManager = fileManager
        self.tokenProvider = tokenProvider
        self.apiBaseURL = apiBaseURL
    }

    func download(from sourceURL: URL, fileType: String, to destinationURL: URL) async throws {
        let fileExtension = try DownloadFilePolicy.fileExtension(for: fileType)
        guard let firstURL = ReaderSourcePolicy.downloadableURL(from: sourceURL) else {
            throw BookFileTransferError.insecureSource
        }

        var attemptedURLs = Set<URL>()
        var requestURL = firstURL
        while attemptedURLs.insert(requestURL).inserted {
            let (temporaryURL, response) = try await session.download(
                for: await request(for: requestURL, fileExtension: fileExtension)
            )
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw BookFileTransferError.serverRejected
            }

            do {
                try validateFile(at: temporaryURL, fileType: fileExtension)
                try installFile(from: temporaryURL, to: destinationURL)
                return
            } catch {
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
        }
        throw BookFileTransferError.invalidFile
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
