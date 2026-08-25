import Foundation
import EkitapligimCore

enum BookFileTransferError: Error {
    case insecureSource
    case serverRejected
    case invalidFile
}

@MainActor
final class ValidatedBookFileTransfer {
    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    func download(from sourceURL: URL, fileType: String, to destinationURL: URL) async throws {
        let fileExtension = try DownloadFilePolicy.fileExtension(for: fileType)
        guard let firstURL = ReaderSourcePolicy.downloadableURL(from: sourceURL) else {
            throw BookFileTransferError.insecureSource
        }

        var attemptedURLs = Set<URL>()
        var requestURL = firstURL
        while attemptedURLs.insert(requestURL).inserted {
            let (temporaryURL, response) = try await session.download(for: request(for: requestURL, fileExtension: fileExtension))
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw BookFileTransferError.serverRejected
            }

            do {
                try validateFile(at: temporaryURL, fileExtension: fileExtension)
                try installFile(from: temporaryURL, to: destinationURL)
                return
            } catch {
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
        try DownloadFilePolicy.validateHeader(header, fileExtension: fileType)
    }

    private func request(for url: URL, fileExtension: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 90
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            fileExtension == "epub" ? "application/epub+zip, application/octet-stream" : "application/pdf, application/octet-stream",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("Ekitapligim-iOS/1.0", forHTTPHeaderField: "User-Agent")
        return request
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
