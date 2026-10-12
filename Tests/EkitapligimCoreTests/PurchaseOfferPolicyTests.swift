import XCTest
@testable import EkitapligimCore

final class PurchaseOfferPolicyTests: XCTestCase {
    private let monthly = "com.ekitapligim.app.premium.monthly"
    private let term = "com.ekitapligim.app.premium.three_months"
    private func context(_ fields: String = "") throws -> PurchaseAccountDTO {
        try JSONDecoder.ekitapligim.decode(PurchaseAccountDTO.self, from: Data(
            ("{\"success\":true,\"app_account_token\":\"9249ceaa-60dd-4a61-917b-0057f22818aa\"" + fields + "}").utf8))
    }
    func testOldServerPreparationRemainsDecodableAndAllowsFirstPurchase() throws {
        let old = try context()
        XCTAssertNil(old.hasLifetime)
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: term, context: old, entitlement: .none), .allowed)
    }
    func testExistingLifetimeBlocksEveryOfferedNewPayment() throws {
        let live = try context(",\"has_lifetime\":true")
        for product in [monthly, term, PurchaseOfferPolicy.lifetimeID] {
            XCTAssertEqual(PurchaseOfferPolicy.decision(productID: product, context: live, entitlement: .none), .alreadyLifetime)
        }
    }
    func testRenewableWarningIsShownBeforeLifetimeOrFixedTermPurchase() throws {
        let live = try context(",\"has_active_subscription\":true")
        for product in [term, PurchaseOfferPolicy.lifetimeID] {
            XCTAssertEqual(PurchaseOfferPolicy.decision(productID: product, context: live, entitlement: .none), .warnExistingSubscription)
        }
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: monthly, context: live, entitlement: .none), .allowed)
    }
    func testStartingRenewableWhileFixedTermExistsRequiresWarning() throws {
        let live = try context(",\"has_fixed_term\":true")
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: monthly, context: live, entitlement: .none), .warnStartingSubscription)
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: term, context: live, entitlement: .none), .allowed)
    }
    func testOlderServerUsesOnlyActiveServerVerifiedLocalEntitlement() throws {
        let old = try context()
        let active = PremiumEntitlement(productID: PurchaseOfferPolicy.lifetimeID, renewalState: .active)
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: monthly, context: old, entitlement: active), .alreadyLifetime)
        let revoked = PremiumEntitlement(productID: PurchaseOfferPolicy.lifetimeID, renewalState: .revoked)
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: monthly, context: old, entitlement: revoked), .allowed)
    }
    func testAuthoritativeRevocationDoesNotBlockNewPaymentFromStaleLocalState() throws {
        let revoked = try context(",\"has_lifetime\":false,\"has_fixed_term\":false,\"has_active_subscription\":false")
        let stale = PremiumEntitlement(productID: PurchaseOfferPolicy.lifetimeID, renewalState: .active)
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: monthly, context: revoked, entitlement: stale), .allowed)
    }
    func testLifetimeDoesNotDisplayShorterSubscriptionExpiration() {
        let lifetime = PremiumEntitlement(productID: PurchaseOfferPolicy.lifetimeID, renewalState: .active)
        XCTAssertNil(PurchaseOfferPolicy.displayedExpiration(entitlement: lifetime, serverExpiration: 1_900_000_000))
        XCTAssertEqual(PurchaseOfferPolicy.displayedExpiration(entitlement: .none, serverExpiration: 1_900_000_000),
                       Date(timeIntervalSince1970: 1_900_000_000))
    }
}
