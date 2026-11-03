import Foundation

public enum CommunityDesignL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "CommunityDesign", bundle: .module, comment: "Reader community design")
    }
}
