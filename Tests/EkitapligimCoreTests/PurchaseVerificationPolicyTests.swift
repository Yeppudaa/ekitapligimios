import XCTest
@testable import EkitapligimCore

final class PurchaseVerificationPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAcceptsActiveEntitlementWithFutureExpiration() throws {
        let response = BillingResponseDTO(
            success: true,
            isPremium: true,
            expirationTime: 1_800_003_600
        )

        XCTAssertEqual(
            try PurchaseVerificationPolicy.requireActive(response, now: now),
            Date(timeIntervalSince1970: 1_800_003_600)
        )
    }

    func testAcceptsActiveLifetimeEntitlement() throws {
        let response = BillingResponseDTO(success: true, isPremium: true)
        XCTAssertNil(try PurchaseVerificationPolicy.requireActive(response, now: now))
    }

    func testRejectsBackendInactiveEntitlement() {
        let response = BillingResponseDTO(success: false, isPremium: false)
        XCTAssertThrowsError(try PurchaseVerificationPolicy.requireActive(response, now: now)) { error in
            XCTAssertEqual(error as? PurchaseVerificationError, .inactiveEntitlement)
        }
    }

    func testRejectsExpiredEntitlementEvenWhenFlagsAreActive() {
        let response = BillingResponseDTO(
            success: true,
            isPremium: true,
            expirationTime: 1_799_999_999
        )
        XCTAssertThrowsError(try PurchaseVerificationPolicy.requireActive(response, now: now)) { error in
            XCTAssertEqual(error as? PurchaseVerificationError, .expiredEntitlement)
        }
    }
}
