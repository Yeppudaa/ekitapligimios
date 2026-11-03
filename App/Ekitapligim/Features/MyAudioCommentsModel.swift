import Foundation
import Combine
import EkitapligimCore

@MainActor
final class MyAudioCommentsModel: ObservableObject {
    @Published private(set) var comments: [ForumPostDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = false
    @Published private(set) var errorMessage: String?

    private let repository: any MyAudioCommentsServing
    private var sessionID: UUID?
    private var revision = UUID()
    private var page = 0
    private var failedReset = true

    init(repository: any MyAudioCommentsServing) { self.repository = repository }

    func retry() async { await load(reset: failedReset) }

    func activate(sessionID: UUID, signedIn: Bool) {
        let activeSession = signedIn ? sessionID : nil
        guard activeSession != self.sessionID else { return }
        self.sessionID = activeSession
        revision = UUID()
        comments = []; page = 0; hasMore = false; isLoading = false; errorMessage = nil
    }

    func load(reset: Bool) async {
        guard sessionID != nil, reset || (hasMore && !isLoading) else { return }
        if reset { revision = UUID() }
        let requestRevision = revision
        let requestedPage = reset ? 1 : page + 1
        isLoading = true; errorMessage = nil
        defer { if revision == requestRevision { isLoading = false } }
        do {
            let result = try await repository.audioComments(page: requestedPage)
            guard revision == requestRevision, !Task.isCancelled else { return }
            guard result.currentPage == requestedPage else { throw APIClientError.invalidResponse }
            var seen = Set(reset ? [] : comments.map(\.id))
            let incoming = result.comments.filter { seen.insert($0.id).inserted }
            comments = reset ? incoming : comments + incoming
            page = requestedPage
            hasMore = page < result.lastPage
        } catch {
            guard revision == requestRevision, !Task.isCancelled else { return }
            failedReset = reset
            if case APIClientError.authenticationRequired = error {
                errorMessage = AudioL10n.text("signInRequired")
            } else if error.isMissingEndpoint {
                errorMessage = AudioL10n.text("commentsUnavailable")
            } else if case APIClientError.httpStatus(503, _) = error {
                errorMessage = AudioL10n.text("commentsUnavailable")
            } else {
                errorMessage = AudioL10n.text("commentsLoadError")
            }
        }
    }
}
