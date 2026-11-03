import Foundation

/// A small, refreshable selection from the Roman catalog, using the existing permission-aware API.
public struct HomeNovelRepository: Sendable {
    private let catalog: any BookRepositoryProtocol
    private let choosePage: @Sendable (ClosedRange<Int>) -> Int
    private static let categoryID = "6"
    private static let selectionCount = 4

    public init(
        catalog: any BookRepositoryProtocol,
        choosePage: @escaping @Sendable (ClosedRange<Int>) -> Int = { Int.random(in: $0) }
    ) {
        self.catalog = catalog
        self.choosePage = choosePage
    }

    public func books() async throws -> [BookDTO] {
        try Task.checkCancellation()
        let firstPage = try await page(1)
        try Task.checkCancellation()
        let lastPage = max(1, firstPage.lastPage)
        let selectedPage = min(lastPage, max(1, choosePage(1...lastPage)))
        var candidates = firstPage.books
        if selectedPage > 1 {
            do {
                let selected = try await page(selectedPage)
                try Task.checkCancellation()
                candidates = selected.books
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A changing catalog or transient failure may use the first Roman page only.
                try Task.checkCancellation()
            }
        }

        var pool = uniqueBooks(candidates)
        if pool.count < Self.selectionCount {
            pool = uniqueBooks(pool + firstPage.books)
        }
        return Array(pool.shuffled().prefix(Self.selectionCount))
    }

    private func page(_ number: Int) async throws -> BooksPageDTO {
        try await catalog.books(
            page: number, query: nil, category: Self.categoryID, author: nil,
            publisher: nil, isbn: nil, order: "latest", premiumOnly: false
        )
    }

    private func uniqueBooks(_ books: [BookDTO]) -> [BookDTO] {
        var seen = Set<String>()
        return books.filter {
            !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && seen.insert($0.id).inserted
        }
    }
}
