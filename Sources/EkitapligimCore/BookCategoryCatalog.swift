import Foundation

/// Shared catalog taxonomy, in the same discovery order as Android's defaultBookCategoryForums.
/// These are filter destinations; book availability and permissions remain server decisions.
public enum BookCategoryCatalog {
    private static let orderedIDs = (6...38).filter { $0 != 31 }.map(String.init)
    private static let knownIDs = Set(orderedIDs)

    public static var defaults: [ForumDTO] {
        orderedIDs.map { id in
            ForumDTO(
                id: id,
                title: NSLocalizedString(id, tableName: "BookCategories", bundle: .module, comment: "Book genre"),
                isBookForum: true
            )
        }
    }

    /// An empty or partial forum response must not erase the catalog's genre destinations.
    /// Counts are included only when supplied by a valid live record.
    public static func merging(live: [ForumDTO]) -> [ForumDTO] {
        var updates: [String: ForumDTO] = [:]
        for forum in live where knownIDs.contains(forum.id) && updates[forum.id] == nil {
            let title = forum.title
                .replacingOccurrences(of: "📚", with: "")
                .replacingOccurrences(of: "📖", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.caseInsensitiveCompare("Genel") != .orderedSame else { continue }
            updates[forum.id] = ForumDTO(
                id: forum.id,
                title: title,
                description: forum.description,
                url: forum.url,
                stats: forum.stats,
                threadCount: forum.threadCount.flatMap { $0 >= 0 ? $0 : nil },
                isBookForum: true
            )
        }
        return defaults.map { updates[$0.id] ?? $0 }
    }

    public static func sorted(_ categories: [ForumDTO], locale: Locale = Locale(identifier: "tr_TR")) -> [ForumDTO] {
        categories.sorted { lhs, rhs in
            let comparison = lhs.title.compare(rhs.title, locale: locale)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        }
    }
}
