import Foundation
import Combine
import EkitapligimCore

/// Keeps comment drafts and mutations isolated from stale loads and account changes.
@MainActor
final class BookAgendaDetailModel: ObservableObject {
    @Published private(set) var post: BookAgendaPostDTO?
    @Published private(set) var comments: [BookAgendaCommentDTO] = []
    @Published var draft = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingComments = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var isPerformingAction = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var commentsError: String?
    @Published private(set) var actionMessage: String?

    private var generation = UUID()
    private var commentsRevision = UUID()

    func invalidate(clear: Bool = true) {
        generation = UUID()
        commentsRevision = UUID()
        isLoading = false
        isLoadingComments = false
        isSubmitting = false
        isPerformingAction = false
        if clear {
            post = nil
            comments = []
            draft = ""
            errorMessage = nil
            commentsError = nil
            actionMessage = nil
        }
    }

    func load(
        fetchPost: @escaping @Sendable () async throws -> BookAgendaPostDTO,
        fetchComments: @escaping @Sendable () async throws -> [BookAgendaCommentDTO]
    ) async {
        invalidate(clear: false)
        let generation = self.generation
        isLoading = true
        errorMessage = nil
        defer { if generation == self.generation { isLoading = false } }
        do {
            let loaded = try await fetchPost()
            guard generation == self.generation, !Task.isCancelled else { return }
            post = loaded
            comments = unique(loaded.comments)
            // Always fetch the dedicated list: the post payload may contain only a preview.
            await loadComments(fetch: fetchComments)
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return }
            errorMessage = L10n.agendaDetailErrorMessage
        }
    }

    func loadComments(fetch: @escaping @Sendable () async throws -> [BookAgendaCommentDTO]) async {
        guard !isLoadingComments, !isSubmitting, !isPerformingAction else { return }
        let generation = self.generation
        let revision = UUID()
        commentsRevision = revision
        isLoadingComments = true
        commentsError = nil
        defer {
            if generation == self.generation, revision == commentsRevision { isLoadingComments = false }
        }
        do {
            let loaded = try await fetch()
            guard generation == self.generation, revision == commentsRevision, !Task.isCancelled else { return }
            comments = unique(loaded)
            synchronizeComments()
        } catch {
            guard generation == self.generation, revision == commentsRevision, !Task.isCancelled else { return }
            commentsError = CommunityRefreshL10n.text("agenda.commentsLoadFailed")
        }
    }

    @discardableResult
    func submitComment(create: @escaping @Sendable (String) async throws -> BookAgendaCommentDTO) async -> Bool {
        let submittedDraft = draft
        let message = submittedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let post, post.viewer.canComment, !message.isEmpty, !isSubmitting, !isPerformingAction else { return false }
        let generation = self.generation
        isSubmitting = true
        actionMessage = nil
        defer { if generation == self.generation { isSubmitting = false } }
        do {
            let created = try await create(message)
            guard generation == self.generation, !Task.isCancelled else { return false }
            invalidateCommentsLoad()
            let isNew = !comments.contains { $0.id == created.id }
            if isNew { comments.append(created) }
            if let current = self.post {
                self.post = current.updating(commentCount: current.commentCount + (isNew ? 1 : 0), comments: comments)
            }
            if draft == submittedDraft { draft = "" }
            return true
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return false }
            actionMessage = L10n.agendaCommentFailed
            return false
        }
    }

    func performAction(
        mutate: @escaping @Sendable () async throws -> Void,
        refresh: @escaping @Sendable () async throws -> BookAgendaPostDTO
    ) async {
        guard !isPerformingAction, !isSubmitting else { return }
        let generation = self.generation
        isPerformingAction = true
        actionMessage = nil
        defer { if generation == self.generation { isPerformingAction = false } }
        do {
            try await mutate()
            guard generation == self.generation, !Task.isCancelled else { return }
            let refreshed = try await refresh()
            guard generation == self.generation, !Task.isCancelled else { return }
            post = refreshed.updating(comments: comments)
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return }
            actionMessage = L10n.agendaActionFailed
        }
    }

    @discardableResult
    func deletePost(delete: @escaping @Sendable () async throws -> Void) async -> Bool {
        guard !isPerformingAction, !isSubmitting else { return false }
        let generation = self.generation
        isPerformingAction = true
        actionMessage = nil
        defer { if generation == self.generation { isPerformingAction = false } }
        do {
            try await delete()
            guard generation == self.generation, !Task.isCancelled else { return false }
            invalidate()
            return true
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return false }
            actionMessage = L10n.agendaPostDeleteFailed
            return false
        }
    }

    func deleteComment(_ comment: BookAgendaCommentDTO, delete: @escaping @Sendable () async throws -> Void) async {
        guard !isPerformingAction, !isSubmitting else { return }
        let generation = self.generation
        isPerformingAction = true
        actionMessage = nil
        defer { if generation == self.generation { isPerformingAction = false } }
        do {
            try await delete()
            guard generation == self.generation, !Task.isCancelled else { return }
            invalidateCommentsLoad()
            comments.removeAll { $0.id == comment.id }
            if let current = post {
                post = current.updating(commentCount: max(0, current.commentCount - 1), comments: comments)
            }
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return }
            actionMessage = L10n.agendaCommentDeleteFailed
        }
    }

    func updatePost(_ updated: BookAgendaPostDTO) {
        guard post == nil || updated.id == post?.id else { return }
        post = updated.updating(comments: comments)
    }

    func updateComment(_ updated: BookAgendaCommentDTO) {
        invalidateCommentsLoad()
        guard let index = comments.firstIndex(where: { $0.id == updated.id }) else { return }
        comments[index] = updated
        synchronizeComments()
    }

    func removeComments(actorID: String) {
        comments.removeAll { $0.actor.id == actorID }
        synchronizeComments()
    }

    private func invalidateCommentsLoad() {
        commentsRevision = UUID()
        isLoadingComments = false
    }

    private func synchronizeComments() {
        post = post?.updating(comments: comments)
    }

    private func unique(_ values: [BookAgendaCommentDTO]) -> [BookAgendaCommentDTO] {
        var ids = Set<String>()
        return values.filter { ids.insert($0.id).inserted }
    }
}
