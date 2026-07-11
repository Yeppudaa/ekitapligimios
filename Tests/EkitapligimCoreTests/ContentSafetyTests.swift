import XCTest
@testable import EkitapligimCore

final class ContentSafetyTests: XCTestCase {
    func testAcceptsNormalText() {
        XCTAssertEqual(ContentSafety().validateUserGeneratedText("Bu kitap hakkında kısa bir yorum."), .accepted)
    }

    func testRejectsEmptyText() {
        XCTAssertEqual(ContentSafety().validateUserGeneratedText("   "), .rejected(reason: .empty))
    }

    func testRejectsBlockedTerms() {
        XCTAssertEqual(ContentSafety().validateUserGeneratedText("Bu bir spamlink mesajıdır."), .rejected(reason: .blockedTerm))
    }
}
