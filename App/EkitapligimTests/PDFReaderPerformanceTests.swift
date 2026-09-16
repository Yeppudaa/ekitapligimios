import XCTest
import SwiftUI
import UIKit
import PDFKit
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class PDFReaderPerformanceTests: XCTestCase {
    func testProgressUpdatesKeepDocumentAndUserZoomUntilLayoutChanges() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reader-test.pdf")
        let document = try XCTUnwrap(PDFDocument(data: pdfData()))
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        var progress = ReadingProgress(currentPage: 1, totalPages: 2)
        var writes = 0
        let coordinator = PDFReader.Coordinator(progress: Binding(get: { progress }, set: {
            writes += 1
            progress = $0
        }), requestedPage: .constant(nil))
        var documentOpens = 0
        let factory: (URL) -> PDFDocument? = { _ in documentOpens += 1; return document }
        coordinator.configure(view, url: url, layout: .continuous, makeDocument: factory)
        view.autoScales = false
        let writesBefore = writes
        for _ in 0..<10 {
            coordinator.updateProgress(from: view)
            coordinator.configure(view, url: url, layout: .continuous, makeDocument: factory)
        }
        XCTAssertEqual(documentOpens, 1)
        XCTAssertTrue(view.document === document)
        XCTAssertFalse(view.autoScales)
        XCTAssertEqual(writes, writesBefore)
        coordinator.configure(view, url: url, layout: .paged, makeDocument: factory)
        XCTAssertEqual(view.displayMode, .singlePage)
        XCTAssertEqual(view.displayDirection, .horizontal)
        XCTAssertTrue(view.autoScales)
        XCTAssertEqual(documentOpens, 1)
    }

    func testThumbnailCacheReusesImagesAndIsClearedOnCancellation() async throws {
        let url = try writePDF()
        defer { try? FileManager.default.removeItem(at: url) }
        let service = PDFThumbnailService(url: url)
        let count = try await service.pageCount()
        XCTAssertEqual(count, 2)
        let first = try await service.thumbnail(at: 0)
        let second = try await service.thumbnail(at: 0)
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
        let bytes = await service.cachedBytes
        XCTAssertGreaterThan(bytes, 0)
        XCTAssertLessThanOrEqual(bytes, 20 * 1024 * 1024)
        await service.cancel()
        let clearedBytes = await service.cachedBytes
        XCTAssertEqual(clearedBytes, 0)
        do {
            _ = try await service.thumbnail(at: 1)
            XCTFail("Closed picker must not render another page")
        } catch is CancellationError {}
    }

    func testThumbnailBudgetEvictsOldPagesAndRejectsInvalidIndices() async throws {
        let url = try writePDF()
        defer { try? FileManager.default.removeItem(at: url) }
        let sizingService = PDFThumbnailService(url: url)
        _ = try await sizingService.thumbnail(at: 0)
        let onePageCost = await sizingService.cachedBytes
        await sizingService.cancel()
        let service = PDFThumbnailService(url: url, byteLimit: onePageCost)
        let first = try await service.thumbnail(at: 0)
        _ = try await service.thumbnail(at: 1)
        let bytes = await service.cachedBytes
        XCTAssertLessThanOrEqual(bytes, onePageCost)
        let regenerated = try await service.thumbnail(at: 0)
        XCTAssertFalse(first === regenerated)
        let invalid = try await service.thumbnail(at: 99)
        XCTAssertNil(invalid)
        await service.cancel()
    }

    func testInvalidPDFDoesNotProduceThumbnails() async throws {
        let service = PDFThumbnailService(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        do {
            _ = try await service.pageCount()
            XCTFail("Missing PDF should fail")
        } catch BookFileTransferError.invalidFile {}
        await service.cancel()
    }

    private func pdfData() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 320, height: 440)).pdfData { context in
            for _ in 0..<2 {
                context.beginPage()
                UIColor.white.setFill()
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 320, height: 440))
            }
        }
    }

    private func writePDF() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        try pdfData().write(to: url)
        return url
    }
}
