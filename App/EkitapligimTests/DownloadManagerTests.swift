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
}
