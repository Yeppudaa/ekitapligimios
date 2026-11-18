import Foundation

public enum PurchaseOfferDecision: Equatable, Sendable {
    case allowed
    case alreadyLifetime
    case alreadyVip
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
        let vip = context.hasVipSupporter ?? (active && entitlement.productID == PremiumProductCatalog.vipID)
        if vip { return .alreadyVip }
        let renewable = context.hasActiveSubscription
            ?? (active && subscriptions.contains(entitlement.productID ?? ""))
        // Lifetime Premium members may upgrade to VIP; only a renewing subscription needs a notice.
        if productID == PremiumProductCatalog.vipID { return renewable ? .warnExistingSubscription : .allowed }
        let lifetime = context.hasLifetime ?? (active && entitlement.productID == lifetimeID)
        if lifetime { return .alreadyLifetime }
        if renewable && !subscriptions.contains(productID) { return .warnExistingSubscription }
        let fixed = context.hasFixedTerm
            ?? (active && !subscriptions.contains(entitlement.productID ?? "")
                && !PremiumProductCatalog.isLifetime(entitlement.productID))
        if fixed && subscriptions.contains(productID) { return .warnStartingSubscription }
        return .allowed
    }

    public static func displayedExpiration(entitlement: PremiumEntitlement, serverExpiration: Int?) -> Date? {
        if entitlement.isActive && PremiumProductCatalog.isLifetime(entitlement.productID) { return nil }
        return entitlement.expiration ?? serverExpiration.flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
    }
}
