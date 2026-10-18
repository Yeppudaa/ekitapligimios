import SwiftUI
import UIKit
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class HomeBookCardLayoutTests: XCTestCase {
    func testLoadingMissingWideAndTallCoversKeepTheSameSlotGeometry() {
        let wide = syntheticImage(CGSize(width: 240, height: 80))
        let tall = syntheticImage(CGSize(width: 80, height: 240))
        let phases: [AnyView] = [
            AnyView(ProgressView()),
            AnyView(EKitapligimMissingBookCover(title: "Kapak bulunamadÄ±", author: "Yazar")),
            AnyView(Image(uiImage: wide).resizable().scaledToFit()),
            AnyView(Image(uiImage: tall).resizable().scaledToFit())
        ]
        for width: CGFloat in [124, 148, 220] {
            for (index, phase) in phases.enumerated() {
                let host = host(AnyView(HomeBookCoverSlot { phase }), size: .large)
                let measured = host.sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
                XCTAssertEqual(measured.width, width, accuracy: 0.5, "phase \(index)")
                XCTAssertEqual(measured.height, width * 1.48, accuracy: 0.5, "phase \(index)")
            }
        }
    }

    func testNormalCardsKeepCompactUniformHeightsForMissingAndLongMetadata() throws {
        let samples = try books()
        for width: CGFloat in [156, 172, 220, 320] {
            let heights = samples.map { book in
                host(AnyView(HomeBookCard(book: book)), size: .large)
                    .sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
            }
            let first = try XCTUnwrap(heights.first)
            for height in heights { XCTAssertEqual(height, first, accuracy: 1, "width \(width)") }
            let coverHeight = (width - 44) * 1.48 + 20
            let copy = VStack(alignment: .leading, spacing: 5) {
                Label { UniformCardText("Roman", lines: 1) } icon: { Image(systemName: "book.closed") }
                    .font(.caption2.weight(.semibold))
                UniformCardText(samples[0].title, lines: 2).font(.subheadline.weight(.semibold))
                UniformCardText(samples[0].author, lines: 1).font(.caption)
            }
            let copyHeight = host(AnyView(copy), size: .large)
                .sizeThatFits(in: CGSize(width: width - 24, height: CGFloat.greatestFiniteMagnitude)).height
            XCTAssertEqual(first, coverHeight + copyHeight + 9 + 24, accuracy: 1,
                           "The card must contain only its measured cover, copy, spacing and padding")
        }
    }

    func testLargerParentProposalCannotStretchCardsAndAccessibilityTextRemainsComplete() throws {
        let book = try XCTUnwrap(books().last)
        let width: CGFloat = 220
        let normal = host(AnyView(HomeBookCard(book: book)), size: .large)
        let normalSize = normal.sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        let constrained = normal.sizeThatFits(in: CGSize(width: width, height: 1_500))
        XCTAssertEqual(constrained.height, normalSize.height, accuracy: 1)

        let large = host(AnyView(HomeBookCard(book: book)), size: .accessibility5)
            .sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        let fullTitle = host(AnyView(Text(book.title).font(.subheadline.weight(.semibold))), size: .accessibility5)
            .sizeThatFits(in: CGSize(width: width - 24, height: CGFloat.greatestFiniteMagnitude))
        let fullAuthor = host(AnyView(Text(book.author).font(.caption)), size: .accessibility5)
            .sizeThatFits(in: CGSize(width: width - 24, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertGreaterThan(large.height, normalSize.height)
        XCTAssertGreaterThanOrEqual(large.height, (width - 44) * 1.48 + fullTitle.height + fullAuthor.height)
        XCTAssertEqual(large.width, width, accuracy: 1)
    }

    func testRenderMixedCoverPhasesAndMetadataForReview() async throws {
        let samples = try books()
        for size in [DynamicTypeSize.large, .accessibility3] {
            let page = VStack(alignment: .leading, spacing: 16) {
                ForEach(samples) { book in HomeBookCard(book: book).frame(width: 172) }
                HStack(alignment: .top, spacing: 12) {
                    HomeBookCoverSlot { Image(uiImage: self.syntheticImage(CGSize(width: 240, height: 80))).resizable().scaledToFit() }
                    HomeBookCoverSlot { ProgressView() }
                }
            }
            let controller = host(AnyView(page), size: size)
            let measured = controller.sizeThatFits(in: CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude))
            XCTAssertTrue(measured.height.isFinite)
            try await LayoutReviewCapture.record(host: controller,
                size: CGSize(width: 360, height: ceil(measured.height)),
                name: "home-book-cards-\(size)", test: self)
        }
    }

    private func host(_ view: AnyView, size: DynamicTypeSize) -> UIHostingController<AnyView> {
        let host = UIHostingController(rootView: AnyView(view.environment(\.dynamicTypeSize, size).environment(\.colorScheme, .light)))
        host.safeAreaRegions = []
        return host
    }

    private func syntheticImage(_ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func books() throws -> [BookDTO] {
        try [
            ("1", "Gizli Tarih", "Donna Tartt", "Roman"),
            ("2", "TaÅŸÄ±yÄ±cÄ± Anne", "Penelope Ward", "Roman"),
            ("3", "Birlikte KeÅŸfettiÄŸimiz HikÃ¢yelerin Ä°zinde Ã‡ok Uzun Bir Okuma YolculuÄŸu", "", ""),
            ("4", "Birlikte KeÅŸfettiÄŸimiz HikÃ¢yelerin Ä°zinde Ã‡ok Uzun Bir Okuma YolculuÄŸu", "Birbirinden GÃ¼zel KitaplarÄ±n Ã‡ok Uzun Ä°simli Ã–rnek YazarÄ±", "Edebiyat")
        ].map { id, title, author, category in
            let data = try JSONSerialization.data(withJSONObject: [
                "id": id, "title": title, "author": author, "category": category,
                "publisher": "", "isbn": "", "language": "tr", "publish_year": "",
                "description": "", "cover_url": "", "pdf_url": "", "page_count": 0, "is_premium_only": false
            ])
            return try JSONDecoder.ekitapligim.decode(BookDTO.self, from: data)
        }
    }
}
