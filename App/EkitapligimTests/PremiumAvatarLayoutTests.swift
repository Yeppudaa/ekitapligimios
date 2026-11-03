import SwiftUI
import UIKit
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class PremiumAvatarLayoutTests: XCTestCase {
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
            let centerY = Int((size * PremiumAvatarAppearance.photoCenterYRatio).rounded())
            let radius = size * PremiumAvatarAppearance.photoDiameterRatio / 2
            for delta in [CGFloat(-1), CGFloat(1)] {
                let sampleX = Int((size / 2 + delta * (radius - size * 0.025)).rounded())
                let offset = (centerY * width + sampleX) * 4
                XCTAssertGreaterThan(data[offset], 220, "Photo must reach both inner edges")
                XCTAssertLessThan(data[offset + 1], 80)
            }
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
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return data
    }

    private func capture(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
