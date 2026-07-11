import Foundation
import UIKit
import EkitapligimCore

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var states: [String: DownloadState] = [:]

    private let session: URLSession
    private let fileManager: FileManager
    private let baseDirectory: URL?

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.session = session
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    func localURL(for bookID: String, fileExtension: String = "pdf") throws -> URL {
        let directory = try downloadsDirectory()
        let fileName = try DownloadFilePolicy.fileName(bookID: bookID, fileExtension: fileExtension)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    func download(bookID: String, sourceURL: URL, expectedFileType: String = "pdf") async {
        guard sourceURL.scheme == "https" else {
            states[bookID] = .failed(message: L10n.downloadSecureConnectionRequired)
            return
        }
        states[bookID] = .downloading(progress: 0)
        var destination: URL?
        do {
            let fileExtension = try DownloadFilePolicy.fileExtension(for: expectedFileType)
            let (temporaryURL, response) = try await session.download(from: sourceURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                states[bookID] = .failed(message: L10n.downloadServerRejected)
                return
            }
            try validateDownloadedFile(at: temporaryURL, fileExtension: fileExtension)
            let targetURL = try localURL(for: bookID, fileExtension: fileExtension)
            destination = targetURL
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: targetURL)
            try protectDownloadedFile(targetURL)
            states[bookID] = .downloaded(localFileName: targetURL.lastPathComponent)
        } catch {
            if let destination, fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            states[bookID] = .failed(message: L10n.downloadValidationFailed)
        }
    }

    func remove(bookID: String, fileExtension: String = "pdf") async {
        do {
            let url = try localURL(for: bookID, fileExtension: fileExtension)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            states[bookID] = .notDownloaded
        } catch {
            states[bookID] = .failed(message: L10n.downloadRemovalFailed)
        }
    }

    private func downloadsDirectory() throws -> URL {
        let base = try baseDirectory
            ?? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("DownloadedBooks", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(values)
        return directory
    }

    private func protectDownloadedFile(_ url: URL) throws {
        try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private func validateDownloadedFile(at url: URL, fileExtension: String) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 1_024) ?? Data()
        try DownloadFilePolicy.validateHeader(header, fileExtension: fileExtension)
    }
}
