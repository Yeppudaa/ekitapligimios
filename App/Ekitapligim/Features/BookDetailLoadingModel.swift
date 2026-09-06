import Foundation
import Combine
import EkitapligimCore

/// Each section publishes independently; a slow secondary request never hides the book.
@MainActor
final class BookDetailLoadingModel: ObservableObject {
    @Published private(set) var book: BookDTO?
    @Published private(set) var similarBooks: [BookDTO] = []
    @Published var access: ReaderAccessDTO?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published var comments: [BookCommentDTO] = []
    @Published var commentsError: String?
    @Published private(set) var isLoadingComments = false
    @Published private(set) var commentsPage = 0
    @Published private(set) var commentsLastPage = 1

    private var generation = UUID()
    private var detailTask: Task<Void, Never>?
    private var accessTask: Task<Void, Never>?
    private var commentsTask: Task<Void, Never>?
    private var commentsRequestID = UUID()
    private var pendingCommentsReset = false

    func cancel() {
        generation = UUID()
        commentsRequestID = UUID()
        detailTask?.cancel()
        accessTask?.cancel()
        commentsTask?.cancel()
        detailTask = nil
        accessTask = nil
        commentsTask = nil
        pendingCommentsReset = false
        isLoadingComments = false
    }

    func load(
        bookID: Int,
        detail: @escaping @Sendable () async throws -> BookEnvelope,
        access: @escaping @Sendable () async throws -> ReaderAccessDTO,
        comments: @escaping @Sendable (Int) async throws -> BookCommentsPageDTO
    ) async {
        cancel()
        let generation = self.generation
        book = nil
        similarBooks = []
        self.access = nil
        self.comments = []
        commentsPage = 0
        commentsLastPage = 1
        commentsError = nil
        errorMessage = nil
        guard bookID > 0 else {
            isLoading = false
            errorMessage = L10n.bookDetailInvalidId
            return
        }
        isLoading = true
        let detailWork = Task { [weak self] in
            do {
                let result = try await detail()
                guard !Task.isCancelled, let self, self.generation == generation else { return }
                self.book = result.book
                self.similarBooks = Array(result.similarBooks.filter { Int($0.id) != bookID }.prefix(8))
                self.isLoading = false
            } catch {
                guard !Task.isCancelled, let self, self.generation == generation else { return }
                self.errorMessage = L10n.bookDetailLoadFailed
                self.isLoading = false
            }
        }
        let accessWork = Task { [weak self] in
            let result = try? await access()
            guard !Task.isCancelled, let self, self.generation == generation else { return }
            self.access = result
        }
        detailTask = detailWork
        accessTask = accessWork
        await withTaskCancellationHandler {
            async let commentsWork: Void = loadComments(reset: true, fetch: comments, expectedGeneration: generation)
            await detailWork.value
            await accessWork.value
            await commentsWork
        } onCancel: {
            detailWork.cancel()
            accessWork.cancel()
        }
    }

    func loadComments(
        reset: Bool,
        fetch: @escaping @Sendable (Int) async throws -> BookCommentsPageDTO
    ) async {
        await loadComments(reset: reset, fetch: fetch, expectedGeneration: generation)
    }

    private func loadComments(
        reset: Bool,
        fetch: @escaping @Sendable (Int) async throws -> BookCommentsPageDTO,
        expectedGeneration: UUID
    ) async {
        guard !Task.isCancelled, generation == expectedGeneration else { return }
        if let commentsTask {
            // A new comment must refresh after an in-flight page finishes, not race it.
            if reset { pendingCommentsReset = true }
            await commentsTask.value
            return
        }
        let generation = self.generation
        let requestID = UUID()
        commentsRequestID = requestID
        isLoadingComments = true
        commentsError = nil
        let work = Task { [weak self] in
            var shouldReset = reset
            repeat {
                guard !Task.isCancelled, let self, self.generation == generation else { return }
                self.pendingCommentsReset = false
                let page = shouldReset ? 1 : self.commentsPage + 1
                do {
                    let result = try await fetch(page)
                    guard !Task.isCancelled, self.generation == generation else { return }
                    self.comments = shouldReset ? result.comments : self.comments + result.comments.filter { next in
                        !self.comments.contains { $0.id == next.id }
                    }
                    self.commentsPage = result.currentPage
                    self.commentsLastPage = result.lastPage
                    self.commentsError = nil
                } catch {
                    guard !Task.isCancelled, self.generation == generation else { return }
                    self.commentsError = L10n.bookCommentsLoadFailed
                }
                shouldReset = self.pendingCommentsReset
            } while shouldReset
        }
        commentsTask = work
        await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
        guard self.generation == generation, commentsRequestID == requestID else { return }
        commentsTask = nil
        isLoadingComments = false
    }
}
