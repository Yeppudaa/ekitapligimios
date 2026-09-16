import Foundation

public enum AIL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "AI", bundle: .module, comment: "AI Assistant")
    }
    public static var newConversation: String { text("newConversation") }
    public static var expiredAction: String { text("expiredAction") }
    public static var invalidInput: String { text("invalidInput") }
    public static var uncertainSend: String { text("uncertainSend") }
    public static var unavailable: String { text("unavailable") }
    public static var sessionRequired: String { text("sessionRequired") }
    public static var permissionDenied: String { text("permissionDenied") }
    public static var notFound: String { text("notFound") }
    public static var limitReached: String { text("limitReached") }
    public static var connectionError: String { text("connectionError") }
    public static func quota(_ remaining: Int, _ limit: Int) -> String {
        String(format: text("quotaFormat"), remaining, limit)
    }
    public static func remaining(_ remaining: Int, _ limit: Int) -> String {
        String(format: text("remainingFormat"), remaining, limit)
    }
}
