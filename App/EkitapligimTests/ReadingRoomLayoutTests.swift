import SwiftUI
import UIKit
import XCTest
@testable import Ekitapligim

@MainActor
final class ReadingRoomLayoutTests: XCTestCase {
    func testWelcomeStaysWithinNarrowAndWideWidthsAndGrowsWithAccessibilityText() throws {
        for scheme in [ColorScheme.light, .dark] {
            for width: CGFloat in [248, 343, 736] {
                var heights: [CGFloat] = []
                for typeSize in [DynamicTypeSize.large, .accessibility3] {
                    let content = HomeAgendaWelcome(onOpen: {})
                        .environment(\.dynamicTypeSize, typeSize).environment(\.colorScheme, scheme)
                    let host = UIHostingController(rootView: content)
                    host.safeAreaRegions = []
                    let size = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
                    XCTAssertEqual(size.width, width, accuracy: 1)
                    XCTAssertTrue(size.height.isFinite)
                    XCTAssertGreaterThan(size.height, 140)
                    heights.append(size.height)
                    let renderer = ImageRenderer(content: content.frame(width: width)); renderer.scale = 1
                    let image = try XCTUnwrap(renderer.uiImage)
                    XCTAssertEqual(image.size.width, width, accuracy: 1)
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "reading-room-\(scheme)-\(Int(width))-\(typeSize)"
                    attachment.lifetime = .keepAlways; add(attachment)
                }
                XCTAssertGreaterThan(heights[1], heights[0])
            }
        }
    }
}
