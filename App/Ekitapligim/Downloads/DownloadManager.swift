import Foundation
import UIKit
import EkitapligimCore

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var states: [String: DownloadState] = [:]
    @Published private(set) var transferProgress: [String: BookTransferProgress] = [:]

    private let transfer: any BookFileTransferring
    private var operations: [String: (id: UUID, task: Task<Void, Error>)] = [:]
    private let fileManager: FileManager
    private let baseDirectory: URL?

    init(
        session: URLSession? = nil,
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        transfer: (any BookFileTransferring)? = nil
    ) {
        self.transfer = transfer ?? ValidatedBookFileTransfer(session: session, fileManager: fileManager)
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    func localURL(for bookID: String, fileExtension: String = "pdf") throws -> URL {
        let directory = try downloadsDirectory()
        let fileName = try DownloadFilePolicy.fileName(bookID: bookID, fileExtension: fileExtension)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    func restoreDownloads() {
        var restoredStates: [String: DownloadState] = [:]
        guard let directory = try? downloadsDirectory(),
              let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            states = restoredStates
            return
        }
        for fileExtension in ["pdf", "epub"] {
            for url in contents where url.pathExtension.lowercased() == fileExtension {
                let prefix = "book-"
                let fileName = url.deletingPathExtension().lastPathComponent
                guard fileName.hasPrefix(prefix) else { continue }
                let bookID = String(fileName.dropFirst(prefix.count))
                guard (try? DownloadFilePolicy.fileName(bookID: bookID, fileExtension: fileExtension)) == url.lastPathComponent else {
                    continue
                }
                guard isValidLocalFile(at: url, fileType: fileExtension) else {
                    try? fileManager.removeItem(at: url)
                    continue
                }
                restoredStates[bookID] = .downloaded(localFileName: url.lastPathComponent)
            }
        }
        for bookID in operations.keys { restoredStates[bookID] = states[bookID] }
        states = restoredStates
    }

    func localFile(for bookID: String) -> (url: URL, fileType: String)? {
        for fileType in ["pdf", "epub"] {
            guard let url = try? localURL(for: bookID, fileExtension: fileType),
                  fileManager.fileExists(atPath: url.path) else { continue }
            if isValidLocalFile(at: url, fileType: fileType) {
                return (url, fileType)
            }
            try? fileManager.removeItem(at: url)
        }
        return nil
    }

    func download(bookID: String, sourceURL: URL, expectedFileType: String = "pdf") async {
        guard operations[bookID] == nil else { return }
        // A failed second request must never remove a previously validated offline copy.
        if let local = localFile(for: bookID) {
            states[bookID] = .downloaded(localFileName: local.url.lastPathComponent)
            return
        }
        guard sourceURL.scheme?.lowercased() == "https" else {
            states[bookID] = .failed(message: L10n.downloadSecureConnectionRequired)
            return
        }
        states[bookID] = .downloading(progress: 0)
        let operationID = UUID()
        var stagingDirectory: URL?
        defer {
            if let stagingDirectory { try? fileManager.removeItem(at: stagingDirectory) }
            if operations[bookID]?.id == operationID {
                operations[bookID] = nil
                transferProgress[bookID] = nil
            }
        }
        do {
            let fileExtension = DownloadFilePolicy.resolvedFileExtension(for: expectedFileType)
            let fileName = try DownloadFilePolicy.fileName(bookID: bookID, fileExtension: fileExtension)
            let directory = try downloadsDirectory().appendingPathComponent(".pending-\(operationID.uuidString)", isDirectory: true)
            stagingDirectory = directory
            let stagingURL = directory.appendingPathComponent(fileName)
            let task = Task { [transfer] in
                try await transfer.download(from: sourceURL, fileType: fileExtension, to: stagingURL) { [weak self] phase in
                    guard let self, self.operations[bookID]?.id == operationID, let progress = phase.transfer else { return }
                    self.transferProgress[bookID] = progress
                    self.states[bookID] = .downloading(progress: progress.fraction ?? 0)
                }
            }
            operations[bookID] = (operationID, task)
            try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            guard operations[bookID]?.id == operationID else { return }
            try Task.checkCancellation()
            let resolvedType = DownloadFilePolicy.sniffedFileExtension(at: stagingURL) ?? fileExtension
            try transfer.validateFile(at: stagingURL, fileType: resolvedType)
            try protectDownloadedFile(stagingURL)
            let storedURL = try localURL(for: bookID, fileExtension: resolvedType)
            if fileManager.fileExists(atPath: storedURL.path) { try fileManager.removeItem(at: storedURL) }
            try fileManager.moveItem(at: stagingURL, to: storedURL)
            states[bookID] = .downloaded(localFileName: storedURL.lastPathComponent)
        } catch {
            guard operations[bookID]?.id == operationID || stagingDirectory == nil else { return }
            if error is CancellationError || Task.isCancelled { states[bookID] = nil; return }
            states[bookID] = .failed(message: (error as? BookFileTransferError)?.readerMessage ?? L10n.downloadValidationFailed)
        }
    }

    func remove(bookID: String, fileExtension: String = "pdf") async {
        operations.removeValue(forKey: bookID)?.task.cancel()
        transferProgress[bookID] = nil
        do {
            let url = try localURL(for: bookID, fileExtension: fileExtension)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            states[bookID] = nil
        } catch {
            states[bookID] = .failed(message: L10n.downloadRemovalFailed)
        }
    }

    func removeAllDownloads() {
        for operation in operations.values { operation.task.cancel() }
        operations.removeAll()
        transferProgress.removeAll()
        do {
            let directory = try downloadsDirectory()
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
            states.removeAll()
        } catch {
            states.removeAll()
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
        try transfer.validateFile(at: url, fileType: fileExtension)
    }

    private func isValidLocalFile(at url: URL, fileType: String) -> Bool {
        (try? validateDownloadedFile(at: url, fileExtension: fileType)) != nil
    }
}
