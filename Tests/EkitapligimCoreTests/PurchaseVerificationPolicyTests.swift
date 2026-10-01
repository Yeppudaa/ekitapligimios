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

    func testMissingSubscriptionExpirationCannotGrantLifetimeAccess() {
        let response = BillingResponseDTO(success: true, isPremium: true)
        XCTAssertThrowsError(try PurchaseVerificationPolicy.requireActive(
            response, productID: "com.ekitapligim.app.premium.monthly", now: now
        )) { XCTAssertEqual($0 as? PurchaseVerificationError, .missingExpiration) }
        XCTAssertNoThrow(try PurchaseVerificationPolicy.requireActive(
            response, productID: "com.ekitapligim.app.premium.lifetime", now: now
        ))
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

    func testAcceptsAppleBillingGracePeriodAsActiveEntitlement() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let response = BillingResponseDTO(
            success: true,
            isPremium: true,
            expirationTime: 1_699_999_000,
            gracePeriodExpirationTime: 1_700_086_400
        )

        XCTAssertEqual(
            try PurchaseVerificationPolicy.requireActive(response, now: now),
            Date(timeIntervalSince1970: 1_700_086_400)
        )
    }

    func testLinkedAppleTransactionExplainsOriginalAccountOnRestore() {
        let error = APIClientError.httpStatus(400, APIErrorEnvelope(errors: [
            APIErrorDetail(code: "original_transaction_already_linked", message: "Subscription linked")
        ]))

        XCTAssertEqual(
            PurchaseVerificationPolicy.failureMessage(for: error, restoring: true),
            L10n.premiumLinkedToAnotherAccount
        )
        XCTAssertEqual(
            PurchaseVerificationPolicy.failureMessage(for: error),
            L10n.premiumLinkedToAnotherAccount
        )
    }

    func testOtherRestoreFailureKeepsGenericMessage() {
        XCTAssertEqual(
            PurchaseVerificationPolicy.failureMessage(for: APIClientError.invalidResponse, restoring: true),
            L10n.premiumRestoreFailed
        )
    }
}
