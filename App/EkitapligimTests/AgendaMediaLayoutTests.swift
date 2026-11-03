import SwiftUI
import UIKit
import XCTest
@testable import Ekitapligim

@MainActor
final class AgendaMediaLayoutTests: XCTestCase {
    func testPortraitAndLandscapePhotosKeepPixelRatioInsideBoundedSlot() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        for sourceSize in [CGSize(width: 40, height: 80), CGSize(width: 80, height: 40)] {
            let image = UIGraphicsImageRenderer(size: sourceSize, format: format).image { context in
                UIColor.red.setFill(); context.fill(CGRect(origin: .zero, size: sourceSize))
            }
            for slot in [CGSize(width: 284, height: 160), CGSize(width: 354, height: 300), CGSize(width: 680, height: 300)] {
                let view = AgendaPhotoPixels(image: image).frame(width: slot.width, height: slot.height).background(Color.white)
                let renderer = ImageRenderer(content: view); renderer.scale = 1
                let rendered = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(rendered.size, slot)
                let bounds = try redPixelBounds(rendered)
                XCTAssertEqual(bounds.width / bounds.height, sourceSize.width / sourceSize.height, accuracy: 0.025)
                XCTAssertEqual(bounds.midX, slot.width / 2, accuracy: 1)
                XCTAssertEqual(bounds.midY, slot.height / 2, accuracy: 1)
                let attachment = XCTAttachment(image: rendered)
                attachment.name = "agenda-photo-fit-\(Int(sourceSize.width))-\(Int(slot.width))"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }

    private func redPixelBounds(_ image: UIImage) throws -> CGRect {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let bounds: CGRect = try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            let pixels = buffer.bindMemory(to: UInt8.self)
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height { for x in 0..<width {
                let index = (y * width + x) * 4
                if pixels[index] > 220 && pixels[index + 1] < 40 && pixels[index + 2] < 40 {
                    minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
                }
            } }
            XCTAssertGreaterThan(maxX, minX)
            XCTAssertGreaterThan(maxY, minY)
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
        return bounds
    }
}
