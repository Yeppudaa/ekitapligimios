import Foundation
import Combine
@preconcurrency import StoreKit
import EkitapligimCore

@MainActor
final class StoreKitPurchaseService: ObservableObject {
    static let productIDs = [
        "com.ekitapligim.app.premium.monthly",
        "com.ekitapligim.app.premium.three_months",
        "com.ekitapligim.app.premium.six_months",
        "com.ekitapligim.app.premium.yearly_once",
        "com.ekitapligim.app.premium.lifetime"
    ]
    static let legacyProductIDs = [
        "com.ekitapligim.app.premium.yearly",
        "ekitapligim.premium.monthly",
        "ekitapligim.premium.yearly"
    ]
    static let recognizedProductIDs = Set(productIDs + legacyProductIDs)

    @Published private(set) var state: PurchaseState = .notLoaded
    @Published private(set) var products: [StoreProduct] = []
    @Published private(set) var entitlement: PremiumEntitlement = .none

    var entitlementDidChange: (@MainActor @Sendable () async -> Void)?

    private let purchaseRepository: any PurchaseVerifying
    private let appStoreSynchronizer: @Sendable () async throws -> Void
    private var storeProducts: [Product] = []
    private var updatesTask: Task<Void, Never>?
    private var statusUpdatesTask: Task<Void, Never>?
    private var storefrontUpdatesTask: Task<Void, Never>?
    private var isLoadingProducts = false
    private var isPurchasing = false
    private var accountName: String?
    private var accountGeneration = UUID()
    private var synchronizationRevision = UUID()
    private var isRestoring = false
    private var retryTask: Task<Void, Never>?
    private var hasPendingVerification = false
    private var isBusy: Bool { isPurchasing || isRestoring }

    init(
        purchaseRepository: any PurchaseVerifying,
        accountName: String? = nil,
        appStoreSynchronizer: @escaping @Sendable () async throws -> Void = {
            try await AppStore.sync()
        }
    ) {
        self.purchaseRepository = purchaseRepository
        self.accountName = accountName
        self.appStoreSynchronizer = appStoreSynchronizer
    }

    deinit {
        updatesTask?.cancel()
        statusUpdatesTask?.cancel()
        storefrontUpdatesTask?.cancel()
        retryTask?.cancel()
    }

    func activateAccount(_ username: String?) {
        guard username != accountName else { return }
        stopObservingTransactions()
        accountName = username
        if username != nil { startObservingTransactions() }
    }

