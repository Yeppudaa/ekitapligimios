import XCTest
import StoreKitTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class PremiumPurchaseTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        let testBundle = Bundle(for: Self.self)
        let configurationURL = try XCTUnwrap(
            testBundle.url(forResource: "Ekitapligim", withExtension: "storekit"),
            "The StoreKit test configuration must be bundled with EkitapligimTests."
        )
        session = try SKTestSession(contentsOf: configurationURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session = nil
    }

    func testProductsLoadAndVerifiedMonthlyPurchaseBecomesActive() async throws {
        let verifier = SuccessfulPurchaseVerifier()
        let service = StoreKitPurchaseService(purchaseRepository: verifier)

        await service.prepare()
        XCTAssertEqual(Set(service.products.map(\.id)), Set(StoreKitPurchaseService.productIDs))

        await service.purchase(productID: "ekitapligim.premium.monthly")

        guard case .purchased(let productID, _) = service.state else {
            return XCTFail("Expected a verified purchase, got \(service.state)")
        }
        XCTAssertEqual(productID, "ekitapligim.premium.monthly")
        XCTAssertTrue(service.entitlement.isActive)
        let verificationCount = await verifier.verificationCount
        XCTAssertEqual(verificationCount, 1)
    }

    func testAskToBuyLeavesPurchasePendingAndDoesNotVerifyServerSide() async throws {
        session.askToBuyEnabled = true
        let verifier = SuccessfulPurchaseVerifier()
        let service = StoreKitPurchaseService(purchaseRepository: verifier)
        await service.loadProducts()

        await service.purchase(productID: "ekitapligim.premium.monthly")

        XCTAssertEqual(service.state, .pending)
        let verificationCount = await verifier.verificationCount
        XCTAssertEqual(verificationCount, 0)
    }

    func testDisabledAutoRenewRemainsActiveUntilPeriodEnd() async throws {
        let verifier = SuccessfulPurchaseVerifier()
        let service = StoreKitPurchaseService(purchaseRepository: verifier)
        await service.loadProducts()
        await service.purchase(productID: "ekitapligim.premium.monthly")

        let transaction = try XCTUnwrap(session.allTransactions().last)
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        await service.refreshEntitlements()

        XCTAssertEqual(service.entitlement.renewalState, .cancelled)
        XCTAssertTrue(service.entitlement.isActive)
        XCTAssertFalse(service.entitlement.willAutoRenew)
    }

    func testExpirationRemovesLocalEntitlement() async throws {
        let service = StoreKitPurchaseService(purchaseRepository: SuccessfulPurchaseVerifier())
        await service.loadProducts()
        await service.purchase(productID: "ekitapligim.premium.monthly")

        try session.expireSubscription(productIdentifier: "ekitapligim.premium.monthly")
        await service.refreshEntitlements()

        XCTAssertEqual(service.entitlement, .none)
    }

    func testBackendRejectionDoesNotGrantPremium() async throws {
        let service = StoreKitPurchaseService(purchaseRepository: RejectingPurchaseVerifier())
        await service.loadProducts()

        await service.purchase(productID: "ekitapligim.premium.monthly")

        guard case .failed = service.state else {
            return XCTFail("A rejected backend verification must fail the purchase")
        }
        XCTAssertEqual(service.entitlement, .none)
        XCTAssertEqual(session.allTransactions().count, 1)
    }

    func testRestoreWithoutEntitlementShowsNothingToRestore() async throws {
        let service = StoreKitPurchaseService(purchaseRepository: SuccessfulPurchaseVerifier())
        await service.loadProducts()

        await service.restore()

        guard case .failed(let message) = service.state else {
            return XCTFail("Expected restore without entitlement to fail")
        }
        XCTAssertEqual(message, L10n.premiumNothingToRestore)
    }
}

private actor SuccessfulPurchaseVerifier: PurchaseVerifying {
    private(set) var verificationCount = 0

    func verifyAppStorePurchase(
        signedTransaction: String,
        productID: String,
        originalTransactionID: String?,
        signedRenewalInfo: String?
    ) async throws -> BillingResponseDTO {
        verificationCount += 1
        return BillingResponseDTO(
            success: true,
            isPremium: true,
            expirationTime: Int(Date().addingTimeInterval(31 * 86_400).timeIntervalSince1970)
        )
    }
}

private struct RejectingPurchaseVerifier: PurchaseVerifying {
    func verifyAppStorePurchase(
        signedTransaction: String,
        productID: String,
        originalTransactionID: String?,
        signedRenewalInfo: String?
    ) async throws -> BillingResponseDTO {
        throw VerificationFailure.rejected
    }

    private enum VerificationFailure: Error { case rejected }
}
