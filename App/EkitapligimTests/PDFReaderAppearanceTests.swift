import XCTest
import SwiftUI
import UIKit
import PDFKit
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class PDFReaderAppearanceTests: XCTestCase {
    func testThemeUpdatesPreservePDFIdentityCurrentPageAndUserZoom() async throws {
        let document = try makeDocument()
        let model = AppearanceModel(document: document)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = UIHostingController(rootView: AppearanceHost(model: model))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        await settle(window)
        let pdf = try XCTUnwrap(findPDF(in: controller.view))
        XCTAssertTrue(model.restored)
        XCTAssertEqual(model.progress.currentPage, 25)
        XCTAssertTrue(pdf.currentPage === document.page(at: 24))

        pdf.autoScales = false
        let scale = min(pdf.maxScaleFactor, max(pdf.minScaleFactor, pdf.scaleFactor * 1.2))
        pdf.scaleFactor = scale
        pdf.go(to: try XCTUnwrap(document.page(at: 39)))
        await settle(window)
        XCTAssertEqual(model.progress.currentPage, 40)
        let savesBeforeAppearanceChanges = model.reportedPages

        for theme in [ReaderPaperTheme.night, .white, .sepia] {
            model.theme = theme
            await settle(window)
            let updatedPDF = try XCTUnwrap(findPDF(in: controller.view))
            XCTAssertTrue(updatedPDF === pdf, "Changing paper appearance must keep the live PDFView")
            XCTAssertTrue(updatedPDF.document === document)
            XCTAssertTrue(updatedPDF.currentPage === document.page(at: 39))
            XCTAssertEqual(model.progress.currentPage, 40)
            XCTAssertEqual(updatedPDF.scaleFactor, scale, accuracy: 0.01)
            XCTAssertFalse(updatedPDF.autoScales)
            XCTAssertEqual(model.reportedPages, savesBeforeAppearanceChanges,
                           "Appearance changes must not emit a new reading position")
        }
    }

    private func findPDF(in view: UIView) -> PDFView? {
        if let pdf = view as? PDFView { return pdf }
        for child in view.subviews {
            if let pdf = findPDF(in: child) { return pdf }
        }
        return nil
    }

    private func settle(_ window: UIWindow) async {
        for _ in 0..<12 {
            window.layoutIfNeeded()
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    private func makeDocument() throws -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 390, height: 640)).pdfData { renderer in
            for page in 1...60 {
                renderer.beginPage()
                ("Page \(page)" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.black
                ])
            }
        }
        return try XCTUnwrap(PDFDocument(data: data))
    }
}

@MainActor
private final class AppearanceModel: ObservableObject {
    let document: PDFDocument
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("appearance-fixture.pdf")
    @Published var theme = ReaderPaperTheme.sepia
    @Published var progress = ReadingProgress(currentPage: 1, totalPages: 60)
    @Published var requestedPage: Int?
    var restored = false
    var reportedPages: [Int] = []
    init(document: PDFDocument) { self.document = document }
}

@MainActor
private struct AppearanceHost: View {
    @ObservedObject var model: AppearanceModel
    var body: some View {
        PDFReader(url: model.url, document: model.document, progress: $model.progress,
                  requestedPage: $model.requestedPage, layout: .continuous, initialPage: 25,
                  onPageChange: { model.reportedPages.append($0.currentPage) },
                  onRestored: { model.restored = true })
            .modifier(ReaderPDFPaper(theme: model.theme))
            .ignoresSafeArea(.container)
    }
}
