import SwiftUI
import UIKit
import XCTest
@testable import Ekitapligim

/// Renders the production menu face without services or network activity.
/// Native toolbar glass is covered separately by ShellMenuLayoutUITests.
@MainActor
final class MenuButtonAppearanceTests: XCTestCase {
    func testMenuFaceCompletelyHidesContrastingContentBehindItsInterior() throws {
        for (name, size) in [("standard", DynamicTypeSize.large), ("accessibility", .accessibility5)] {
            for (backdropName, backdrop) in [("red", Color.red), ("blue", Color.blue)] {
                for hasUnread in [false, true] {
                    let rendered = try render(backdrop: backdrop, size: size, hasUnread: hasUnread)
                    let context = "\(name), \(backdropName), unread=\(hasUnread)"
                    // Sample the solid face away from the symbol, badge and rounded corners.
                    // A translucent fill tints these pixels red or blue and fails this assertion.
                    for (x, y) in [(32, 15), (15, 32), (49, 32), (32, 49)] {
                        assertWhite(rendered.pixels.pixel(x: x, y: y), context: context)
                    }
                    let attachment = XCTAttachment(image: rendered.image)
                    attachment.name = "menu-face-\(name)-\(backdropName)-unread-\(hasUnread)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    func testUnreadBadgeAndFaceDoNotDrawAnOuterRingOrExtendBeyondTheControl() throws {
        for size in [DynamicTypeSize.large, .accessibility5] {
            let blue = Color(red: 0, green: 0, blue: 1)
            let plain = try render(backdrop: blue, size: size, hasUnread: false)
            let unread = try render(backdrop: blue, size: size, hasUnread: true)
            var changedPixels = 0
            for y in 0..<64 {
                for x in 0..<64 {
                    let plainPixel = plain.pixels.pixel(x: x, y: y)
                    let unreadPixel = unread.pixels.pixel(x: x, y: y)
                    let outsideControl = x < 10 || x >= 54 || y < 10 || y >= 54
                    if outsideControl {
                        XCTAssertEqual(plainPixel, [0, 0, 255, 255], "Face leaks outside its bounds at \(x),\(y)")
                        XCTAssertEqual(unreadPixel, plainPixel, "Badge leaks outside its bounds at \(x),\(y)")
                    }
                    if plainPixel != unreadPixel {
                        changedPixels += 1
                        XCTAssertFalse(outsideControl, "Unread decoration must stay inside the menu")
                    }
                }
            }
            XCTAssertGreaterThan(changedPixels, 0, "Unread state must still render a visible badge")
        }
    }

    private func render(backdrop: Color, size: DynamicTypeSize, hasUnread: Bool) throws -> (image: UIImage, pixels: Pixels) {
        let content = ZStack {
            backdrop
            EKitapligimMenuButtonFace(hasUnread: hasUnread)
        }
        .frame(width: 64, height: 64)
        .environment(\.dynamicTypeSize, size)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 64, height: 64)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage)
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(cgImage.width, 64)
        XCTAssertEqual(cgImage.height, 64)
        var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
        let didDraw = bytes.withUnsafeMutableBytes { storage in
            guard let context = CGContext(data: storage.baseAddress, width: 64, height: 64,
                                          bitsPerComponent: 8, bytesPerRow: 64 * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 64, height: 64))
            return true
        }
        XCTAssertTrue(didDraw, "The component must produce readable pixels")
        return (image, Pixels(bytes: bytes))
    }

    private func assertWhite(_ pixel: [UInt8], context: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        for channel in pixel.prefix(3) {
            XCTAssertGreaterThanOrEqual(channel, 254, "A backdrop shows through the menu: \(context), \(pixel)", file: file, line: line)
        }
        XCTAssertEqual(pixel[3], 255, "The rendered menu must be opaque", file: file, line: line)
    }

    private struct Pixels {
        let bytes: [UInt8]
        func pixel(x: Int, y: Int) -> [UInt8] {
            let index = (y * 64 + x) * 4
            return Array(bytes[index..<(index + 4)])
        }
    }
}
