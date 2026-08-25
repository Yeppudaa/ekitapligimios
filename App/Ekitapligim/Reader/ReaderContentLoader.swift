import Foundation
import EkitapligimCore

@MainActor
final class ReaderContentLoader {
    private let transfer: ValidatedBookFileTransfer
    private let fileManager: FileManager
    private let baseDirectory: URL?

    init(
        transfer: ValidatedBookFileTransfer = ValidatedBookFileTransfer(),
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.transfer = transfer
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    func prepare(bookID: String, sourceURL: URL, fileType: String) async throws -> URL {
        let fileExtension = try DownloadFilePolicy.fileExtension(for: fileType)
        let directory = try sessionDirectory()
        let safeName = try DownloadFilePolicy.fileName(bookID: bookID, fileExtension: fileExtension)
        let targetURL = directory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(safeName, isDirectory: false)
        do {
            try await transfer.download(from: sourceURL, fileType: fileExtension, to: targetURL)
            return targetURL
        } catch {
            try? fileManager.removeItem(at: targetURL.deletingLastPathComponent())
            throw error
        }
    }

    func removePreparedFile(at url: URL?) {
        guard let url, url.isFileURL else { return }
        let sessionRoot = try? sessionDirectory().standardizedFileURL
        let parent = url.deletingLastPathComponent().standardizedFileURL
        guard let sessionRoot, parent.path.hasPrefix(sessionRoot.path + "/") else { return }
        try? fileManager.removeItem(at: parent)
    }

    private func sessionDirectory() throws -> URL {
        let base = try baseDirectory
            ?? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("ReaderSessions", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(values)
        return directory
    }
}
