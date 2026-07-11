import Foundation

public struct ReaderBookmark: Codable, Equatable, Identifiable, Sendable {
    public let bookID: Int
    public let page: Int
    public let createdAt: Date

    public var id: String { "\(bookID):\(page)" }

    public init(bookID: Int, page: Int, createdAt: Date = Date()) {
        self.bookID = bookID
        self.page = max(1, page)
        self.createdAt = createdAt
    }
}

public struct ReaderBookmarks: Codable, Equatable, Sendable {
    public private(set) var items: [ReaderBookmark]

    public init(items: [ReaderBookmark] = []) {
        self.items = Self.normalized(items)
    }

    public func bookmarks(for bookID: Int) -> [ReaderBookmark] {
        items.filter { $0.bookID == bookID }
    }

    public func contains(bookID: Int, page: Int) -> Bool {
        items.contains { $0.bookID == bookID && $0.page == page }
    }

    public mutating func toggle(bookID: Int, page: Int, createdAt: Date = Date()) {
        let normalizedPage = max(1, page)
        if let index = items.firstIndex(where: { $0.bookID == bookID && $0.page == normalizedPage }) {
            items.remove(at: index)
        } else {
            items.append(ReaderBookmark(bookID: bookID, page: normalizedPage, createdAt: createdAt))
            items = Self.normalized(items)
        }
    }

    public mutating func remove(bookID: Int, page: Int) {
        items.removeAll { $0.bookID == bookID && $0.page == page }
    }

    private static func normalized(_ items: [ReaderBookmark]) -> [ReaderBookmark] {
        var unique: [String: ReaderBookmark] = [:]
        for item in items {
            unique[item.id] = item
        }
        return unique.values.sorted {
            if $0.bookID == $1.bookID { return $0.page < $1.page }
            return $0.bookID < $1.bookID
        }
    }
}
