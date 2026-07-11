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
        guard let expirationTime = response.expirationTime else {
            return nil
        }

        let expiration = Date(timeIntervalSince1970: TimeInterval(expirationTime))
        guard expiration > now else {
            throw PurchaseVerificationError.expiredEntitlement
        }
        return expiration
    }
}
