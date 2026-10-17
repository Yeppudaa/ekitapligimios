import Foundation

public enum HomeRefreshL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "HomeRefresh", bundle: .module, comment: "Modern home, catalog and personal library")
    }

    public static func booksWithYou(_ count: Int) -> String {
        String(format: text("library.booksWithYou"), locale: Locale.current, count)
    }

    public static func page(_ number: Int) -> String {
        String(format: text("continue.page"), locale: Locale.current, number)
    }
}

public enum HomeEditorialSelection {
    /// Pick once per pool and keep it stable through search, scroll and refresh.
    public static func select(from books: [BookDTO], retaining currentID: String?) -> BookDTO? {
        var seen = Set<String>()
        let candidates = books.filter {
            !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seen.insert($0.id).inserted
        }
        if let currentID, let current = candidates.first(where: { $0.id == currentID }) { return current }
        return candidates.randomElement()
    }
}
