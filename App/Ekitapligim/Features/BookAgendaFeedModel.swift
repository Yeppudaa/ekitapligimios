import Foundation
import Combine
import EkitapligimCore

/// Repository operations are injected separately from account state so requests can be tested offline.
struct BookAgendaFeedDependencies: Sendable {
    var feed: @Sendable (BookAgendaTab, String?, Int, Int) async throws -> BookAgendaPageDTO
    var post: @Sendable (String) async throws -> BookAgendaPostDTO
    var react: @Sendable (String) async throws -> BookAgendaActionDTO
    var bookmark: @Sendable (String) async throws -> BookAgendaActionDTO
    var repost: @Sendable (String) async throws -> BookAgendaActionDTO
    var follow: @Sendable (String, Bool) async throws -> BookAgendaFollowDTO?
    var delete: @Sendable (String) async throws -> Void

    init(repository: BookAgendaRepository) {
        feed = { try await repository.feed(tab: $0, filter: $1, page: $2, perPage: $3) }
        post = { try await repository.post(id: $0) }
        react = { try await repository.toggleReaction(postID: $0) }
        bookmark = { try await repository.toggleBookmark(postID: $0) }
        repost = { try await repository.toggleRepost(postID: $0) }
        follow = { try await repository.setFollow(userID: $0, follow: $1) }
        delete = { try await repository.deletePost(id: $0) }
    }

    init(
        feed: @escaping @Sendable (BookAgendaTab, String?, Int, Int) async throws -> BookAgendaPageDTO,
        post: @escaping @Sendable (String) async throws -> BookAgendaPostDTO,
        react: @escaping @Sendable (String) async throws -> BookAgendaActionDTO,
        bookmark: @escaping @Sendable (String) async throws -> BookAgendaActionDTO,
        repost: @escaping @Sendable (String) async throws -> BookAgendaActionDTO,
        follow: @escaping @Sendable (String, Bool) async throws -> BookAgendaFollowDTO?,
        delete: @escaping @Sendable (String) async throws -> Void
    ) {
        self.feed = feed; self.post = post; self.react = react
        self.bookmark = bookmark; self.repost = repost; self.follow = follow; self.delete = delete
    }
}

@MainActor
final class BookAgendaFeedModel: ObservableObject {
    @Published private(set) var posts: [BookAgendaPostDTO] = []
    @Published private(set) var hasMore = false
    @Published private(set) var canCreate = false
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published var actionMessage: String?
    @Published private(set) var mutatingPostIDs: Set<String> = []
    @Published private(set) var followingActorIDs: Set<String> = []
    @Published private(set) var isSignedIn = false

    private struct Query: Equatable {
        let tab: BookAgendaTab
        let filter: String?
    }
    private var dependencies: BookAgendaFeedDependencies?
    private var sessionID: String?
    private var sessionGeneration = 0
    private var feedGeneration = 0
    private var selection: Query?
    private var page = 0
    private var interactionRevisions: [String: Int] = [:]
    private var removedPostIDs: Set<String> = []
    private var blockedActorIDs: Set<String> = []

    init() {}

    /// Call synchronously when account identity changes, before launching a new load task.
    func configure(dependencies: BookAgendaFeedDependencies, signedIn: Bool, sessionID: String?) {
        self.dependencies = dependencies
        guard isSignedIn != signedIn || self.sessionID != sessionID else { return }
        sessionGeneration += 1
        feedGeneration += 1
        isSignedIn = signedIn
        self.sessionID = sessionID
        selection = nil
        posts = []
        page = 0
        hasMore = false
        canCreate = false
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        actionMessage = nil
        mutatingPostIDs = []
        followingActorIDs = []
        interactionRevisions = [:]
        removedPostIDs = []
        blockedActorIDs = []
    }

    func load(tab: BookAgendaTab, filter: String?, reset: Bool) async {
        guard let dependencies else { return }
        let normalizedFilter = filter.flatMap { $0.isEmpty ? nil : $0 }
        let query = Query(
            tab: !isSignedIn ? .agenda : (normalizedFilter == "saved" ? .personal : tab),
            filter: !isSignedIn && normalizedFilter == "saved" ? nil : normalizedFilter
        )
        let queryChanged = selection != query
        let resetting = reset || queryChanged
        if resetting {
            // Every reset supersedes older work; changing a filter during a request must start it now.
            feedGeneration += 1
            selection = query
            isLoading = true
            isLoadingMore = false
            canCreate = false
            if queryChanged {
                posts = []
                page = 0
                hasMore = false
            }
        } else {
            guard !isLoading, !isLoadingMore, hasMore else { return }
            isLoadingMore = true
        }
        let requestGeneration = feedGeneration
        let requestSession = sessionGeneration
        let revisionSnapshot = interactionRevisions
        let targetPage = resetting ? 1 : page + 1
        errorMessage = nil
        defer {
            if requestGeneration == feedGeneration, requestSession == sessionGeneration {
                isLoading = false
                isLoadingMore = false
            }
        }
        do {
            let response = try await dependencies.feed(query.tab, query.filter, targetPage, 15)
            guard current(requestGeneration, session: requestSession), !Task.isCancelled else { return }
            let incoming = unique(response.items).map { post in
                // An earlier feed snapshot must not undo an action completed while it was waiting.
                if mutatingPostIDs.contains(post.id)
                    || revisionSnapshot[post.id, default: 0] != interactionRevisions[post.id, default: 0],
                   let existing = posts.first(where: { $0.id == post.id }) { return existing }
                return post
            }
            if resetting { posts = incoming }
            else {
                let existingIDs = Set(posts.map(\.id))
                posts.append(contentsOf: incoming.filter { !existingIDs.contains($0.id) })
            }
            page = targetPage
            hasMore = response.hasMore
            canCreate = isSignedIn && response.authenticated && response.canCreate
        } catch {
            guard current(requestGeneration, session: requestSession), !Task.isCancelled else { return }
            errorMessage = L10n.agendaFeedLoadFailed
        }
    }

