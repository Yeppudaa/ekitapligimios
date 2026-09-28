import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class DownloadManagerTests: XCTestCase {
    private var temporaryDirectory: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testDownloadDirectoryIsExcludedFromBackup() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        let manager = DownloadManager(baseDirectory: base)

        let fileURL = try manager.localURL(for: "42", fileExtension: "pdf")
        let directory = fileURL.deletingLastPathComponent()
        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])

        XCTAssertEqual(fileURL.lastPathComponent, "book-42.pdf")
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testLocalURLRejectsPathTraversal() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        let manager = DownloadManager(baseDirectory: base)

        XCTAssertThrowsError(try manager.localURL(for: "../../Library", fileExtension: "pdf"))
    }

    func testRestoresValidatedDownloadedBookFromDisk() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        let manager = DownloadManager(baseDirectory: base)
        let localURL = try manager.localURL(for: "42", fileExtension: "epub")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: localURL)

        manager.restoreDownloads()

        XCTAssertEqual(manager.states["42"], .downloaded(localFileName: "book-42.epub"))
        XCTAssertEqual(manager.localFile(for: "42")?.fileType, "epub")
    }

    func testRemovingAllDownloadsClearsFilesAndState() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        let manager = DownloadManager(baseDirectory: base)
        let localURL = try manager.localURL(for: "42", fileExtension: "pdf")
        try Data("%PDF-1.7".utf8).write(to: localURL)
        manager.restoreDownloads()

        manager.removeAllDownloads()

        XCTAssertNil(manager.localFile(for: "42"))
        XCTAssertTrue(manager.states.isEmpty)
    }

    func testLateDownloadAfterClearCannotRecreateOfflineBook() async throws {
        let transfer = SuspendedBookTransfer()
        let manager = makeManager(transfer: transfer)
        let started = expectation(description: "download started")
        transfer.didStart = { started.fulfill() }
        let url = try XCTUnwrap(URL(string: "https://example.invalid/book.pdf"))
        let task = Task { await manager.download(bookID: "42", sourceURL: url) }
        await fulfillment(of: [started], timeout: 2)
        manager.removeAllDownloads()
        transfer.complete()
        await task.value
        XCTAssertNil(manager.localFile(for: "42"))
        XCTAssertTrue(manager.states.isEmpty)
        XCTAssertTrue(manager.transferProgress.isEmpty)
    }

    func testDuplicateDownloadDoesNotStartAnotherTransfer() async throws {
        let transfer = SuspendedBookTransfer()
        let manager = makeManager(transfer: transfer)
        let started = expectation(description: "download started")
        transfer.didStart = { started.fulfill() }
        let url = try XCTUnwrap(URL(string: "https://example.invalid/book.pdf"))
        let task = Task { await manager.download(bookID: "42", sourceURL: url) }
        await fulfillment(of: [started], timeout: 2)
        await manager.download(bookID: "42", sourceURL: url)
        XCTAssertEqual(transfer.requests, 1)
        transfer.complete()
        await task.value
        XCTAssertEqual(manager.states["42"], .downloaded(localFileName: "book-42.pdf"))
    }

    func testExistingValidBookIsPreservedWithoutRedownloading() async throws {
        let transfer = SuspendedBookTransfer()
        let manager = makeManager(transfer: transfer)
        let local = try manager.localURL(for: "42")
        let original = Data("%PDF-1.7 original".utf8)
        try original.write(to: local)
        await manager.download(bookID: "42", sourceURL: try XCTUnwrap(URL(string: "https://example.invalid/book.pdf")))
        XCTAssertEqual(transfer.requests, 0)
        XCTAssertEqual(try Data(contentsOf: local), original)
        XCTAssertEqual(manager.states["42"], .downloaded(localFileName: "book-42.pdf"))
    }

    func testReportsMeasuredProgressAndIgnoresEventsAfterRemoval() async throws {
        let transfer = SuspendedBookTransfer()
        let manager = makeManager(transfer: transfer)
        let started = expectation(description: "download started")
        transfer.didStart = { started.fulfill() }
        let url = try XCTUnwrap(URL(string: "https://example.invalid/book.pdf"))
        let task = Task { await manager.download(bookID: "42", sourceURL: url) }
        await fulfillment(of: [started], timeout: 2)
        transfer.report(25, total: 100)
        XCTAssertEqual(manager.states["42"], .downloading(progress: 0.25))
        await manager.remove(bookID: "42")
        transfer.report(100, total: 100)
        transfer.complete()
        await task.value
        XCTAssertNil(manager.states["42"])
        XCTAssertNil(manager.localFile(for: "42"))
    }

    private func makeManager(transfer: any BookFileTransferring) -> DownloadManager {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        return DownloadManager(baseDirectory: base, transfer: transfer)
    }

    func testRestoreRemovesCorruptDownloadedFile() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        let manager = DownloadManager(baseDirectory: base)
        let localURL = try manager.localURL(for: "42", fileExtension: "pdf")
        try Data("not a PDF".utf8).write(to: localURL)

        manager.restoreDownloads()

        XCTAssertTrue(manager.states.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: localURL.path))
    }
}

@MainActor
private final class SuspendedBookTransfer: BookFileTransferring {
    var requests = 0
    var didStart: (() -> Void)?
    private var continuation: CheckedContinuation<Void, Error>?
    private var progress: (@MainActor @Sendable (ReaderLoadingPhase) -> Void)?
    func download(from sourceURL: URL, fileType: String, to destinationURL: URL,
                  onProgress: @escaping @MainActor @Sendable (ReaderLoadingPhase) -> Void) async throws {
        requests += 1
        progress = onProgress
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            didStart?()
        }
        // Deliberately ignore cancellation to simulate a completion already queued by URLSession.
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("%PDF-1.7 test".utf8).write(to: destinationURL)
    }
    func report(_ bytes: Int64, total: Int64) { progress?(.downloading(BookTransferProgress(receivedBytes: bytes, expectedBytes: total))) }
    func complete() { continuation?.resume(); continuation = nil }
    func validateFile(at url: URL, fileType: String) throws {
        try DownloadFilePolicy.validateHeader(Data(contentsOf: url), fileExtension: fileType)
    }
}
