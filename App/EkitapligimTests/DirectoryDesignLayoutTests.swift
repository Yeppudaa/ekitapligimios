import SwiftUI
import UIKit
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class DirectoryDesignLayoutTests: XCTestCase {
    func testBothScenicHeadersAndLongEntryNamesFitNarrowAndTabletWidths() throws {
        let item = try JSONDecoder().decode(DirectoryItemDTO.self, from: Data(#"{"id":"layout","name":"Türkiye İş Bankası Kültür Yayınları — Uzun Bir Yayınevi Adı","bookCount":12345}"#.utf8))
        for kind in DirectoryKind.allCases {
            for width: CGFloat in [284, 354, 724] {
                var heights: [CGFloat] = []
                for textSize in [DynamicTypeSize.large, .accessibility3] {
                    let content = VStack(spacing: 18) {
                        DirectoryScenicHeader(kind: kind, totalEntries: 14096, totalBooks: 37072)
                        DirectoryEntryCard(kind: kind, item: item)
                    }.environment(\.dynamicTypeSize, textSize)
                    let host = UIHostingController(rootView: content)
                    host.safeAreaRegions = []
                    let size = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
                    XCTAssertEqual(size.width, width, accuracy: 0.5)
                    XCTAssertTrue(size.height.isFinite)
                    heights.append(size.height)
                    let renderer = ImageRenderer(content: content.frame(width: width))
                    renderer.scale = 1
                    let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
                    attachment.name = "directory-\(kind.rawValue)-\(Int(width))-\(textSize)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                XCTAssertGreaterThan(heights[1], heights[0], "Large text must grow instead of clipping")
            }
        }
    }
}
