import Foundation
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class ValidatedBookFileTransferTests: XCTestCase {
    private func sourceURL(for object: [String: Any]) throws -> URL? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        return ValidatedBookFileTransfer.jsonSourceURL(at: file)
    }

    func testFollowsHTTPSJSONSourcesLikeAndroidReader() throws {
        let target = "https://books.example.com/read/book.pdf?t=temporary"
        for key in ["source_url", "sourceUrl", "url"] {
            XCTAssertEqual(try sourceURL(for: [key: target])?.absoluteString, target)
        }
        XCTAssertEqual(try sourceURL(for: ["innerContent": ["source_url": target]])?.absoluteString, target)
    }

    func testRejectsInsecureJSONSourcesAndOversizedRedirectBodies() throws {
        XCTAssertNil(try sourceURL(for: ["source_url": "http://books.example.com/book.pdf"]))
        XCTAssertNil(try sourceURL(for: ["source_url": "file:///private/book.pdf"]))
        XCTAssertNil(try sourceURL(for: ["source_url": "https://books.example.com/book.pdf", "metadata": String(repeating: "x", count: 65_537)]))
    }

    func testConvertsDriveShareURLBeforeDownloading() throws {
        let source = try sourceURL(for: ["sourceUrl": "https://drive.google.com/file/d/book42/view"])
        XCTAssertEqual(source?.host, "drive.usercontent.google.com")
        XCTAssertTrue(source?.query?.contains("id=book42") == true)
    }

    func testLateProgressCannotReplaceValidationOrOpening() {
        var phases: [ReaderLoadingPhase] = []
        let delivery = BookDownloadProgressDelivery { phases.append($0) }
        let progress = BookTransferProgress(receivedBytes: 100, expectedBytes: 200)
        delivery.receive(progress)
        delivery.finish()
        phases.append(.validating)
        delivery.receive(BookTransferProgress(receivedBytes: 200, expectedBytes: 200))

        XCTAssertEqual(phases, [.downloading(progress), .validating])
    }

    func testDiskFullIncludesUnderlyingURLSessionPOSIXError() {
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: 28)
        let wrapped = NSError(domain: NSURLErrorDomain, code: -3003, userInfo: [NSUnderlyingErrorKey: underlying])
        XCTAssertTrue(ValidatedBookFileTransfer.isOutOfSpace(wrapped))
        XCTAssertTrue(ValidatedBookFileTransfer.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)))
        XCTAssertFalse(ValidatedBookFileTransfer.isOutOfSpace(NSError(domain: NSURLErrorDomain, code: NSFileWriteOutOfSpaceError)))
        XCTAssertFalse(ValidatedBookFileTransfer.isOutOfSpace(URLError(.networkConnectionLost)))
    }
}
