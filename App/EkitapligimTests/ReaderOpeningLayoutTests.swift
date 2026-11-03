import SwiftUI
import UIKit
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class ReaderOpeningLayoutTests: XCTestCase {
    func testSnapshotUsesItsOwnWindowCoordinatesAndVisibleCoverPixels() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        controller.view.backgroundColor = .white
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let parent = UIView(frame: CGRect(x: 18, y: 70, width: 240, height: 350))
        let anchor = UIView(frame: CGRect(x: 12, y: 30, width: 112, height: 166))
        anchor.backgroundColor = .systemTeal
        controller.view.addSubview(parent)
        parent.addSubview(anchor)
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        let source = ReaderOpeningSource()
        source.anchor = anchor
        let snapshot = try XCTUnwrap(source.capture())
        XCTAssertEqual(snapshot.windowSize, window.bounds.size)
        XCTAssertEqual(snapshot.coverFrame, CGRect(x: 30, y: 100, width: 112, height: 166))
        let cover = try XCTUnwrap(snapshot.cover)
        XCTAssertEqual(cover.size.width, 112, accuracy: 0.5)
        XCTAssertEqual(cover.size.height, 166, accuracy: 0.5)
        let attachment = XCTAttachment(image: cover)
        attachment.name = "reader-captured-cover-in-window-coordinates"
        attachment.lifetime = .keepAlways
        add(attachment)
        parent.clipsToBounds = true
        parent.frame.size.height = 100
        let parentClipped = try XCTUnwrap(source.capture())
        XCTAssertNil(parentClipped.cover)
        XCTAssertNil(parentClipped.coverFrame)
        // A scrolled cover falls back to a centered book instead of enlarging clipped pixels.
        parent.frame.origin.y = -400
        let clipped = try XCTUnwrap(source.capture())
        XCTAssertNil(clipped.cover)
        XCTAssertNil(clipped.coverFrame)
    }

    func testActualSwiftUIFramesRenderDifferentlyAndAttachForVisualReview() throws {
        let book = try JSONDecoder().decode(BookDTO.self, from: Data("""
            {"id":"42","title":"Okuma Yolculuğu","author":"Ekitaplığım","publisher":"",
             "isbn":"","category":"Deneme","language":"Türkçe","publishYear":"2026",
             "description":"","coverUrl":"","pdfUrl":"","pageCount":60,"isPremiumOnly":false}
            """.utf8))
        let coverRenderer = ImageRenderer(content: EKitapligimMissingBookCover(title: book.title, author: book.author)
            .frame(width: 170, height: 250))
        coverRenderer.scale = 2
        let cover = try XCTUnwrap(coverRenderer.uiImage)
        for size in [CGSize(width: 390, height: 844), CGSize(width: 1_024, height: 1_366)] {
            let background = UIGraphicsImageRenderer(size: size).image { context in
                UIColor.lightGray.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            let snapshot = ReaderOpeningSnapshot(background: background, cover: cover,
                coverFrame: CGRect(x: 24, y: 100, width: 170, height: 250), windowSize: size)
            for theme in ReaderPaperTheme.allCases {
                var previous: Data?
                for elapsed in [0.0, 560, 900, 1_380, 1_640, 2_040, 2_160] {
                    let renderer = ImageRenderer(content: ZStack {
                        Image(uiImage: background).resizable()
                        ReaderOpeningArtwork(book: book, snapshot: snapshot, theme: theme,
                                             frame: ReaderOpeningFrame(elapsedMilliseconds: elapsed))
                    }.frame(width: size.width, height: size.height))
                    renderer.scale = 1
                    let image = try XCTUnwrap(renderer.uiImage)
                    XCTAssertEqual(image.size, size)
                    let pixels = try XCTUnwrap(image.pngData())
                    if let previous { XCTAssertNotEqual(pixels, previous, "Each milestone must visibly advance") }
                    previous = pixels
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "reader-cover-\(Int(size.width))-\(theme.rawValue)-\(Int(elapsed))ms"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }
}
