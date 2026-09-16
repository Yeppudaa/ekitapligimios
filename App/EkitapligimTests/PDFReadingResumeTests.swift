import XCTest
import SwiftUI
import PDFKit
import UIKit
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class PDFReadingResumeTests: XCTestCase {
    func testRestore25NeverEmitsPage1AndLaterReports40Then12() async throws {
        try await assertDelayedRestoration(layout: .paged)
    }

    func testContinuousReaderRestoresActualPageAfterDelayedAttachment() async throws {
        try await assertDelayedRestoration(layout: .continuous)
    }

    private func assertDelayedRestoration(layout: PDFReadingLayout) async throws {
        let document = try makeDocument(pages: 45)
        let view = ResumePDFView()
        var displayed = ReadingProgress(currentPage: 1, totalPages: 1)
        var saved: [Int] = []
        let coordinator = PDFReader.Coordinator(progress: Binding(get: { displayed }, set: { displayed = $0 }),
            requestedPage: .constant(nil), initialPage: 25, onPageChange: { saved.append($0.currentPage) })
        coordinator.configure(view, url: URL(fileURLWithPath: "/test.pdf"), layout: layout, makeDocument: { _ in document })
        coordinator.observe(view)
        defer { coordinator.stopObserving() }
        coordinator.updateProgress(from: view)
        // SwiftUI may leave the representable unattached for more than one main-queue turn.
        for _ in 0..<4 { await nextMainQueueTurn() }
        XCTAssertFalse(coordinator.isRestored)
        XCTAssertTrue(saved.isEmpty)
        let window = attach(view)
        defer { window.isHidden = true }
        await settleLayout(view)
        XCTAssertTrue(coordinator.isRestored)
        XCTAssertTrue(view.currentPage === document.page(at: 24))
        XCTAssertEqual(displayed.currentPage, 25)
        XCTAssertTrue(saved.isEmpty)
        view.go(to: try XCTUnwrap(document.page(at: 39)))
        coordinator.updateProgress(from: view)
        view.go(to: try XCTUnwrap(document.page(at: 11)))
        coordinator.updateProgress(from: view)
        XCTAssertEqual(saved, [40, 12])
        // A later layout must not take the reader back to its initial page.
        view.setNeedsLayout()
        await settleLayout(view)
        XCTAssertTrue(view.currentPage === document.page(at: 11))
        XCTAssertEqual(saved, [40, 12])
    }

    func testStoredPageClampsToActualPDFCountWithoutSavingDuringRestore() async throws {
        let document = try makeDocument(pages: 3)
        let view = ResumePDFView()
        var displayed = ReadingProgress(currentPage: 1, totalPages: 999)
        var writes = 0
        let coordinator = PDFReader.Coordinator(progress: Binding(get: { displayed }, set: { displayed = $0 }),
            requestedPage: .constant(nil), initialPage: 25, onPageChange: { _ in writes += 1 })
        coordinator.configure(view, url: URL(fileURLWithPath: "/test.pdf"), layout: .paged, makeDocument: { _ in document })
        coordinator.observe(view)
        defer { coordinator.stopObserving() }
        let window = attach(view)
        defer { window.isHidden = true }
        await settleLayout(view)
        XCTAssertTrue(coordinator.isRestored)
        XCTAssertTrue(view.currentPage === document.page(at: 2))
        XCTAssertEqual(displayed.currentPage, 3)
        XCTAssertEqual(displayed.totalPages, 3)
        XCTAssertEqual(writes, 0)
    }

    func testFailedNavigationDoesNotPretendToRestoreOrSavePage1() async throws {
        let document = try makeDocument(pages: 30)
        let view = NavigationRejectingPDFView()
        var displayed = ReadingProgress(currentPage: 1, totalPages: 30)
        var writes = 0
        let coordinator = PDFReader.Coordinator(progress: Binding(get: { displayed }, set: { displayed = $0 }),
            requestedPage: .constant(nil), initialPage: 25, onPageChange: { _ in writes += 1 })
        let window = attach(view)
        defer { window.isHidden = true; coordinator.stopObserving() }
        coordinator.configure(view, url: URL(fileURLWithPath: "/test.pdf"), layout: .paged, makeDocument: { _ in document })
        coordinator.observe(view)
        await settleLayout(view)
        coordinator.updateProgress(from: view)
        XCTAssertFalse(coordinator.isRestored)
        XCTAssertNotEqual(displayed.currentPage, 25)
        XCTAssertEqual(writes, 0)
    }

    func testAttachedReaderWaitsForNonzeroBounds() async throws {
        let document = try makeDocument(pages: 30)
        let view = ResumePDFView()
        var displayed = ReadingProgress(currentPage: 1, totalPages: 30)
        var writes = 0
        let coordinator = PDFReader.Coordinator(progress: Binding(get: { displayed }, set: { displayed = $0 }),
            requestedPage: .constant(nil), initialPage: 25, onPageChange: { _ in writes += 1 })
        let window = attach(view)
        defer { window.isHidden = true; coordinator.stopObserving() }
        view.frame = .zero
        coordinator.configure(view, url: URL(fileURLWithPath: "/test.pdf"), layout: .continuous, makeDocument: { _ in document })
        coordinator.observe(view)
        await settleLayout(view)
        XCTAssertFalse(coordinator.isRestored)
        XCTAssertEqual(writes, 0)
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        view.setNeedsLayout()
        await settleLayout(view)
        XCTAssertTrue(coordinator.isRestored)
        XCTAssertTrue(view.currentPage === document.page(at: 24))
        XCTAssertEqual(displayed.currentPage, 25)
        XCTAssertEqual(writes, 0)
    }

    func testClosingBeforeQueuedRestorationDoesNotPublishStalePage() async throws {
        let document = try makeDocument(pages: 30)
        let view = ResumePDFView()
        var displayed = ReadingProgress(currentPage: 1, totalPages: 30)
        let coordinator = PDFReader.Coordinator(progress: Binding(get: { displayed }, set: { displayed = $0 }),
            requestedPage: .constant(nil), initialPage: 25)
        let window = attach(view)
        defer { window.isHidden = true }
        coordinator.configure(view, url: URL(fileURLWithPath: "/test.pdf"), layout: .paged, makeDocument: { _ in document })
        coordinator.observe(view)
        coordinator.stopObserving()
        await settleLayout(view)
        XCTAssertFalse(coordinator.isRestored)
        XCTAssertEqual(displayed.currentPage, 1)
    }

    private func attach(_ view: PDFView) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIViewController()
        window.rootViewController = host
        window.isHidden = false
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        host.view.addSubview(view)
        window.layoutIfNeeded()
        view.setNeedsLayout()
        return window
    }

    private func settleLayout(_ view: PDFView) async {
        for _ in 0..<8 {
            view.layoutIfNeeded()
            await nextMainQueueTurn()
        }
    }

    private func nextMainQueueTurn() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }

    private func makeDocument(pages: Int) throws -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 320, height: 440)).pdfData { context in
            for index in 1...pages {
                context.beginPage()
                ("Page \(index)" as NSString).draw(at: CGPoint(x: 30, y: 30), withAttributes: nil)
            }
        }
        return try XCTUnwrap(PDFDocument(data: data))
    }
}

@MainActor
private final class NavigationRejectingPDFView: PDFView {
    override func go(to page: PDFPage) { }
}
