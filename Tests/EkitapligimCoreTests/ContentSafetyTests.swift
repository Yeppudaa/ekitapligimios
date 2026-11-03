import XCTest
@testable import EkitapligimCore

final class ContentSafetyTests: XCTestCase {
    func testAcceptsNormalText() {
        XCTAssertEqual(ContentSafety().validateUserGeneratedText("Bu kitap hakkında kısa bir yorum."), .accepted)
    }

    func testRejectsEmptyText() {
        XCTAssertEqual(ContentSafety().validateUserGeneratedText("   "), .rejected(reason: .empty))
    }

    func testAcceptsShortNonBlankTextMatchingAndroidIsNotBlank() {
        XCTAssertEqual(ContentSafety().validateUserGeneratedText("a"), .accepted)
        XCTAssertEqual(ContentSafety().validateUserGeneratedText("ok"), .accepted)
    }

    func testRejectsBlockedTerms() {
        XCTAssertEqual(ContentSafety().validateUserGeneratedText("Bu bir spamlink mesajıdır."), .rejected(reason: .blockedTerm))
    }

    func testTurkishCaseAndDotVariantsCannotBypassBlockedTerms() {
        let safety = ContentSafety()
        for text in ["KİŞİSEL VERİ PAYLAŞIMI", "KISISEL VERI PAYLASIMI", "kisisel veri paylasimi", "Nefret Söylemi", "NEFRET SOYLEMI"] {
            XCTAssertEqual(safety.validateUserGeneratedText(text), .rejected(reason: .blockedTerm), text)
        }
        XCTAssertEqual(safety.validateUserGeneratedText("Işık ve kitaplar"), .accepted)
    }
}
