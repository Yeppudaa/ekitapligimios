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
        let service = StoreKitPurchaseService(purchaseRepository: verifier, accountName: "tester")

        await service.prepare()
        XCTAssertEqual(Set(service.products.map(\.id)), Set(StoreKitPurchaseService.productIDs))

        await service.purchase(productID: "com.ekitapligim.app.premium.monthly")

        guard case .purchased(let productID, _) = service.state else {
            return XCTFail("Expected a verified purchase, got \(service.state)")
        }
        XCTAssertEqual(productID, "com.ekitapligim.app.premium.monthly")
        XCTAssertTrue(service.entitlement.isActive)
        let verificationCount = await verifier.verificationCount
        XCTAssertEqual(verificationCount, 1)
        var capturedAccountToken: UUID?
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result { capturedAccountToken = transaction.appAccountToken }
        }
        XCTAssertEqual(capturedAccountToken?.uuidString.lowercased(), "9249ceaa-60dd-4a61-917b-0057f22818aa")
    }

    func testAskToBuyLeavesPurchasePendingAndDoesNotVerifyServerSide() async throws {
        session.askToBuyEnabled = true
        let verifier = SuccessfulPurchaseVerifier()
        let service = StoreKitPurchaseService(purchaseRepository: verifier, accountName: "tester")
        await service.loadProducts()

        await service.purchase(productID: "com.ekitapligim.app.premium.monthly")

        XCTAssertEqual(service.state, .pending)
        let verificationCount = await verifier.verificationCount
        XCTAssertEqual(verificationCount, 0)
    }

    func testDisabledAutoRenewRemainsActiveUntilPeriodEnd() async throws {
        let verifier = SuccessfulPurchaseVerifier()
        let service = StoreKitPurchaseService(purchaseRepository: verifier, accountName: "tester")
        await service.loadProducts()
        await service.purchase(productID: "com.ekitapligim.app.premium.monthly")

        let transaction = try XCTUnwrap(session.allTransactions().last)
        try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
        await waitForEntitlement(service) {
            $0.renewalState == .cancelled && !$0.willAutoRenew
        }

        XCTAssertEqual(service.entitlement.renewalState, .cancelled)
        XCTAssertTrue(service.entitlement.isActive)
        XCTAssertFalse(service.entitlement.willAutoRenew)
    }

    func testExpirationRemovesLocalEntitlement() async throws {
        let service = StoreKitPurchaseService(purchaseRepository: SuccessfulPurchaseVerifier(),
            accountName: "tester")
        await service.loadProducts()
        await service.purchase(productID: "com.ekitapligim.app.premium.monthly")

        try session.expireSubscription(productIdentifier: "com.ekitapligim.app.premium.monthly")
        await waitForEntitlement(service) { $0 == .none }

        XCTAssertEqual(service.entitlement, .none)
    }

    func testBackendRejectionDoesNotGrantPremium() async throws {
        let service = StoreKitPurchaseService(purchaseRepository: RejectingPurchaseVerifier(), accountName: "tester")
        defer { service.stopObservingTransactions() }
        await service.loadProducts()

        await service.purchase(productID: "com.ekitapligim.app.premium.monthly")

        guard case .failed = service.state else {
            return XCTFail("A rejected backend verification must fail the purchase")
        }
        XCTAssertEqual(service.entitlement, .none)
        XCTAssertEqual(session.allTransactions().count, 1)
    }

    func testRestoreWithoutEntitlementShowsNothingToRestore() async throws {
        let service = StoreKitPurchaseService(purchaseRepository: SuccessfulPurchaseVerifier(),
            accountName: "tester")
        await service.loadProducts()
        await waitForStoreKitToClearEntitlements()

        await service.restore()

        guard case .failed(let message) = service.state else {
            return XCTFail("Expected restore without entitlement to fail")
        }
        XCTAssertEqual(message, L10n.premiumNothingToRestore)
    }

    func testRestoreUsesCurrentVerifiedEntitlementBeforeAppStoreSync() async throws {
        let syncRecorder = AppStoreSyncRecorder()
        let service = StoreKitPurchaseService(
            purchaseRepository: SuccessfulPurchaseVerifier(),
            accountName: "tester",
            appStoreSynchronizer: {
                await syncRecorder.recordCall()
                throw RestoreFailure.appStoreSyncFailed
            }
        )
        await service.loadProducts()
        await service.purchase(productID: "com.ekitapligim.app.premium.monthly")

        await service.restore()

        XCTAssertEqual(service.state, .restored)
        XCTAssertTrue(service.entitlement.isActive)
        let syncCallCount = await syncRecorder.callCount
        XCTAssertEqual(syncCallCount, 0)
    }

    func testRestoreRechecksEntitlementsWhenAppStoreSyncFails() async throws {
        let syncRecorder = AppStoreSyncRecorder()
        let service = StoreKitPurchaseService(
            purchaseRepository: SuccessfulPurchaseVerifier(),
            accountName: "tester",
            appStoreSynchronizer: {
                await syncRecorder.recordCall()
                throw RestoreFailure.appStoreSyncFailed
            }
        )
        defer { service.stopObservingTransactions() }
        await service.loadProducts()

        await service.restore()

        guard case .failed(let message) = service.state else {
            return XCTFail("Expected failed App Store synchronization to be reported")
        }
        XCTAssertEqual(message, L10n.premiumRestoreFailed)
        let syncCallCount = await syncRecorder.callCount
        XCTAssertEqual(syncCallCount, 1)
    }

    func testRestoreKeepsVerifiedEntitlementWhenAnotherVerificationFails() throws {
        let expected = PremiumEntitlement(
            productID: "com.ekitapligim.app.premium.monthly",
            expiration: Date().addingTimeInterval(86_400),
            renewalState: .active,
            willAutoRenew: true
        )

        let restored = try StoreKitPurchaseService.resolveSynchronizedEntitlement(
            best: expected,
            lastFailure: RestoreFailure.rejectedStaleTransaction
        )

        XCTAssertEqual(restored, expected)
    }

    func testRestoreStillFailsWhenEveryVerificationFails() {
        XCTAssertThrowsError(
            try StoreKitPurchaseService.resolveSynchronizedEntitlement(
                best: nil,
                lastFailure: RestoreFailure.rejectedStaleTransaction
            )
        )
    }

    func testCancelledRestoreDoesNotLeaveLoadingState() async {
        let service = StoreKitPurchaseService(
            purchaseRepository: SuccessfulPurchaseVerifier(), accountName: "tester",
            appStoreSynchronizer: { throw CancellationError() }
        )
        await waitForStoreKitToClearEntitlements()
        await service.restore()
        XCTAssertNotEqual(service.state, .loading)
    }

    func testSigningOutDuringVerificationCannotRecreatePremium() async throws {
        let verifier = SuspendedPurchaseVerifier()
        let service = StoreKitPurchaseService(purchaseRepository: verifier, accountName: "tester")
        await service.loadProducts()
        let purchase = Task { await service.purchase(productID: "com.ekitapligim.app.premium.monthly") }
        await verifier.waitUntilRequested()
        service.activateAccount(nil)
        await verifier.succeed()
        await purchase.value
        XCTAssertEqual(service.entitlement, .none)
        guard case .purchased = service.state else { return }
        XCTFail("A response for a signed-out account must not update purchase state")
    }

    func testRestoreFinishesPurchaseLeftPendingByBackendOutage() async throws {
        let verifier = RecoverablePurchaseVerifier()
        let service = StoreKitPurchaseService(purchaseRepository: verifier, accountName: "tester")
        await service.loadProducts()
        await service.purchase(productID: "com.ekitapligim.app.premium.monthly")
        var unfinishedBefore = 0
        for await _ in Transaction.unfinished { unfinishedBefore += 1 }
        XCTAssertGreaterThan(unfinishedBefore, 0)
        await verifier.recover()
        await service.restore()
        XCTAssertEqual(service.state, .restored)
        var unfinishedAfter = 0
        for await _ in Transaction.unfinished { unfinishedAfter += 1 }
        XCTAssertEqual(unfinishedAfter, 0)
        service.stopObservingTransactions()
    }

    func testPurchaseAndRestoreAreSerialized() async throws {
        let verifier = SuspendedPurchaseVerifier()
        let sync = AppStoreSyncRecorder()
        let service = StoreKitPurchaseService(
            purchaseRepository: verifier, accountName: "tester",
            appStoreSynchronizer: { await sync.recordCall() }
        )
        await service.loadProducts()
        let purchase = Task { await service.purchase(productID: "com.ekitapligim.app.premium.monthly") }
        await verifier.waitUntilRequested()
        await service.restore()
        let calls = await sync.callCount
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(service.state, .purchasing(productID: "com.ekitapligim.app.premium.monthly"))
        await verifier.succeed()
        await purchase.value
    }

    func testLifetimePurchaseRestoresIntoNewServiceWithoutExpiration() async {
        let service = StoreKitPurchaseService(purchaseRepository: SuccessfulPurchaseVerifier(), accountName: "tester")
        await service.purchase(productID: "com.ekitapligim.app.premium.lifetime")
        XCTAssertTrue(service.entitlement.isActive)
        XCTAssertNil(service.entitlement.expiration)
        let restored = StoreKitPurchaseService(purchaseRepository: SuccessfulPurchaseVerifier(), accountName: "tester")
        await restored.restore()
        XCTAssertEqual(restored.state, .restored)
        XCTAssertNil(restored.entitlement.expiration)
        XCTAssertFalse(restored.entitlement.willAutoRenew)
    }

    func testExpiredNonRenewingPurchaseShowsNothingToRestore() async {
        let service = StoreKitPurchaseService(purchaseRepository: SuccessfulPurchaseVerifier(), accountName: "tester")
        await service.purchase(productID: "com.ekitapligim.app.premium.three_months")
        XCTAssertTrue(service.entitlement.isActive)
        let expired = StoreKitPurchaseService(
            purchaseRepository: ExpiredPurchaseVerifier(), accountName: "tester", appStoreSynchronizer: {}
        )
        await expired.restore()
        XCTAssertEqual(expired.state, .failed(message: L10n.premiumNothingToRestore))
        XCTAssertEqual(expired.entitlement, .none)
    }

    func testRestoreClearsPreviouslyGrantedEntitlementWhenServerRevokesIt() async {
        let verifier = RecoverablePurchaseVerifier()
        await verifier.recover()
        let service = StoreKitPurchaseService(
            purchaseRepository: verifier, accountName: "tester", appStoreSynchronizer: {}
        )
        defer { service.stopObservingTransactions() }
        await service.purchase(productID: "com.ekitapligim.app.premium.lifetime")
        XCTAssertTrue(service.entitlement.isActive)
        await verifier.revoke()
        await service.restore()
        XCTAssertEqual(service.state, .failed(message: L10n.premiumNothingToRestore))
        XCTAssertEqual(service.entitlement, .none)
    }

    private func waitForEntitlement(
        _ service: StoreKitPurchaseService,
        until predicate: (PremiumEntitlement) -> Bool
    ) async {
        let clock = ContinuousClock()
        // StoreKitTest publishes renewal-info changes asynchronously. Busy CI
        // simulators can need more than five seconds after disabling auto-renew.
        let deadline = clock.now.advanced(by: .seconds(15))

        repeat {
            await service.refreshEntitlements()
            if predicate(service.entitlement) { return }
            try? await Task.sleep(for: .milliseconds(100))
        } while clock.now < deadline
    }

    private func waitForStoreKitToClearEntitlements() async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))

        repeat {
            var hasCurrentEntitlement = false
            for await _ in Transaction.currentEntitlements {
                hasCurrentEntitlement = true
                break
            }
            if !hasCurrentEntitlement { return }
            session.clearTransactions()
            try? await Task.sleep(for: .milliseconds(100))
        } while clock.now < deadline
    }
}

