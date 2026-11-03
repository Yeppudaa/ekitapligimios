import XCTest
@testable import EkitapligimCore

final class AccountDeletionConfirmationTests: XCTestCase {
    func testTurkishAndLatinSpellingsAreAccepted() {
        for input in ["SİL", "SIL", "sil", "Sil", "sİl", "sıl", " SİL "] {
            XCTAssertTrue(AccountDeletionConfirmation.isConfirmed(input), input)
        }
    }

    func testOtherWordsAreRejected() {
        for input in ["", "SI", "SILL", "SİLİN", "DELETE", "S I L"] {
            XCTAssertFalse(AccountDeletionConfirmation.isConfirmed(input), input)
        }
    }
}
