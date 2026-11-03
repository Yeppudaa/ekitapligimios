import UIKit
import XCTest
@testable import Ekitapligim

@MainActor
final class ProfilePhotoLoaderTests: XCTestCase {
    func testPNGIsEncodedAsActualJPEGForExistingUploadContract() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let png = try XCTUnwrap(image.pngData())
        let jpeg = try ProfilePhotoLoader.jpeg(from: png)
        XCTAssertEqual(Array(jpeg.prefix(3)), [0xFF, 0xD8, 0xFF])
        let decoded = try XCTUnwrap(UIImage(data: jpeg))
        XCTAssertEqual(decoded.size.width, image.size.width * image.scale, accuracy: 0.5)
        XCTAssertEqual(decoded.size.height, image.size.height * image.scale, accuracy: 0.5)
    }

    func testInvalidImageCannotReachUpload() {
        XCTAssertThrowsError(try ProfilePhotoLoader.jpeg(from: Data("not an image".utf8)))
    }

    func testOriginalSizeLimitIsCheckedBeforeImageDecoding() {
        XCTAssertThrowsError(try ProfilePhotoLoader.jpeg(from: Data(count: ProfileEditorModel.maxImageBytes + 1))) {
            XCTAssertTrue($0 is ProfilePhotoSizeError)
        }
    }
}
