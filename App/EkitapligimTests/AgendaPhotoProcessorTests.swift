import UIKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
import EkitapligimCore
@testable import Ekitapligim

final class AgendaPhotoProcessorTests: XCTestCase {
    func testLargePNGIsDownsampledToRealJPEGWithoutChangingAspectRatio() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500), format: format).image { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        }
        let data = try AgendaPhotoProcessor.jpeg(XCTUnwrap(image.pngData()))
        XCTAssertEqual(Array(data.prefix(3)), [0xFF, 0xD8, 0xFF])
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.size.width, 2048, accuracy: 1)
        XCTAssertEqual(decoded.size.height, 1024, accuracy: 1)
    }

    func testEXIFOrientationIsAppliedAndGPSIsStripped() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40), format: format).image { context in
            UIColor.systemOrange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let source = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(source, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 41.0, kCGImagePropertyGPSLatitudeRef: "N"]
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let result = try AgendaPhotoProcessor.jpeg(source as Data)
        let decoded = try XCTUnwrap(UIImage(data: result))
        XCTAssertEqual(decoded.size.width, 40, accuracy: 1)
        XCTAssertEqual(decoded.size.height, 80, accuracy: 1)
        let output = try XCTUnwrap(CGImageSourceCreateWithData(result as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(output, 0, nil) as? [CFString: Any])
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    }

    func testInvalidOrOversizedSourceCannotBeUploaded() {
        for data in [Data(), Data("bad image".utf8), Data(count: 40 * 1024 * 1024 + 1)] {
            XCTAssertThrowsError(try AgendaPhotoProcessor.jpeg(data))
        }
    }
}
