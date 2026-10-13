import Foundation

public enum PurchaseOfferDecision: Equatable, Sendable {
    case allowed
    case alreadyLifetime
    case warnExistingSubscription
    case warnStartingSubscription
}

public enum PurchaseOfferPolicy {
    public static let lifetimeID = PremiumProductCatalog.lifetimeID
    private static let subscriptions = Set(
        (PremiumProductCatalog.productIDs + PremiumProductCatalog.legacyProductIDs)
            .filter { PremiumProductCatalog.subscriptionMonths(for: $0) != nil }
    )

    public static func decision(productID: String, context: PurchaseAccountDTO,
                                entitlement: PremiumEntitlement, now: Date = Date()) -> PurchaseOfferDecision {
        let active = entitlement.isActive(at: now)
        let lifetime = context.hasLifetime ?? (active && entitlement.productID == lifetimeID)
        if lifetime { return .alreadyLifetime }
        let renewable = context.hasActiveSubscription
            ?? (active && subscriptions.contains(entitlement.productID ?? ""))
        if renewable && !subscriptions.contains(productID) { return .warnExistingSubscription }
        let fixed = context.hasFixedTerm
            ?? (active && !subscriptions.contains(entitlement.productID ?? "") && entitlement.productID != lifetimeID)
        if fixed && subscriptions.contains(productID) { return .warnStartingSubscription }
        return .allowed
    }

    public static func displayedExpiration(entitlement: PremiumEntitlement, serverExpiration: Int?) -> Date? {
        if entitlement.isActive && entitlement.productID == lifetimeID { return nil }
        return entitlement.expiration ?? serverExpiration.flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
    }
}
