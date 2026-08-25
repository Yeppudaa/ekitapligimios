import Foundation
import Combine
@preconcurrency import StoreKit
import EkitapligimCore

@MainActor
final class StoreKitPurchaseService: ObservableObject {
    static let productIDs = ["ekitapligim.premium.monthly", "ekitapligim.premium.yearly"]

    @Published private(set) var state: PurchaseState = .notLoaded
    @Published private(set) var products: [StoreProduct] = []
    @Published private(set) var entitlement: PremiumEntitlement = .none

    var entitlementDidChange: (@MainActor @Sendable () async -> Void)?

    private let purchaseRepository: any PurchaseVerifying
    private var storeProducts: [Product] = []
    private var updatesTask: Task<Void, Never>?
    private var statusUpdatesTask: Task<Void, Never>?
    private var storefrontUpdatesTask: Task<Void, Never>?
    private var isLoadingProducts = false

    init(purchaseRepository: any PurchaseVerifying) {
        self.purchaseRepository = purchaseRepository
    }

    deinit {
        updatesTask?.cancel()
        statusUpdatesTask?.cancel()
        storefrontUpdatesTask?.cancel()
    }

    func startObservingTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard !Task.isCancelled else { break }
                await self?.processTransactionUpdate(update)
            }
        }
        statusUpdatesTask = Task { [weak self] in
            for await _ in Product.SubscriptionInfo.Status.updates {
                guard !Task.isCancelled else { break }
                await self?.refreshEntitlements()
            }
        }
        storefrontUpdatesTask = Task { [weak self] in
            for await _ in Storefront.updates {
                guard !Task.isCancelled else { break }
                await self?.loadProducts(force: true)
            }
        }
    }

    func stopObservingTransactions() {
        updatesTask?.cancel()
        statusUpdatesTask?.cancel()
        storefrontUpdatesTask?.cancel()
        updatesTask = nil
        statusUpdatesTask = nil
        storefrontUpdatesTask = nil
        entitlement = .none
        state = products.isEmpty ? .notLoaded : .available(products: products)
    }

    func prepare() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts(force: Bool = false) async {
        if !force, !storeProducts.isEmpty {
            state = .available(products: products)
            return
        }
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        state = .loading
        do {
            let loaded = try await loadProductsWithRetry()
            guard !loaded.isEmpty else {
                state = .failed(message: L10n.premiumProductMissing)
                return
            }
            storeProducts = loaded.sorted { lhs, rhs in
                (Self.productIDs.firstIndex(of: lhs.id) ?? .max)
                    < (Self.productIDs.firstIndex(of: rhs.id) ?? .max)
            }
            products = storeProducts.map {
                StoreProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
            }
            state = .available(products: products)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(message: L10n.premiumProductsFailed)
        }
    }

    private func loadProductsWithRetry() async throws -> [Product] {
        // StoreKit may briefly return an empty catalog while TestFlight/Sandbox
        // establishes the storefront. Retry before presenting a permanent error.
        let retryDelays: [UInt64] = [0, 1_000_000_000, 3_000_000_000, 6_000_000_000]
        var lastLoaded: [Product] = []

        for delay in retryDelays {
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
            let loaded = try await Product.products(for: Self.productIDs)
            if !loaded.isEmpty {
                return loaded
            }
            lastLoaded = loaded
        }

        return lastLoaded
    }

    func purchase(productID: String) async {
        guard Self.productIDs.contains(productID) else {
            state = .failed(message: L10n.premiumProductMissing)
            return
        }

        do {
            let product: Product
            if let cached = storeProducts.first(where: { $0.id == productID }) {
                product = cached
            } else if let loaded = try await Product.products(for: [productID]).first {
                product = loaded
            } else {
                state = .failed(message: L10n.premiumProductMissing)
                return
            }

            state = .purchasing(productID: productID)
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let response = try await verifyWithServer(verification, transaction: transaction)
                let serverExpiration = try PurchaseVerificationPolicy.requireActive(response)
                let updated = await entitlementSnapshot(for: transaction, serverExpiration: serverExpiration)
                await transaction.finish()
                entitlement = updated
                state = .purchased(productID: transaction.productID, expiration: updated.expiration)
                await entitlementDidChange?()
            case .pending:
                state = .pending
            case .userCancelled:
                state = .available(products: products)
            @unknown default:
                state = .failed(message: L10n.premiumPurchaseFailed)
            }
        } catch {
            state = .failed(message: L10n.premiumVerificationFailed)
        }
    }

    func restore() async {
        state = .loading
        do {
            try await AppStore.sync()
            guard let restored = try await synchronizeCurrentEntitlements() else {
                state = .failed(message: L10n.premiumNothingToRestore)
                return
            }
            entitlement = restored
            state = .restored
            await entitlementDidChange?()
        } catch {
            state = .failed(message: L10n.premiumRestoreFailed)
        }
    }

    func refreshEntitlements() async {
        do {
            let previous = entitlement
            entitlement = try await synchronizeCurrentEntitlements() ?? .none
            if state == .notLoaded, !products.isEmpty {
                state = .available(products: products)
            }
            if previous != entitlement {
                await entitlementDidChange?()
            }
        } catch {
            // Keep the last server-backed state during transient network failures.
        }
    }

    private func synchronizeCurrentEntitlements() async throws -> PremiumEntitlement? {
        var best: PremiumEntitlement?
        for await result in Transaction.currentEntitlements {
            let transaction = try checkVerified(result)
            guard Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded else { continue }

            let response = try await verifyWithServer(result, transaction: transaction)
            let serverExpiration = try PurchaseVerificationPolicy.requireActive(response)
            let candidate = await entitlementSnapshot(for: transaction, serverExpiration: serverExpiration)
            if isLater(candidate, than: best) { best = candidate }
        }
        return best
    }

    private func verifyWithServer(
        _ verification: VerificationResult<Transaction>,
        transaction: Transaction
    ) async throws -> BillingResponseDTO {
        let signedRenewalInfo: String?
        if let status = await transaction.subscriptionStatus,
           case .verified = status.renewalInfo {
            signedRenewalInfo = status.renewalInfo.jwsRepresentation
        } else {
            signedRenewalInfo = nil
        }
        return try await purchaseRepository.verifyAppStorePurchase(
            signedTransaction: verification.jwsRepresentation,
            productID: transaction.productID,
            originalTransactionID: String(transaction.originalID),
            signedRenewalInfo: signedRenewalInfo
        )
    }

    private func entitlementSnapshot(
        for transaction: Transaction,
        serverExpiration: Date?
    ) async -> PremiumEntitlement {
        var renewalState: PremiumRenewalState = .active
        var willAutoRenew = true

        if let status = await transaction.subscriptionStatus {
            switch status.state {
            case .subscribed: renewalState = .active
            case .inGracePeriod: renewalState = .gracePeriod
            case .inBillingRetryPeriod: renewalState = .billingRetry
            case .expired: renewalState = .expired
            case .revoked: renewalState = .revoked
            default: renewalState = .active
            }
            if case .verified(let renewalInfo) = status.renewalInfo {
                willAutoRenew = renewalInfo.willAutoRenew
                if renewalState == .active, !willAutoRenew { renewalState = .cancelled }
            }
        }

        return PremiumEntitlement(
            productID: transaction.productID,
            expiration: serverExpiration ?? transaction.expirationDate,
            renewalState: renewalState,
            willAutoRenew: willAutoRenew
        )
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreKitError.notAvailableInStorefront
        }
    }

    private func processTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            guard Self.productIDs.contains(transaction.productID) else { return }
            let response = try await verifyWithServer(result, transaction: transaction)
            do {
                let expiration = try PurchaseVerificationPolicy.requireActive(response)
                entitlement = await entitlementSnapshot(for: transaction, serverExpiration: expiration)
                await transaction.finish()
                state = .purchased(productID: transaction.productID, expiration: entitlement.expiration)
            } catch is PurchaseVerificationError {
                await transaction.finish()
                entitlement = PremiumEntitlement(
                    productID: transaction.productID,
                    expiration: transaction.expirationDate,
                    renewalState: transaction.revocationDate == nil ? .expired : .revoked,
                    willAutoRenew: false
                )
                state = products.isEmpty ? .notLoaded : .available(products: products)
            }
            await entitlementDidChange?()
        } catch {
            // Unverified or server-unsynchronized transactions remain unfinished for redelivery.
        }
    }

    private func isLater(_ candidate: PremiumEntitlement, than current: PremiumEntitlement?) -> Bool {
        guard let current else { return true }
        return (candidate.expiration ?? .distantFuture) > (current.expiration ?? .distantFuture)
    }
}
