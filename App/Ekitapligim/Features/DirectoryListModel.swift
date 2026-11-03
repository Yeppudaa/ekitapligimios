import Foundation
import Combine
import EkitapligimCore

@MainActor
final class DirectoryListModel: ObservableObject {
    /// A display batch counts matching entries, not the server's contains-search candidates.
    static let matchingBatchSize = 30
    typealias LoadPage = @Sendable (Int, String?) async throws -> DirectoryPageDTO
    typealias LoadStats = @Sendable () async throws -> SiteStatsDTO

    @Published private(set) var items: [DirectoryItemDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var totalEntries = 0
    @Published private(set) var totalBooks = 0
    private(set) var currentPage = 0
    private(set) var filter = DirectoryFilter()
    private var generation = UUID()
    private var loadPage: LoadPage?
    private var loadStats: LoadStats?
    private var stats: SiteStatsDTO?
    private var kind = DirectoryKind.author
    private var requestTask: Task<Void, Never>?
    private let now: () -> Date
    private var snapshots: [DirectoryFilter: Snapshot] = [:]
    private var recentlyUsed: [DirectoryFilter] = []
    private struct Snapshot {
        let items: [DirectoryItemDTO]
        let page: Int
        let hasMore: Bool
        let date: Date
    }

    init(now: @escaping () -> Date = Date.init) { self.now = now }

    func configure(kind: DirectoryKind, repository: DirectoryRepository, site: SiteRepository) {
        configure(kind: kind, loadPage: { try await repository.items(kind: kind, page: $0, query: $1, perPage: 100) },
                  loadStats: { try await site.stats() })
    }

    func configure(kind: DirectoryKind, loadPage: @escaping LoadPage, loadStats: @escaping LoadStats) {
        if self.kind != kind {
            cancelLoading()
            snapshots = [:]; recentlyUsed = []; stats = nil
            items = []; currentPage = 0; hasMore = false
            totalEntries = 0; totalBooks = 0; errorMessage = nil
        }
        self.kind = kind
        self.loadPage = loadPage
        self.loadStats = loadStats
    }

    /// Invalidate old responses immediately, including during the search debounce.
    func select(_ selection: DirectoryFilter) {
        guard filter != selection else { return }
        requestTask?.cancel()
        generation = UUID()
        filter = selection
        items = []
        currentPage = 0
        hasMore = false
        errorMessage = nil
        isLoading = true
    }

    func cancelLoading() {
        requestTask?.cancel()
        requestTask = nil
        generation = UUID()
        isLoading = false
    }

    /// Independent from page loading: slow optional counters never gate the first rows.
    func loadStatistics() async {
        guard stats == nil, let loadStats else { return }
        let requestedKind = kind
        guard let result = try? await loadStats(), !Task.isCancelled, kind == requestedKind else { return }
        stats = result
        let entries = kind == .author ? result.totalAuthors : result.totalPublishers
        if entries > 0 { totalEntries = entries }
        if result.totalBooks > 0 { totalBooks = result.totalBooks }
    }

    func hasFreshSnapshot(for selection: DirectoryFilter) -> Bool {
        guard let snapshot = snapshots[selection] else { return false }
        let age = now().timeIntervalSince(snapshot.date)
        return age >= 0 && age < 120
    }

    func load(filter selection: DirectoryFilter, reset: Bool, forceRefresh: Bool = false) async {
        select(selection)
        guard let loadPage, reset || (!isLoading && hasMore) else { return }
        if reset, !forceRefresh, hasFreshSnapshot(for: selection), let snapshot = snapshots[selection] {
            cancelLoading()
            items = snapshot.items; currentPage = snapshot.page; hasMore = snapshot.hasMore
            errorMessage = nil
            touch(selection)
            return
        }
        if forceRefresh { snapshots[selection] = nil }
        requestTask?.cancel()
        let requestID = UUID()
        generation = requestID
        isLoading = true
        errorMessage = nil
        if reset {
            items = []
            currentPage = 0
            hasMore = false
        }
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.collect(selection: selection, requestID: requestID, loadPage: loadPage)
        }
        // Explicit cancellation also stops a load-more task created by a button, not
        // just SwiftUI's automatically cancelled filter task and its URLSession request.
        requestTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: { task.cancel() }
        if generation == requestID { requestTask = nil }
    }

    private func collect(selection: DirectoryFilter, requestID: UUID, loadPage: LoadPage) async {
        defer { if generation == requestID { isLoading = false } }
        let initialCount = items.count
        let minimumMatches = selection.letter == "#" ? 1 : Self.matchingBatchSize
        do {
            try Task.checkCancellation()
            var requestedPage = currentPage + 1
            var result = try await loadPage(requestedPage, selection.remoteQuery)
            while true {
                guard generation == requestID, !Task.isCancelled else { return }
                // A repeated/malformed cursor must not trap a letter search in an endless loop.
                guard result.currentPage == requestedPage else { throw DirectoryLoadError.invalidPage }
                var seen = Set(items.map(\.id))
                let matching = result.items.filter { selection.matches($0) && seen.insert($0.id).inserted }
                items += matching
                currentPage = requestedPage
                hasMore = requestedPage < max(1, result.lastPage)
                applyTotals(result)
                // A candidate page may contain only one matching initial. Keep collecting a
                // useful batch, publishing each page as it arrives. Never truncate a page or
                // impose a total-result cap; the next batch resumes at the next server cursor.
                guard items.count - initialCount < minimumMatches, hasMore else {
                    remember(selection)
                    return
                }
                requestedPage += 1
                result = try await loadPage(requestedPage, selection.remoteQuery)
            }
        } catch is CancellationError {
            // The next selection owns its own request and loading state.
        } catch {
            guard generation == requestID, !Task.isCancelled else { return }
            errorMessage = L10n.directoryLoadFailed
        }
    }

    private func touch(_ selection: DirectoryFilter) {
        recentlyUsed.removeAll { $0 == selection }
        recentlyUsed.append(selection)
    }

    private func remember(_ selection: DirectoryFilter) {
        // Screen/account scoped and memory-only. Avoid retaining huge fully expanded lists.
        guard items.count <= 2_000 else { snapshots[selection] = nil; return }
        snapshots[selection] = Snapshot(items: items, page: currentPage, hasMore: hasMore, date: now())
        touch(selection)
        while recentlyUsed.count > 6 { snapshots[recentlyUsed.removeFirst()] = nil }
    }

    private func applyTotals(_ result: DirectoryPageDTO) {
        let globalEntries = kind == .author ? stats?.totalAuthors : stats?.totalPublishers
        if let globalEntries, globalEntries > 0 {
            totalEntries = globalEntries
        } else if filter.isUnfiltered {
            totalEntries = max(result.total, items.count)
        } else {
            totalEntries = max(totalEntries, items.count)
        }
        if let globalBooks = stats?.totalBooks, globalBooks > 0 {
            totalBooks = globalBooks
        } else {
            totalBooks = max(totalBooks, items.reduce(0) { $0 + $1.bookCount })
        }
    }
}

private enum DirectoryLoadError: Error { case invalidPage }