private enum RestoreFailure: Error {
    case rejectedStaleTransaction
    case appStoreSyncFailed
}

// Production always obtains the stable UUID from the authenticated API.
extension PurchaseVerifying {
    func prepareAppStorePurchase(accountName: String) async throws -> UUID {
        try XCTUnwrap(UUID(uuidString: "9249ceaa-60dd-4a61-917b-0057f22818aa"))
    }
}

private actor AppStoreSyncRecorder {
    private(set) var callCount = 0

    func recordCall() {
        callCount += 1
    }
}

private actor SuccessfulPurchaseVerifier: PurchaseVerifying {
    private(set) var verificationCount = 0

    func verifyAppStorePurchase(
        signedTransaction: String,
        productID: String,
        originalTransactionID: String?,
        signedRenewalInfo: String?,
        accountName: String
    ) async throws -> BillingResponseDTO {
        verificationCount += 1
        return BillingResponseDTO(
            success: true,
            isPremium: true,
            expirationTime: productID.hasSuffix(".lifetime") ? nil : Int(Date().addingTimeInterval(31 * 86_400).timeIntervalSince1970)
        )
    }
}

private struct RejectingPurchaseVerifier: PurchaseVerifying {
    func verifyAppStorePurchase(
        signedTransaction: String,
        productID: String,
        originalTransactionID: String?,
        signedRenewalInfo: String?,
        accountName: String
    ) async throws -> BillingResponseDTO {
        throw VerificationFailure.rejected
    }

