import SwiftUI
import UIKit
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class PremiumAvatarLayoutTests: XCTestCase {
    func testPixelCoordinatesMatchTheRenderedTopAndBottom() throws {
        let image = try render(VStack(spacing: 0) {
            Color.red
            Color.blue
        }, size: 20)
        let data = try pixels(image)
        let top = (5 * 20 + 10) * 4
        let bottom = (15 * 20 + 10) * 4
        XCTAssertGreaterThan(data[top], 220)
        XCTAssertLessThan(data[top + 2], 30)
        XCTAssertLessThan(data[bottom], 30)
        XCTAssertGreaterThan(data[bottom + 2], 220)
    }

    func testMovingFrameChangesRimButLeavesPhotoOpeningAndBookStill() throws {
        let first = try render(PremiumAvatarArtwork(cycle: 0.05, sparkle: 0.16), size: 200)
        let second = try render(PremiumAvatarArtwork(cycle: 0.42, sparkle: 0.68), size: 200)
        let left = try pixels(first), right = try pixels(second)
        var changed = 0
        for y in 0..<200 {
            for x in 0..<200 {
                let offset = (y * 200 + x) * 4
                let differs = left[offset..<(offset + 4)] != right[offset..<(offset + 4)]
                if differs { changed += 1 }
                if hypot(Double(x - 100), Double(y - 106)) < 65 {
                    XCTAssertFalse(differs, "Frame animation entered the photo opening")
                }
                if (87...113).contains(x), (12...24).contains(y) {
                    XCTAssertFalse(differs, "Book emblem moved")
                }
            }
        }
        XCTAssertGreaterThan(changed, 200)
        capture(first, name: "premium-frame-phase-a")
        capture(second, name: "premium-frame-phase-b")
    }

    func testRealFrameKeepsAvatarAndGoldEdgeConcentricAtSmallAndLargeSizes() throws {
        for size: CGFloat in [66, 94, 106, 160] {
            let frame = PremiumAvatarFrame(size: size) { diameter in
                Color.red.frame(width: diameter, height: diameter)
            }.environment(\.scenePhase, .inactive)
            let image = try render(frame, size: size)
            XCTAssertEqual(image.size.width, size)
            XCTAssertEqual(image.size.height, size)
            let data = try pixels(image)
            let width = Int(size)
            let centerY = Int(floor(size * PremiumAvatarAppearance.photoCenterYRatio))
            let radius = size * PremiumAvatarAppearance.photoDiameterRatio / 2
            for delta in [CGFloat(-1), CGFloat(1)] {
                // Pixel n has its center at n + 0.5. Flooring these mirrored
                // coordinates keeps both probes equally far from the avatar center.
                // Keep the color probes just inside the decorative sparkle halo.
                let sampleX = Int(floor(size / 2 + delta * (radius - size * 0.04)))
                let offset = (centerY * width + sampleX) * 4
                XCTAssertGreaterThan(data[offset], 220, "Photo must reach both inner edges")
                XCTAssertLessThan(data[offset + 1], 80)
            }
            let photo = opaqueRedBounds(data, width: width)
            XCTAssertEqual(photo.midX, size / 2, accuracy: 1)
            XCTAssertEqual(photo.midY, size * PremiumAvatarAppearance.photoCenterYRatio, accuracy: 1.5)
            XCTAssertEqual(photo.width, size * 0.80, accuracy: 1,
                           "The visible photo must fill the opening up to the inner gold rim")
            capture(image, name: "premium-avatar-fit-\(Int(size))")
        }
    }

    func testLongPremiumNameWrapsWithBadgeAtNarrowAndAccessibleSizes() throws {
        for width: CGFloat in [180, 284, 680] {
            for textSize in [DynamicTypeSize.large, .accessibility3] {
                let name = PremiumMemberName(username: "Kitaplarla Yeni Dünyalar Keşfeden Deniz", isPremium: true)
                    .font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                    .environment(\.dynamicTypeSize, textSize)
                let host = UIHostingController(rootView: name)
                host.safeAreaRegions = []
                let fitting = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
                XCTAssertLessThanOrEqual(fitting.width, width + 0.5)
                XCTAssertTrue(fitting.height.isFinite)
                let renderer = ImageRenderer(content: name.frame(width: width).padding(8).background(.white))
                renderer.scale = 1
                capture(try XCTUnwrap(renderer.uiImage), name: "premium-name-\(Int(width))-\(textSize)")
            }
        }
    }

    private func render<V: View>(_ view: V, size: CGFloat) throws -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage)
    }

    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        try data.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            // CGImage rows already match the renderer's top-to-bottom pixel coordinates.
            // Flipping here samples the animated bottom rim when checking the fixed top book.
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return data
    }

    private func opaqueRedBounds(_ data: [UInt8], width: Int) -> CGRect {
        var minX = width, minY = width, maxX = -1, maxY = -1
        for y in 0..<width { for x in 0..<width {
            let offset = (y * width + x) * 4
            if data[offset] > 220, data[offset + 1] < 80, data[offset + 3] > 250 {
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
            }
        } }
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX + 1), height: max(0, maxY - minY + 1))
    }

    private func capture(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
