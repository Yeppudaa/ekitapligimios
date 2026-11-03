import SwiftUI
import UIKit
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class CommunityDesignLayoutTests: XCTestCase {
    func testHeroGrowsForLargeTextOnNarrowScreensAndRendersWithoutFixedTextHeight() throws {
        for width: CGFloat in [284, 354, 680] {
            var heights: [CGFloat] = []
            for textSize in [DynamicTypeSize.large, .accessibility3] {
                let view = CommunityHero(eyebrow: CommunityDesignL10n.text("members.eyebrow"),
                    title: CommunityDesignL10n.text("members.hero"), subtitle: CommunityDesignL10n.text("members.subtitle"))
                    .environment(\.dynamicTypeSize, textSize)
                let host = UIHostingController(rootView: view)
                host.safeAreaRegions = []
                let size = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
                XCTAssertEqual(size.width, width, accuracy: 0.5)
                XCTAssertTrue(size.height.isFinite)
                heights.append(size.height)
                let renderer = ImageRenderer(content: view.frame(width: width))
                renderer.scale = 1
                let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
                attachment.name = "community-hero-\(Int(width))-\(textSize)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            XCTAssertGreaterThan(heights[1], heights[0])
        }
    }
}
