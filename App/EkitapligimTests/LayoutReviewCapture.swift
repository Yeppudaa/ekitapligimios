import SwiftUI
import UIKit
import XCTest

/// Render the complete static SwiftUI layout, then attach bounded review images.
/// UIKit hierarchy snapshots can fail for offscreen hosting windows on CI.
@MainActor
enum LayoutReviewCapture {
    static func record(host: UIHostingController<AnyView>, size: CGSize, name: String, test: XCTestCase) async throws {
        let renderer = ImageRenderer(content: host.rootView
            .frame(width: size.width, height: size.height, alignment: .topLeading))
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage, "SwiftUI must render the complete page: \(name)")
        let pixels = try XCTUnwrap(image.cgImage, "The review image must contain actual pixels: \(name)")
        XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
        XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
        var offset: CGFloat = 0
        var page = 1
        while offset < size.height {
            let tile = CGRect(x: 0, y: offset, width: size.width, height: min(720, size.height - offset))
            let crop = try XCTUnwrap(pixels.cropping(to: tile), "Every review tile must render: \(name), tile \(page)")
            XCTAssertEqual(CGFloat(crop.width), tile.width, accuracy: 0.5)
            XCTAssertEqual(CGFloat(crop.height), tile.height, accuracy: 0.5)
            let attachment = XCTAttachment(image: UIImage(cgImage: crop))
            attachment.name = "\(name)-tile-\(page)-y\(Int(offset))"
            attachment.lifetime = .keepAlways
            test.add(attachment)
            offset += tile.height
            page += 1
        }
        XCTAssertEqual(offset, size.height, accuracy: 0.5, "The complete page must be captured without dropping content")
    }
}
