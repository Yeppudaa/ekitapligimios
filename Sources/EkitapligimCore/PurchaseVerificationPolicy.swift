import Foundation

public enum PurchaseVerificationError: Error, Equatable, Sendable {
    case inactiveEntitlement
    case expiredEntitlement
}

public enum PurchaseVerificationPolicy {
    public static func requireActive(
        _ response: BillingResponseDTO,
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
            return nil
        }

        let expiration = Date(timeIntervalSince1970: TimeInterval(effectiveExpirationTime))
        guard expiration > now else {
            throw PurchaseVerificationError.expiredEntitlement
        }
        return expiration
    }
}