    func startObservingTransactions() {
        guard accountName != nil, updatesTask == nil else { return }
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
        accountGeneration = UUID()
        synchronizationRevision = UUID()
        accountName = nil
        isPurchasing = false
        isRestoring = false
        retryTask?.cancel()
        retryTask = nil
        hasPendingVerification = false
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
            if !isBusy { state = .available(products: products) }
            return
        }
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        if storeProducts.isEmpty && !isBusy { state = .loading }
        do {
            let loaded = try await loadProductsWithRetry()
            guard !loaded.isEmpty else {
                if !isBusy {
                    state = storeProducts.isEmpty
                        ? .failed(message: L10n.premiumProductMissing)
                        : .available(products: products)
                }
                return
            }
            storeProducts = loaded.sorted { lhs, rhs in
                (Self.productIDs.firstIndex(of: lhs.id) ?? .max)
                    < (Self.productIDs.firstIndex(of: rhs.id) ?? .max)
            }
            products = storeProducts.map {
                StoreProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
            }
            if !isBusy { state = .available(products: products) }
        } catch is CancellationError {
            return
        } catch {
            if !isBusy {
                state = storeProducts.isEmpty
                    ? .failed(message: L10n.premiumProductsFailed)
                    : .available(products: products)
            }
        }
    }

    private func loadProductsWithRetry() async throws -> [Product] {
        // StoreKit may briefly return an empty or partial catalog while
        // TestFlight/Sandbox establishes the storefront. Keep successful
        // products across retries before presenting a permanent error.
        let retryDelays: [UInt64] = [0, 2_000_000_000, 5_000_000_000, 10_000_000_000, 20_000_000_000]
        var loadedByID: [String: Product] = [:]
        var lastError: Error?

        for delay in retryDelays {
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
            do {
                let loaded = try await Product.products(for: Self.productIDs)
                for product in loaded where Self.productIDs.contains(product.id) {
                    loadedByID[product.id] = product
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // StoreKit can throw while the sandbox storefront is still
                // becoming available. Keep retrying instead of failing on the
                // first transient storefront/network error.
                lastError = error
            }

            // A sandbox storefront can transiently return only part of a
            // catalog. Query the missing identifiers individually and merge
            // successful responses across retries instead of discarding them.
            for productID in Self.productIDs where loadedByID[productID] == nil {
                do {
                    if let product = try await Product.products(for: [productID]).first,
                       product.id == productID {
                        loadedByID[productID] = product
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    lastError = error
                }
            }

            if loadedByID.count == Self.productIDs.count {
                return Array(loadedByID.values)
            }
        }

        if let lastError, loadedByID.isEmpty {
            throw lastError
        }
        return Array(loadedByID.values)
    }

    func purchase(productID: String) async {
        guard !isBusy, accountName != nil else { return }
        let generation = accountGeneration
        guard let purchaseAccount = accountName else { return }
        synchronizationRevision = UUID()
        guard Self.productIDs.contains(productID) else {
            state = .failed(message: L10n.premiumProductMissing)
            return
        }
        isPurchasing = true
        state = .purchasing(productID: productID)
        defer {
            if generation == accountGeneration {
                isPurchasing = false
                scheduleVerificationRetry()
            }
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

            try requireCurrentAccount(generation)
            let appAccountToken = try await purchaseRepository.prepareAppStorePurchase(accountName: purchaseAccount)
            try requireCurrentAccount(generation)
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            try requireCurrentAccount(generation)
            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    let response = try await verifyWithServer(verification, transaction: transaction, generation: generation)
                    let serverExpiration = try PurchaseVerificationPolicy.requireActive(response, productID: transaction.productID)
                    let updated = await entitlementSnapshot(for: transaction, serverExpiration: serverExpiration)
                    try requireCurrentAccount(generation)
                    await transaction.finish()
                    try requireCurrentAccount(generation)
                    if isLater(updated, than: entitlement.isActive ? entitlement : nil) { entitlement = updated }
                    state = .purchased(productID: transaction.productID, expiration: updated.expiration)
                    await entitlementDidChange?()
                } catch {
                    guard generation == accountGeneration, !Task.isCancelled else { return }
                    hasPendingVerification = true
                    state = .failed(message: PurchaseVerificationPolicy.failureMessage(for: error))
                }
            case .pending:
                state = .pending
            case .userCancelled:
                state = .available(products: products)
            @unknown default:
                state = .failed(message: L10n.premiumPurchaseFailed)
            }
        } catch {
            guard generation == accountGeneration, !Task.isCancelled else { return }
            state = .failed(message: L10n.premiumPurchaseFailed)
        }
    }

    func restore() async {
        guard !isBusy, accountName != nil else { return }
        let generation = accountGeneration
        synchronizationRevision = UUID()
        isRestoring = true
        defer {
            if generation == accountGeneration {
                isRestoring = false
                if state == .loading { state = products.isEmpty ? .notLoaded : .available(products: products) }
                scheduleVerificationRetry()
            }
        }
        state = .loading

        var lastFailure: Error?

        // An active StoreKit entitlement may already be available and verified
        // server-side. Do not make that successful restore depend on the
        // account-dialog based AppStore.sync() call, which can fail or be
        // cancelled even though the entitlement itself is valid.
        do {
            if let restored = try await synchronizeCurrentEntitlements(generation: generation) {
                try requireCurrentAccount(generation)
                await completeRestore(restored)
                return
            }
        } catch is CancellationError {
            if !isBusy, state == .loading {
                state = products.isEmpty ? .notLoaded : .available(products: products)
            }
            return
        } catch {
            if lastFailure == nil { lastFailure = error }
        }

        do {
            try requireCurrentAccount(generation)
            try await appStoreSynchronizer()
            try requireCurrentAccount(generation)
        } catch is CancellationError {
            return
        } catch {
            if lastFailure == nil || PurchaseVerificationPolicy.isLinkedAccountError(error) {
                lastFailure = error
            }
        }

        // Re-read entitlements even when AppStore.sync() failed. StoreKit can
        // refresh its transaction cache before the sync call reports an error.
        do {
            if let restored = try await synchronizeCurrentEntitlements(generation: generation) {
                try requireCurrentAccount(generation)
                await completeRestore(restored)
                return
            }
        } catch is CancellationError {
            return
        } catch {
            if lastFailure == nil || PurchaseVerificationPolicy.isLinkedAccountError(error) {
                lastFailure = error
            }
        }

        guard generation == accountGeneration, !Task.isCancelled else { return }
        if let lastFailure {
            hasPendingVerification = true
            state = .failed(message: PurchaseVerificationPolicy.failureMessage(for: lastFailure, restoring: true))
        } else {
            let hadEntitlement = entitlement != .none
            entitlement = .none
            state = .failed(message: L10n.premiumNothingToRestore)
            if hadEntitlement { await entitlementDidChange?() }
        }
    }

    private func completeRestore(_ restored: PremiumEntitlement) async {
        entitlement = restored
        state = .restored
        await entitlementDidChange?()
    }

    func refreshEntitlements() async {
        guard accountName != nil, !isBusy else { return }
        let generation = accountGeneration
        let revision = UUID()
        synchronizationRevision = revision
        do {
            await retryUnfinishedTransactions(generation: generation)
            let synchronized = try await synchronizeCurrentEntitlements(generation: generation)
            try requireCurrentAccount(generation)
            guard revision == synchronizationRevision else { return }
            let previous = entitlement
            entitlement = synchronized ?? .none
            if entitlement.isActive, let productID = entitlement.productID {
                switch state {
                case .failed, .pending:
                    state = .purchased(productID: productID, expiration: entitlement.expiration)
                default: break
                }
            }
            if state == .notLoaded, !products.isEmpty {
                state = .available(products: products)
            }
            if previous != entitlement {
                await entitlementDidChange?()
            }
        } catch PurchaseVerificationError.inactiveEntitlement,
                PurchaseVerificationError.expiredEntitlement {
            guard generation == accountGeneration, revision == synchronizationRevision else { return }
            if entitlement != .none {
                entitlement = .none
                await entitlementDidChange?()
            }
        } catch {
            // Keep the last server-backed state during transient network failures.
            if generation == accountGeneration { hasPendingVerification = true }
        }
        if generation == accountGeneration { scheduleVerificationRetry() }
    }

    private func synchronizeCurrentEntitlements(generation: UUID) async throws -> PremiumEntitlement? {
        var best: PremiumEntitlement?
        var lastFailure: Error?

        for await result in Transaction.currentEntitlements {
            do {
                try requireCurrentAccount(generation)
                let transaction = try checkVerified(result)
                guard Self.recognizedProductIDs.contains(transaction.productID),
                      transaction.revocationDate == nil,
                      !transaction.isUpgraded else { continue }

                let response = try await verifyWithServer(result, transaction: transaction, generation: generation)
                let serverExpiration: Date?
                do { serverExpiration = try PurchaseVerificationPolicy.requireActive(response, productID: transaction.productID) }
                catch PurchaseVerificationError.inactiveEntitlement, PurchaseVerificationError.expiredEntitlement {
                    // Non-renewing purchases remain in currentEntitlements after expiry.
                    await transaction.finish()
                    continue
                }
                let candidate = await entitlementSnapshot(for: transaction, serverExpiration: serverExpiration)
                try requireCurrentAccount(generation)
                await transaction.finish()
                try requireCurrentAccount(generation)
                if isLater(candidate, than: best) { best = candidate }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Sandbox accounts can expose more than one current subscription
                // while an upgrade, downgrade, or accelerated renewal settles.
                // One rejected/stale transaction must not hide another entitlement
                // that StoreKit and the server both verified as active.
                hasPendingVerification = true
                if lastFailure == nil || PurchaseVerificationPolicy.isLinkedAccountError(error) {
                    lastFailure = error
                }
            }
        }
        try requireCurrentAccount(generation)
        return try Self.resolveSynchronizedEntitlement(best: best, lastFailure: lastFailure)
    }

    static func resolveSynchronizedEntitlement(
        best: PremiumEntitlement?,
        lastFailure: Error?
    ) throws -> PremiumEntitlement? {
        if let best { return best }
        if let lastFailure { throw lastFailure }
        return nil
    }

    private func verifyWithServer(
        _ verification: VerificationResult<Transaction>,
        transaction: Transaction,
        generation: UUID
    ) async throws -> BillingResponseDTO {
        let signedRenewalInfo: String?
        if let status = await transaction.subscriptionStatus,
           case .verified = status.renewalInfo {
            signedRenewalInfo = status.renewalInfo.jwsRepresentation
        } else {
            signedRenewalInfo = nil
        }
        try requireCurrentAccount(generation)
        guard let accountName else { throw CancellationError() }
        let response = try await purchaseRepository.verifyAppStorePurchase(
            signedTransaction: verification.jwsRepresentation,
            productID: transaction.productID,
            originalTransactionID: String(transaction.originalID),
            signedRenewalInfo: signedRenewalInfo,
            accountName: accountName
        )
        try requireCurrentAccount(generation)
        return response
    }

    private func entitlementSnapshot(
        for transaction: Transaction,
        serverExpiration: Date?
    ) async -> PremiumEntitlement {
        var renewalState: PremiumRenewalState = .active
        var willAutoRenew = transaction.productType == .autoRenewable

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

    private func requireCurrentAccount(_ generation: UUID) throws {
        try Task.checkCancellation()
        guard generation == accountGeneration, accountName != nil else { throw CancellationError() }
    }

    private func processTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard accountName != nil else { return }
        if isBusy {
            hasPendingVerification = true
            return
        }
        let generation = accountGeneration
        do {
            try await acknowledge(result, generation: generation)
            // A refund/expiration for one product must not remove another active
            // product (including lifetime). Recompute the complete entitlement.
            await refreshEntitlements()
            try requireCurrentAccount(generation)
            await entitlementDidChange?()
        } catch {
            // Unverified or server-unsynchronized transactions remain unfinished for redelivery.
            guard generation == accountGeneration else { return }
            hasPendingVerification = true
            scheduleVerificationRetry()
        }
    }

    private func acknowledge(_ result: VerificationResult<Transaction>, generation: UUID) async throws {
        try requireCurrentAccount(generation)
        let transaction = try checkVerified(result)
        guard Self.recognizedProductIDs.contains(transaction.productID) else { return }
        // A decoded response confirms durable server processing, including an
        // expired or revoked entitlement. Transport/validation errors throw.
        let response = try await verifyWithServer(result, transaction: transaction, generation: generation)
        do { _ = try PurchaseVerificationPolicy.requireActive(response, productID: transaction.productID) }
        catch PurchaseVerificationError.inactiveEntitlement, PurchaseVerificationError.expiredEntitlement {
            // A definitive server rejection completes this obsolete transaction.
        }
        await transaction.finish()
        try requireCurrentAccount(generation)
    }

    private func retryUnfinishedTransactions(generation: UUID) async {
        hasPendingVerification = false
        for await result in Transaction.unfinished {
            do { try await acknowledge(result, generation: generation) }
            catch {
                guard generation == accountGeneration, !Task.isCancelled else { return }
                hasPendingVerification = true
            }
        }
    }

    private func scheduleVerificationRetry() {
        guard hasPendingVerification, accountName != nil, retryTask == nil else { return }
        let generation = accountGeneration
        retryTask = Task { [weak self] in
            for delay in [2, 5, 15, 30] {
                do { try await Task.sleep(for: .seconds(delay)) } catch { break }
                guard let self, generation == self.accountGeneration else { return }
                await self.refreshEntitlements()
                if !self.hasPendingVerification { break }
            }
            guard let self, generation == self.accountGeneration else { return }
            self.retryTask = nil
        }
    }

    private func isLater(_ candidate: PremiumEntitlement, than current: PremiumEntitlement?) -> Bool {
        guard let current else { return true }
        return (candidate.expiration ?? .distantFuture) > (current.expiration ?? .distantFuture)
    }
}
