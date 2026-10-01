import XCTest
@testable import EkitapligimCore

final class PremiumEntitlementTests: XCTestCase {
    func testCancelledSubscriptionRemainsActiveUntilExpiration() {
        let entitlement = PremiumEntitlement(
            productID: "ekitapligim.premium.monthly",
            expiration: Date().addingTimeInterval(3_600),
            renewalState: .cancelled,
            willAutoRenew: false
        )

        XCTAssertTrue(entitlement.isActive)
    }

    func testGracePeriodRemainsEntitled() {
        XCTAssertTrue(PremiumEntitlement(renewalState: .gracePeriod).isActive)
    }

    func testBillingRetryExpiredAndRevokedAreNotEntitled() {
        XCTAssertFalse(PremiumEntitlement(renewalState: .billingRetry).isActive)
        XCTAssertFalse(PremiumEntitlement(renewalState: .expired).isActive)
        XCTAssertFalse(PremiumEntitlement(renewalState: .revoked).isActive)
    }

    func testCachedEntitlementExpiresEvenWhenOffline() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for state in [PremiumRenewalState.active, .cancelled, .gracePeriod] {
            let entitlement = PremiumEntitlement(expiration: now, renewalState: state)
            XCTAssertFalse(entitlement.isActive(at: now))
            XCTAssertTrue(entitlement.isActive(at: now.addingTimeInterval(-1)))
        }
        XCTAssertTrue(PremiumEntitlement(renewalState: .active).isActive(at: now))
    }
}