    private enum VerificationFailure: Error { case rejected }
}

private actor SuspendedPurchaseVerifier: PurchaseVerifying {
    private var continuation: CheckedContinuation<BillingResponseDTO, Never>?
    private var requested = false
    private var completed = false

    func verifyAppStorePurchase(signedTransaction: String, productID: String,
                               originalTransactionID: String?, signedRenewalInfo: String?,
                               accountName: String) async throws -> BillingResponseDTO {
        requested = true
        if completed { return response }
        return await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilRequested() async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while !requested && ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(requested, "StoreKit never reached server verification")
    }

    func succeed() {
        completed = true
        continuation?.resume(returning: response)
        continuation = nil
    }

    private var response: BillingResponseDTO {
        BillingResponseDTO(success: true, isPremium: true,
            expirationTime: Int(Date().addingTimeInterval(86_400).timeIntervalSince1970))
    }
}

private actor RecoverablePurchaseVerifier: PurchaseVerifying {
    private var available = false
    private var revoked = false
    func recover() { available = true }
    func revoke() { revoked = true }
    func verifyAppStorePurchase(signedTransaction: String, productID: String,
                               originalTransactionID: String?, signedRenewalInfo: String?,
                               accountName: String) async throws -> BillingResponseDTO {
        guard available else { throw APIClientError.httpStatus(503, nil) }
        if revoked { return BillingResponseDTO(success: false, isPremium: false) }
        return BillingResponseDTO(success: true, isPremium: true,
            expirationTime: productID.hasSuffix(".lifetime") ? nil : Int(Date().addingTimeInterval(86_400).timeIntervalSince1970))
    }
}

private struct ExpiredPurchaseVerifier: PurchaseVerifying {
    func verifyAppStorePurchase(signedTransaction: String, productID: String,
                               originalTransactionID: String?, signedRenewalInfo: String?,
                               accountName: String) async throws -> BillingResponseDTO {
        BillingResponseDTO(success: false, isPremium: false)
    }
}
