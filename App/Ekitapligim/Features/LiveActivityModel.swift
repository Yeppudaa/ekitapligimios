import Foundation
import Combine
import EkitapligimCore

/// Server activity is authoritative. Mutations only invalidate the feed; they never insert invented rows.
@MainActor
final class LiveActivityModel: ObservableObject {
    typealias LoadPage = @Sendable (Int, Int?, String?) async throws -> LiveActivityPageDTO

    @Published private(set) var items: [LiveActivityItemDTO] = []
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?

    private enum Request: Equatable { case reset, more, latest }
    private var loadPage: LoadPage?
    private var sessionID: UUID?
    private var userID: String?
    private var generation = UUID()
    private var nextBefore: Int?
    private var inFlight = false
    private var queuedRefresh: Request?

    func configure(repository: LiveActivityRepository, sessionID: UUID, userID: String?) {
        configure(loadPage: { try await repository.activity(limit: $0, before: $1, userID: $2) },
                  sessionID: sessionID, userID: userID)
    }

    func configure(loadPage: @escaping LoadPage, sessionID: UUID, userID: String?) {
        self.loadPage = loadPage
        guard self.sessionID != sessionID || self.userID != userID else { return }
        self.sessionID = sessionID
        self.userID = userID
        generation = UUID()
        items = []
        nextBefore = nil
        hasMore = false
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        inFlight = false
        queuedRefresh = nil
    }

    func load(reset: Bool) async {
        if !reset { guard hasMore, nextBefore != nil else { return } }
        await request(reset ? .reset : .more)
    }

    func refreshLatest() async { await request(.latest) }

    /// One request runs at a time, with one queued refresh. A successful write during a load
    /// therefore always triggers a subsequent server read, even when the first response is stale.
    private func request(_ requested: Request) async {
        guard let loadPage else { return }
        if inFlight {
            switch requested {
            case .reset: queuedRefresh = .reset
            case .latest: if queuedRefresh == nil { queuedRefresh = .latest }
            case .more: break
            }
            return
        }

        let requestGeneration = generation
        var current = requested
        while !Task.isCancelled, generation == requestGeneration {
            inFlight = true
            isLoading = current == .reset
            isLoadingMore = current == .more
            if current != .latest { errorMessage = nil }
            do {
                let page = try await loadPage(20, current == .more ? nextBefore : nil, userID)
                guard generation == requestGeneration else { return }
                if !Task.isCancelled { apply(page, for: current) }
            } catch is CancellationError {
                // Leaving the page does not replace a usable timeline with an error.
            } catch {
                guard generation == requestGeneration else { return }
                if !Task.isCancelled, current != .latest { errorMessage = L10n.liveActivityLoadFailed }
            }
            guard generation == requestGeneration else { return }
            inFlight = false
            isLoading = false
            isLoadingMore = false
            guard let next = queuedRefresh else { return }
            queuedRefresh = nil
            if Task.isCancelled {
                // The old view task can finish after a new visible view has already requested
                // its refresh. Transfer that work out of the cancelled caller's task.
                Task {
                    guard generation == requestGeneration else { return }
                    await request(next)
                }
                return
            }
            current = next
        }
    }

    private func apply(_ page: LiveActivityPageDTO, for request: Request) {
        let incoming = unique(page.items)
        switch request {
        case .reset:
            items = incoming
            nextBefore = page.nextBefore
            hasMore = page.hasMore && page.nextBefore != nil
        case .more:
            let existing = Set(items.map(\.id))
            items += incoming.filter { !existing.contains($0.id) }
            nextBefore = page.nextBefore
            hasMore = page.hasMore && page.nextBefore != nil
        case .latest:
            let wasEmpty = items.isEmpty
            let incomingIDs = Set(incoming.map(\.id))
            items = incoming + items.filter { !incomingIDs.contains($0.id) }
            if wasEmpty {
                nextBefore = page.nextBefore
                hasMore = page.hasMore && page.nextBefore != nil
            }
        }
        errorMessage = nil
    }

    private func unique(_ rows: [LiveActivityItemDTO]) -> [LiveActivityItemDTO] {
        var seen: Set<String> = []
        return rows.filter { seen.insert($0.id).inserted }
    }
}
