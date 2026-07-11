import Foundation
import StoreKit
import EkitapligimCore

@MainActor
final class StoreKitPurchaseService: ObservableObject {
    @Published private(set) var state: PurchaseState = .notLoaded

    private let productIDs = ["ekitapligim.premium.monthly", "ekitapligim.premium.yearly"]
    private let purchaseRepository: PurchaseRepository
    private var loadedProducts: [StoreProduct] = []
    private var updatesTask: Task<Void, Never>?

    init(purchaseRepository: PurchaseRepository) {
        self.purchaseRepository = purchaseRepository
    }

    func startObservingTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard !Task.isCancelled else { break }
                await self?.processTransactionUpdate(update)
            }
        }
    }

    func stopObservingTransactions() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    func loadProducts() async {
        state = .loading
        do {
            let products = try await Product.products(for: productIDs)
            loadedProducts = products.map {
                StoreProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
            }
            state = .available(products: loadedProducts)
        } catch {
            state = .failed(message: L10n.premiumProductsFailed)
        }
    }

    func purchase(productID: String) async {
        do {
            guard let product = try await Product.products(for: [productID]).first else {
                state = .failed(message: L10n.premiumProductMissing)
                return
            }
            state = .purchasing(productID: productID)
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let response = try await purchaseRepository.verifyAppStorePurchase(
                    signedTransaction: transaction.jwsRepresentation,
                    productID: transaction.productID,
                    originalTransactionID: String(transaction.originalID)
                )
                let serverExpiration = try PurchaseVerificationPolicy.requireActive(response)
                await transaction.finish()
                state = .purchased(
                    productID: transaction.productID,
                    expiration: serverExpiration ?? transaction.expirationDate
                )
            case .pending:
                state = .pending
            case .userCancelled:
                state = .available(products: loadedProducts)
            @unknown default:
                state = .failed(message: L10n.premiumPurchaseFailed)
            }
        } catch {
            state = .failed(message: L10n.premiumVerificationFailed)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            var restoredProductID: String?
            for await entitlement in Transaction.currentEntitlements {
                let transaction = try checkVerified(entitlement)
                guard productIDs.contains(transaction.productID), transaction.revocationDate == nil else { continue }
                if let expiration = transaction.expirationDate, expiration <= Date() { continue }
                let response = try await purchaseRepository.verifyAppStorePurchase(
                    signedTransaction: transaction.jwsRepresentation,
                    productID: transaction.productID,
                    originalTransactionID: String(transaction.originalID)
                )
                _ = try PurchaseVerificationPolicy.requireActive(response)
                restoredProductID = transaction.productID
            }
            guard restoredProductID != nil else {
                state = .failed(message: L10n.premiumNothingToRestore)
                return
            }
            state = .restored
        } catch {
            state = .failed(message: L10n.premiumRestoreFailed)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreKitError.notAvailableInStorefront
        }
    }

    private func processTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            guard productIDs.contains(transaction.productID) else { return }

            let response = try await purchaseRepository.verifyAppStorePurchase(
                signedTransaction: transaction.jwsRepresentation,
                productID: transaction.productID,
                originalTransactionID: String(transaction.originalID)
            )

            do {
                let serverExpiration = try PurchaseVerificationPolicy.requireActive(response)
                await transaction.finish()
                state = .purchased(
                    productID: transaction.productID,
                    expiration: serverExpiration ?? transaction.expirationDate
                )
            } catch is PurchaseVerificationError {
                // The server verified and recorded the inactive transaction.
                await transaction.finish()
                state = loadedProducts.isEmpty ? .notLoaded : .available(products: loadedProducts)
            }
        } catch {
            // Leave unverified or unsynced transactions unfinished so StoreKit can redeliver them.
        }
    }
}
