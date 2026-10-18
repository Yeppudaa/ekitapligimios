import Foundation

public enum PremiumDesignL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "PremiumDesign", bundle: .module, comment: "Premium presentation")
    }
}
