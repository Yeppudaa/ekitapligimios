import Foundation

public extension L10n {
    private static func purchaseSafety(_ key: String) -> String {
        NSLocalizedString(key, tableName: "PurchaseSafety", bundle: .module, comment: "Premium purchase protection")
    }
    static var premiumAlreadyLifetime: String { purchaseSafety("alreadyLifetime") }
    static var premiumPurchaseNoticeTitle: String { purchaseSafety("noticeTitle") }
    static var premiumExistingSubscriptionNotice: String { purchaseSafety("existingSubscription") }
    static var premiumStartingSubscriptionNotice: String { purchaseSafety("startingSubscription") }
    static var premiumContinuePurchase: String { purchaseSafety("continuePurchase") }
    static var premiumFixedTermCarryover: String { purchaseSafety("fixedTermCarryover") }
}
