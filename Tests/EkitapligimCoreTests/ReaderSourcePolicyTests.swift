import XCTest
@testable import EkitapligimCore

final class ReaderSourcePolicyTests: XCTestCase {
    func testConvertsGoogleDrivePreviewURLToBinaryDownload() throws {
        let source = try XCTUnwrap(URL(string: "https://drive.google.com/file/d/abc_DEF-123/view?usp=sharing"))
        let result = try XCTUnwrap(ReaderSourcePolicy.downloadableURL(from: source))
        let components = try XCTUnwrap(URLComponents(url: result, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.host, "drive.usercontent.google.com")
        XCTAssertEqual(components.path, "/download")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "id" })?.value, "abc_DEF-123")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "confirm" })?.value, "t")
    }

    func testConvertsGoogleDriveOpenURL() throws {
        let source = try XCTUnwrap(URL(string: "https://drive.google.com/open?id=book42"))

        XCTAssertEqual(
            ReaderSourcePolicy.downloadableURL(from: source)?.host,
            "drive.usercontent.google.com"
        )
    }

    func testPreservesTemporaryServerURLAndToken() throws {
        let source = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/books/42/reader/source?t=secret"))

        XCTAssertEqual(ReaderSourcePolicy.downloadableURL(from: source), source)
    }

    func testRejectsInsecureSource() throws {
        let source = try XCTUnwrap(URL(string: "http://drive.google.com/file/d/book42/view"))

        XCTAssertNil(ReaderSourcePolicy.downloadableURL(from: source))
    }
}
