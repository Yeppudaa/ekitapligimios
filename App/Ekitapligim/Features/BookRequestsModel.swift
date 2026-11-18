import Foundation
import Combine
import EkitapligimCore

struct BookRequestsDependencies: Sendable {
    var fetch: @Sendable (Int) async throws -> BookRequestsPageDTO
    var create: @Sendable (String, String, String) async throws -> BookRequestDTO
    var vote: @Sendable (String) async throws -> BookRequestVoteDTO
    init(repository: BookRequestsRepository) {
        fetch = { try await repository.requests(page: $0) }
        create = { try await repository.create(title: $0, author: $1, isbn: $2) }
        vote = { try await repository.toggleVote(id: $0) }
    }
    init(fetch: @escaping @Sendable (Int) async throws -> BookRequestsPageDTO,
         create: @escaping @Sendable (String, String, String) async throws -> BookRequestDTO,
         vote: @escaping @Sendable (String) async throws -> BookRequestVoteDTO) {
        self.fetch = fetch; self.create = create; self.vote = vote
    }
}

@MainActor
final class BookRequestsModel: ObservableObject {
    @Published private(set) var items: [BookRequestDTO] = []
    @Published private(set) var quota: BookRequestQuotaDTO?
    /// Site-wide totals from the server; nil only for servers that predate them.
    @Published private(set) var stats: BookRequestStatsDTO?
    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingMore = false
    private var currentPage = 1
    @Published private(set) var isLoading = true
    @Published private(set) var isSubmitting = false
    @Published private(set) var votingID: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var createError: String?
    @Published var operationError: String?
    @Published var statusMessage: String?
    @Published var draftTitle = ""
    @Published var draftAuthor = ""
    @Published var draftISBN = ""
    @Published private(set) var accessExplanation: BookRequestAccessPresentation?
    private var generation = UUID()
    private var loadRevision = UUID()
    private var dependencies: BookRequestsDependencies?
    private var sessionID: UUID?
    private var signedIn = false

    func configure(_ dependencies: BookRequestsDependencies, session: UUID, signedIn: Bool) {
        self.dependencies = dependencies
        guard session != sessionID || signedIn != self.signedIn else { return }
        generation = UUID(); loadRevision = UUID(); sessionID = session; self.signedIn = signedIn
        items = []; quota = nil; stats = nil; hasMore = false; isLoadingMore = false; currentPage = 1
        isLoading = true; isSubmitting = false; votingID = nil
        errorMessage = nil; createError = nil; operationError = nil; statusMessage = nil
        draftTitle = ""; draftAuthor = ""; draftISBN = ""; accessExplanation = nil
    }

    func prepareCreation() -> BookRequestAccessPresentation? {
        createError = nil
        accessExplanation = quota?.explanation
        return accessExplanation
    }

    func load(afterMutation: Bool = false) async {
        guard let dependencies, !Task.isCancelled,
              afterMutation || (!isSubmitting && votingID == nil) else { return }
        let generation = self.generation
        let revision = UUID(); loadRevision = revision
        isLoading = true; isLoadingMore = false; errorMessage = nil
        defer { if generation == self.generation, revision == loadRevision { isLoading = false } }
        do {
            let response = try await dependencies.fetch(1)
            guard generation == self.generation, revision == loadRevision, !Task.isCancelled else { return }
            var ids = Set<String>()
            items = response.items.filter { ids.insert($0.id).inserted }
            quota = response.requestQuota
            stats = response.stats
            currentPage = response.page
            hasMore = response.hasMore
        } catch {
            guard generation == self.generation, revision == loadRevision, !Task.isCancelled else { return }
            errorMessage = L10n.bookRequestsLoadFailed
        }
    }

    /// Appends the next server page; a refresh or mutation reload supersedes it.
    func loadMore() async {
        guard let dependencies, hasMore, !isLoading, !isLoadingMore, !isSubmitting, votingID == nil,
              !Task.isCancelled else { return }
        let generation = self.generation
        let revision = loadRevision
        let nextPage = currentPage + 1
        isLoadingMore = true; errorMessage = nil
        defer { if generation == self.generation, revision == loadRevision { isLoadingMore = false } }
        do {
            let response = try await dependencies.fetch(nextPage)
            guard generation == self.generation, revision == loadRevision, !Task.isCancelled else { return }
            var ids = Set(items.map(\.id))
            items += response.items.filter { ids.insert($0.id).inserted }
            if let latest = response.stats { stats = latest }
            if let latestQuota = response.requestQuota { quota = latestQuota }
            currentPage = max(nextPage, response.page)
            // A short or repeated page must not leave an endless "load more" button.
            hasMore = response.hasMore && !response.items.isEmpty
        } catch {
            guard generation == self.generation, revision == loadRevision, !Task.isCancelled else { return }
            errorMessage = L10n.bookRequestsLoadFailed
        }
    }

    func submit() async -> Bool {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = draftAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        let isbn = draftISBN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let dependencies, signedIn, !Task.isCancelled, !isSubmitting, votingID == nil,
              !title.isEmpty, !author.isEmpty else { return false }
        if let explanation = quota?.explanation { accessExplanation = explanation; return false }
        let generation = self.generation
        let draft = (draftTitle, draftAuthor, draftISBN)
        loadRevision = UUID(); isLoading = false; isSubmitting = true; createError = nil; accessExplanation = nil
        defer { if generation == self.generation { isSubmitting = false } }
        do {
            let created = try await dependencies.create(title, author, isbn)
            guard generation == self.generation, !Task.isCancelled else { return false }
            guard !created.id.isEmpty else { throw APIClientError.invalidResponse }
            if !items.contains(where: { $0.id == created.id }) { items.insert(created, at: 0) }
            if draft == (draftTitle, draftAuthor, draftISBN) { draftTitle = ""; draftAuthor = ""; draftISBN = "" }
            statusMessage = L10n.bookRequestsCreated
            await load(afterMutation: true)
            return generation == self.generation && !Task.isCancelled
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return false }
            createError = L10n.bookRequestsCreateFailed
            if case APIClientError.httpStatus(_, let envelope) = error,
               let code = envelope?.errors.first?.code {
                if code == "premium_required" { accessExplanation = .membership }
                if code == "book_request_monthly_limit" {
                    // Re-read the server's quota; never guess a limit or renewal date from an HTTP status.
                    await load(afterMutation: true)
                    guard generation == self.generation, !Task.isCancelled else { return false }
                    accessExplanation = quota?.explanation
                    createError = ReadingRoomL10n.text("request.limitChanged")
                }
            }
            return false
        }
    }

    func vote(_ item: BookRequestDTO) async {
        guard let dependencies, signedIn, !Task.isCancelled, !isSubmitting, votingID == nil, item.allowsVote else { return }
        let generation = self.generation
        loadRevision = UUID(); isLoading = false; votingID = item.id; operationError = nil
        defer { if generation == self.generation { votingID = nil } }
        do {
            let response = try await dependencies.vote(item.id)
            guard generation == self.generation, !Task.isCancelled else { return }
            guard response.success else { throw APIClientError.invalidResponse }
            statusMessage = L10n.bookRequestsVoteSaved
            await load(afterMutation: true)
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return }
            operationError = L10n.bookRequestsVoteFailed
        }
    }

    func removeUser(_ id: Int) { items.removeAll { $0.userId == id } }
}
