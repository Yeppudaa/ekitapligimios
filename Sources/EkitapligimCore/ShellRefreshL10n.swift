import Foundation

public enum ShellRefreshL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "ShellRefresh", bundle: .module, comment: "Modern app shell and personal shelves")
    }

    public static func count(_ value: Int) -> String {
        String(format: text("booksCount"), locale: Locale.current, value)
    }

    public static func remainingDays(_ days: Int) -> String {
        String(format: text("daysRemaining"), locale: Locale.current, days)
    }
}