    func replace(_ post: BookAgendaPostDTO) {
        interactionRevisions[post.id, default: 0] += 1
        guard !removedPostIDs.contains(post.id), !blockedActorIDs.contains(post.actor.id),
              let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        if selection?.filter == "saved", !post.viewer.bookmarked {
            posts.remove(at: index)
        } else { posts[index] = post }
    }

    func removeBlockedActor(_ actorID: String) {
        blockedActorIDs.insert(actorID)
        posts.removeAll { $0.actor.id == actorID }
    }

    func setBlockedActors(_ actorIDs: Set<String>) {
        blockedActorIDs = actorIDs
        posts.removeAll { actorIDs.contains($0.actor.id) }
    }

    func isMutating(postID: String) -> Bool {
        mutatingPostIDs.contains(postID)
            || posts.first(where: { $0.id == postID }).map { followingActorIDs.contains($0.actor.id) } == true
    }

    func react(_ post: BookAgendaPostDTO) async {
        guard let dependencies, let latest = posts.first(where: { $0.id == post.id }), latest.viewer.canReact else { return }
        await mutate(post.id, operation: dependencies.react)
    }

    func bookmark(_ post: BookAgendaPostDTO) async {
        guard let dependencies else { return }
        await mutate(post.id, operation: dependencies.bookmark)
    }

    func repost(_ post: BookAgendaPostDTO) async {
        guard let dependencies else { return }
        await mutate(post.id, operation: dependencies.repost)
    }

    func toggleFollow(_ post: BookAgendaPostDTO) async {
        guard let dependencies, isSignedIn,
              let latest = posts.first(where: { $0.id == post.id }),
              !followingActorIDs.contains(latest.actor.id), !isMutating(postID: post.id) else { return }
        let requestSession = sessionGeneration
        let actorID = latest.actor.id
        followingActorIDs.insert(actorID)
        actionMessage = nil
        defer { if requestSession == sessionGeneration { followingActorIDs.remove(actorID) } }
        do {
            let response = try await dependencies.follow(actorID, !latest.viewer.followingActor)
            guard requestSession == sessionGeneration, !Task.isCancelled else { return }
            guard let response else { actionMessage = L10n.agendaFollowUnavailable; return }
            guard response.success else { throw APIClientError.invalidResponse }
            if let selection { await load(tab: selection.tab, filter: selection.filter, reset: true) }
        } catch {
            guard requestSession == sessionGeneration, !Task.isCancelled else { return }
            actionMessage = L10n.agendaFollowFailed
        }
    }

    func delete(_ post: BookAgendaPostDTO) async {
        guard let dependencies, isSignedIn, !isMutating(postID: post.id),
              let latest = posts.first(where: { $0.id == post.id }),
              latest.viewer.canDelete else { return }
        let requestSession = sessionGeneration
        mutatingPostIDs.insert(post.id)
        interactionRevisions[post.id, default: 0] += 1
        actionMessage = nil
        defer { if requestSession == sessionGeneration { mutatingPostIDs.remove(post.id) } }
        do {
            try await dependencies.delete(post.id)
            guard requestSession == sessionGeneration, !Task.isCancelled else { return }
            removedPostIDs.insert(post.id)
            posts.removeAll { $0.id == post.id }
        } catch {
            guard requestSession == sessionGeneration, !Task.isCancelled else { return }
            actionMessage = L10n.agendaPostDeleteFailed
        }
    }

    private func mutate(
        _ postID: String,
        operation: @Sendable (String) async throws -> BookAgendaActionDTO
    ) async {
        guard let dependencies, isSignedIn, !isMutating(postID: postID),
              posts.contains(where: { $0.id == postID }) else { return }
        let requestSession = sessionGeneration
        mutatingPostIDs.insert(postID)
        interactionRevisions[postID, default: 0] += 1
        actionMessage = nil
        defer { if requestSession == sessionGeneration { mutatingPostIDs.remove(postID) } }
        do {
            let result = try await operation(postID)
            guard requestSession == sessionGeneration, !Task.isCancelled else { return }
            guard result.success else { throw APIClientError.invalidResponse }
            let updated = try await dependencies.post(postID)
            guard requestSession == sessionGeneration, !Task.isCancelled else { return }
            guard updated.id == postID else { throw APIClientError.invalidResponse }
            replace(updated)
        } catch {
            guard requestSession == sessionGeneration, !Task.isCancelled else { return }
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func current(_ requestGeneration: Int, session: Int) -> Bool {
        requestGeneration == feedGeneration && session == sessionGeneration
    }

    func remove(postID: String) {
        removedPostIDs.insert(postID)
        posts.removeAll { $0.id == postID }
    }

    private func unique(_ incoming: [BookAgendaPostDTO]) -> [BookAgendaPostDTO] {
        var seen = Set<String>()
        return incoming.filter {
            !removedPostIDs.contains($0.id) && !blockedActorIDs.contains($0.actor.id) && seen.insert($0.id).inserted
        }
    }
}
