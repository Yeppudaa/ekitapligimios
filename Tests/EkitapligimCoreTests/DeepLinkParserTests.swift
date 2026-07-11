import XCTest
@testable import EkitapligimCore

final class DeepLinkParserTests: XCTestCase {
    func testBookDeepLink() {
        XCTAssertEqual(
            DeepLinkParser().parse("https://ekitapligim.com/books/suc-ve-ceza.15582/"),
            .bookDetail(15582)
        )
    }

    func testRejectsOtherHosts() {
        XCTAssertNil(DeepLinkParser().parse("https://example.com/books/foo.1/"))
    }
}
