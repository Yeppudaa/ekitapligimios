import XCTest
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
