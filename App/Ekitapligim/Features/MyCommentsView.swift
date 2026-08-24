import SwiftUI
import EkitapligimCore

@MainActor
struct MyCommentsView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var comments: [ForumPostDTO] = []
    @State private var page = 1
    @State private var lastPage = 1
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && comments.isEmpty {
                    EKLoadingState(message: L10n.myCommentsLoading)
                } else if let errorMessage, comments.isEmpty {
                    EKErrorState(title: L10n.myCommentsUnavailableTitle, message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else if comments.isEmpty {
                    EKEmptyState(
                        title: L10n.myCommentsEmptyTitle,
                        message: L10n.myCommentsEmptyDescription,
                        systemImage: "text.bubble"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(comments) { comment in
                                NavigationLink {
                                    ForumThreadDetailView(thread: thread(from: comment))
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(comment.threadTitle ?? L10n.myCommentsForumTitle)
                                            .font(.headline)
                                            .foregroundStyle(EKitapligimPalette.ink)
                                            .lineLimit(1)
                                        Text(comment.message)
                                            .font(.subheadline)
                                            .foregroundStyle(EKitapligimPalette.muted)
                                            .lineLimit(3)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .ekitapligimCard(radius: 14)
                                }
                                .buttonStyle(.plain)
                            }
                            if page < lastPage {
                                EKLoadMoreButton(isLoading: isLoading) {
                                    Task { await load(reset: false) }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await load(reset: true) }
                }
            }
        }
        .navigationTitle(L10n.myCommentsTitle)
        .task { await load(reset: true) }
    }

    private func thread(from comment: ForumPostDTO) -> ForumThreadDTO {
        ForumThreadDTO(
            id: comment.threadId,
            title: comment.threadTitle ?? L10n.myCommentsForumTitle,
            username: comment.username,
            postDate: comment.postDate,
            canReply: comment.canReply
        )
    }

    @MainActor
    private func load(reset: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        let requestedPage = reset ? 1 : page + 1
        do {
            let result = try await container.profile.comments(page: requestedPage)
            comments = reset ? result.comments : comments + result.comments.filter { item in
                !comments.contains(where: { $0.id == item.id })
            }
            page = result.currentPage ?? requestedPage
            lastPage = result.lastPage ?? page
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
