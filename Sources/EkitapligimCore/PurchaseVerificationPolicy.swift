import Foundation

public enum PurchaseVerificationError: Error, Equatable, Sendable {
    case inactiveEntitlement
    case expiredEntitlement
    case missingExpiration
}

public enum PurchaseVerificationPolicy {
    public static func failureMessage(for error: Error, restoring: Bool = false) -> String {
        if isLinkedAccountError(error) { return L10n.premiumLinkedToAnotherAccount }
        return restoring ? L10n.premiumRestoreFailed : L10n.premiumVerificationFailed
    }

    public static func isLinkedAccountError(_ error: Error) -> Bool {
        if case APIClientError.httpStatus(_, let envelope) = error,
           envelope?.errors.contains(where: { $0.code == "original_transaction_already_linked" }) == true {
            return true
        }
        return false
    }

    public static func requireActive(
        _ response: BillingResponseDTO,
        productID: String? = nil,
        now: Date = Date()
    ) throws -> Date? {
        guard response.success, response.isPremium else {
            throw PurchaseVerificationError.inactiveEntitlement
        }
        let effectiveExpirationTime = max(
            response.expirationTime ?? 0,
            response.gracePeriodExpirationTime ?? 0
        )
        guard effectiveExpirationTime > 0 else {
            if let productID, productID != "com.ekitapligim.app.premium.lifetime" {
                throw PurchaseVerificationError.missingExpiration
            }
            return nil
        }

        let expiration = Date(timeIntervalSince1970: TimeInterval(effectiveExpirationTime))
        guard expiration > now else {
            throw PurchaseVerificationError.expiredEntitlement
        }
        return expiration
    }
}
