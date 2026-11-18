import Foundation

public enum PremiumProductCatalog {
    public static let lifetimeID = "com.ekitapligim.app.premium.lifetime"
    /// One-time VIP Premium (non-consumable). Kept out of `productIDs` so a store without it
    /// never affects loading, ordering or availability of the existing plans.
    public static let vipID = "com.ekitapligim.app.premium.vip"
    public static let productIDs = [
        "com.ekitapligim.app.premium.monthly",
        "com.ekitapligim.app.premium.quarterly",
        "com.ekitapligim.app.premium.semiannual",
        "com.ekitapligim.app.premium.yearly",
        lifetimeID
    ]
    // Existing non-renewing purchases keep their original terms and restore rights.
    public static let legacyProductIDs = [
        "com.ekitapligim.app.premium.three_months",
        "com.ekitapligim.app.premium.six_months",
        "com.ekitapligim.app.premium.yearly_once",
        "ekitapligim.premium.monthly",
        "ekitapligim.premium.yearly"
    ]

    /// Products that never expire once verified.
    public static func isLifetime(_ productID: String?) -> Bool {
        productID == lifetimeID || productID == vipID
    }

    public static func subscriptionMonths(for productID: String) -> Int? {
        switch productID {
        case "com.ekitapligim.app.premium.monthly", "ekitapligim.premium.monthly": return 1
        case "com.ekitapligim.app.premium.quarterly": return 3
        case "com.ekitapligim.app.premium.semiannual": return 6
        case "com.ekitapligim.app.premium.yearly", "ekitapligim.premium.yearly": return 12
        default: return nil
        }
    }

    public static func canPurchase(_ productID: String, context: PurchaseAccountDTO) -> Bool {
        guard context.success else { return false }
        // VIP is sold only after the server explicitly confirms it can grant the VIP membership.
        if productID == vipID { return context.supportedProductIds?.contains(vipID) == true }
        guard productIDs.contains(productID) else { return false }
        if let supported = context.supportedProductIds { return supported.contains(productID) }
        // A server predating these IDs would reject a paid transaction. Require
        // explicit support before allowing Apple to charge for either new plan.
        return productID != "com.ekitapligim.app.premium.quarterly"
            && productID != "com.ekitapligim.app.premium.semiannual"
    }

    public static func period(for productID: String) -> String {
        switch subscriptionMonths(for: productID) {
        case 1: return L10n.premiumMonthlyPeriod
        case 3: return L10n.premiumThreeMonthPeriod
        case 6: return L10n.premiumSixMonthPeriod
        case 12: return L10n.premiumYearlyPeriod
        default: return L10n.premiumLifetimePeriod
        }
    }

    public static func tagline(for productID: String) -> String {
        switch subscriptionMonths(for: productID) {
        case 1: return L10n.premiumMonthlyTagline
        case 3: return L10n.premiumThreeMonthTagline
        case 6: return L10n.premiumSixMonthTagline
        case 12: return L10n.premiumYearlyTagline
        default: return L10n.premiumLifetimeTagline
        }
    }
}
