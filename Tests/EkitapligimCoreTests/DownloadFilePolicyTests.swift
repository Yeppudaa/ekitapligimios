import XCTest
@testable import EkitapligimCore

final class DownloadFilePolicyTests: XCTestCase {
    func testCreatesSafePDFFileName() throws {
        XCTAssertEqual(
            try DownloadFilePolicy.fileName(bookID: "123-abc_DEF", fileExtension: "application/pdf"),
            "book-123-abc_DEF.pdf"
        )
    }

    func testRejectsPathTraversalIdentifier() {
        XCTAssertThrowsError(try DownloadFilePolicy.fileName(bookID: "../../private", fileExtension: "pdf"))
    }

    func testRejectsUnsupportedFileType() {
        XCTAssertThrowsError(try DownloadFilePolicy.fileExtension(for: "html"))
    }

    func testAcceptsPDFMarkerWithinFirstKilobyte() throws {
        let data = Data("server-prefix\n%PDF-1.7\n".utf8)
        XCTAssertNoThrow(try DownloadFilePolicy.validateHeader(data, fileExtension: "pdf"))
    }

    func testRejectsHTMLDisguisedAsPDF() {
        let data = Data("<html>login required</html>".utf8)
        XCTAssertThrowsError(try DownloadFilePolicy.validateHeader(data, fileExtension: "pdf"))
    }

    func testAcceptsEPUBZipHeader() {
        let data = Data([0x50, 0x4B, 0x03, 0x04, 0x00])
        XCTAssertNoThrow(try DownloadFilePolicy.validateHeader(data, fileExtension: "epub"))
    }
}
