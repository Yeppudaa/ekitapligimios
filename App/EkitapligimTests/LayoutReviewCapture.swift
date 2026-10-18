import SwiftUI
import UIKit
import XCTest

/// Capture every point of a tall hosted page through a bounded UIKit viewport.
/// A single 8,000pt screenshot exceeds the native raster limit on a 3x simulator.
@MainActor
enum LayoutReviewCapture {
    static func record(host: UIHostingController<AnyView>, size: CGSize, name: String, test: XCTestCase) async throws {
        let fullBounds = CGRect(origin: .zero, size: size)
        let viewport = CGRect(x: 0, y: 0, width: size.width, height: min(720, size.height))
        let window = UIWindow(frame: viewport)
        let parent = UIViewController()
        parent.view.clipsToBounds = true
        window.clipsToBounds = true
        window.overrideUserInterfaceStyle = host.overrideUserInterfaceStyle
        window.rootViewController = parent
        parent.addChild(host)
        parent.view.addSubview(host.view)
        host.didMove(toParent: parent)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
            window.rootViewController = nil
        }
        var offset: CGFloat = 0
        var page = 1
        while offset < size.height {
            host.view.frame = fullBounds.offsetBy(dx: 0, dy: -offset)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            parent.view.layoutIfNeeded()
            await Task.yield()
            try await Task.sleep(for: .milliseconds(100))
            let tile = CGRect(x: 0, y: 0, width: size.width, height: min(viewport.height, size.height - offset))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            var rendered = false
            let image = UIGraphicsImageRenderer(bounds: tile, format: format).image { _ in
                rendered = window.drawHierarchy(in: viewport, afterScreenUpdates: true)
            }
            XCTAssertTrue(rendered, "UIKit capture failed: \(name), tile \(page), y=\(offset)")
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, tile.height, accuracy: 0.5)
            let attachment = XCTAttachment(image: image)
            attachment.name = "\(name)-tile-\(page)-y\(Int(offset))"
            attachment.lifetime = .keepAlways
            test.add(attachment)
            offset += tile.height
            page += 1
        }
        XCTAssertEqual(offset, size.height, accuracy: 0.5, "The complete page must be captured without dropping content")
    }
}
