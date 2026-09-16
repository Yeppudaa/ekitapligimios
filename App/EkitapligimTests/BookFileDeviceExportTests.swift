import XCTest
@testable import Ekitapligim

final class BookFileDeviceExportTests: XCTestCase {
    private var temporaryDirectory: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testSanitizedPDFFileNameUsesBookTitle() {
        XCTAssertEqual(
            BookFileDeviceExport.sanitizedFileName(title: "Sefiller", bookID: "42", fileExtension: "pdf"),
            "Sefiller.pdf"
        )
    }

    func testSanitizedEPUBFileNameUsesBookTitle() {
        XCTAssertEqual(
            BookFileDeviceExport.sanitizedFileName(title: "Tutunamayanlar", bookID: "7", fileExtension: "epub"),
            "Tutunamayanlar.epub"
        )
    }

    func testSanitizedFileNameStripsPathTraversal() {
        let name = BookFileDeviceExport.sanitizedFileName(
            title: "../../Library/secret",
            bookID: "42",
            fileExtension: "pdf"
        )
        XCTAssertEqual(name, "Library-secret.pdf")
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains("\\"))
        XCTAssertFalse(name.contains(":"))
    }

    func testEmptyTitleFallsBackToBookIdentifier() {
        XCTAssertEqual(
            BookFileDeviceExport.sanitizedFileName(title: "   ", bookID: "42", fileExtension: "pdf"),
            "book-42.pdf"
        )
    }

    func testEmptyTitleAndEmptyBookIDFallsBackToKitap() {
        XCTAssertEqual(
            BookFileDeviceExport.sanitizedFileName(title: "", bookID: "", fileExtension: "epub"),
            "kitap.epub"
        )
    }

    func testColonInTitleIsRemovedFromFileName() {
        XCTAssertEqual(
            BookFileDeviceExport.sanitizedFileName(title: "Kitap: Cilt 1", bookID: "9", fileExtension: "pdf"),
            "Kitap-Cilt 1.pdf"
        )
    }

    func testMakeExportCopyLeavesSourceFileInPlace() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let source = base.appendingPathComponent("book-42.pdf")
        let payload = Data("%PDF-1.7".utf8)
        try payload.write(to: source)

        let copy = try BookFileDeviceExport.makeExportCopy(
            from: source,
            title: "Sefiller",
            bookID: "42",
            fileExtension: "pdf"
        )

        XCTAssertEqual(copy.lastPathComponent, "Sefiller.pdf")
        XCTAssertTrue(copy.path.contains("BookFileExports"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.path))
        XCTAssertEqual(try Data(contentsOf: copy), payload)
        XCTAssertEqual(try Data(contentsOf: source), payload)
        XCTAssertNotEqual(source.path, copy.path)
        XCTAssertNotEqual(source.deletingLastPathComponent().path, copy.deletingLastPathComponent().path)

        BookFileDeviceExport.removeExportCopy(copy)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path))
        XCTAssertEqual(try Data(contentsOf: source), payload)
    }

    func testMakeExportCopyLeavesEPUBSourceFileInPlace() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let source = base.appendingPathComponent("book-7.epub")
        let payload = Data([0x50, 0x4B, 0x03, 0x04, 0x00])
        try payload.write(to: source)

        let copy = try BookFileDeviceExport.makeExportCopy(
            from: source,
            title: "Tutunamayanlar",
            bookID: "7",
            fileExtension: "epub"
        )

        XCTAssertEqual(copy.lastPathComponent, "Tutunamayanlar.epub")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertNotEqual(source.deletingLastPathComponent().path, copy.deletingLastPathComponent().path)
        XCTAssertEqual(try Data(contentsOf: copy), payload)

        BookFileDeviceExport.removeExportCopy(copy)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path))
    }

    func testRemoveExportCopyDoesNotDeleteSourceDirectory() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectory = base
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let source = base.appendingPathComponent("book-42.pdf")
        try Data("%PDF-1.7".utf8).write(to: source)

        BookFileDeviceExport.removeExportCopy(source)

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.path))
    }

    func testMissingSourceThrowsWithoutCreatingCopy() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        XCTAssertThrowsError(
            try BookFileDeviceExport.makeExportCopy(
                from: missing,
                title: "Sefiller",
                bookID: "42",
                fileExtension: "pdf"
            )
        ) { error in
            XCTAssertEqual(error as? BookFileDeviceExportError, .sourceMissing)
        }
    }
}
