import XCTest
@testable import EkitapligimCore

final class PremiumProductCatalogTests: XCTestCase {
    func testEveryOfferedTermRenewsAtItsOwnInterval() {
        XCTAssertEqual(PremiumProductCatalog.productIDs.compactMap {
            PremiumProductCatalog.subscriptionMonths(for: $0)
        }, [1, 3, 6, 12])
        XCTAssertNil(PremiumProductCatalog.subscriptionMonths(for: PremiumProductCatalog.lifetimeID))
        XCTAssertEqual(PremiumProductCatalog.productIDs.count, 5)
    }

    func testOldFixedTermsRemainRecognizedWithoutBeingOfferedOrConverted() {
        for suffix in ["three_months", "six_months", "yearly_once"] {
            let id = "com.ekitapligim.app.premium." + suffix
            XCTAssertTrue(PremiumProductCatalog.legacyProductIDs.contains(id))
            XCTAssertFalse(PremiumProductCatalog.productIDs.contains(id))
            XCTAssertNil(PremiumProductCatalog.subscriptionMonths(for: id))
        }
    }

    func testNewPlansCannotChargeBeforeBackendSupportsThem() throws {
        let old = try decode("")
        for id in ["com.ekitapligim.app.premium.quarterly", "com.ekitapligim.app.premium.semiannual"] {
            XCTAssertFalse(PremiumProductCatalog.canPurchase(id, context: old))
            let supported = try decode(",\"supported_product_ids\":[\"\(id)\"]")
            XCTAssertTrue(PremiumProductCatalog.canPurchase(id, context: supported))
            XCTAssertFalse(PremiumProductCatalog.canPurchase(id, context: try decode(",\"supported_product_ids\":[]")))
        }
        XCTAssertTrue(PremiumProductCatalog.canPurchase("com.ekitapligim.app.premium.monthly", context: old))
        XCTAssertTrue(PremiumProductCatalog.canPurchase("com.ekitapligim.app.premium.yearly", context: old))
        XCTAssertTrue(PremiumProductCatalog.canPurchase(PremiumProductCatalog.lifetimeID, context: old))
    }

    func testAllNewSubscriptionSwitchesStayInRenewableOfferPolicy() throws {
        let subscription = try decode(",\"has_active_subscription\":true")
        let oldTerm = try decode(",\"has_fixed_term\":true")
        for id in PremiumProductCatalog.productIDs where id != PremiumProductCatalog.lifetimeID {
            XCTAssertEqual(PurchaseOfferPolicy.decision(productID: id, context: subscription, entitlement: .none), .allowed)
            XCTAssertEqual(PurchaseOfferPolicy.decision(productID: id, context: oldTerm, entitlement: .none), .warnStartingSubscription)
            let entitlement = PremiumEntitlement(productID: id, expiration: Date().addingTimeInterval(3600), renewalState: .active)
            XCTAssertEqual(PurchaseOfferPolicy.decision(productID: PremiumProductCatalog.lifetimeID,
                context: try decode(""), entitlement: entitlement), .warnExistingSubscription)
        }
    }

    func testFailedPreparationNeverAllowsPayment() throws {
        let response = PurchaseAccountDTO(success: false, appAccountToken: UUID(),
            supportedProductIds: PremiumProductCatalog.productIDs)
        for id in PremiumProductCatalog.productIDs {
            XCTAssertFalse(PremiumProductCatalog.canPurchase(id, context: response))
        }
    }

    private func decode(_ fields: String) throws -> PurchaseAccountDTO {
        try JSONDecoder.ekitapligim.decode(PurchaseAccountDTO.self, from: Data(
            ("{\"success\":true,\"app_account_token\":\"9249ceaa-60dd-4a61-917b-0057f22818aa\"" + fields + "}").utf8))
    }
}
