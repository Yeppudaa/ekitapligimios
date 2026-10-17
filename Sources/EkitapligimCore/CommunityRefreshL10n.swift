import Foundation

/// Copy for the native community artwork, discovery and collection layouts.
public enum CommunityRefreshL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "CommunityRefresh", bundle: .module, comment: "Community visual refresh")
    }
    public static func count(_ key: String, _ value: Int) -> String {
        String(format: text(key), value)
    }
}
