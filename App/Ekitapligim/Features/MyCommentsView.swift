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
        Group {
            if isLoading && comments.isEmpty {
                ProgressView(L10n.myCommentsLoading)
            } else if let errorMessage, comments.isEmpty {
                ContentUnavailableView {
                    Label(L10n.myCommentsUnavailableTitle, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button(L10n.commonRetry) { Task { await load(reset: true) } }
                }
            } else if comments.isEmpty {
                ContentUnavailableView(
                    L10n.myCommentsEmptyTitle,
                    systemImage: "text.bubble",
                    description: Text(L10n.myCommentsEmptyDescription)
                )
            } else {
                List {
                    ForEach(comments) { comment in
                        NavigationLink {
                            ForumThreadDetailView(thread: thread(from: comment))
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(comment.threadTitle ?? L10n.myCommentsForumTitle)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(comment.message)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if page < lastPage {
                        Button(L10n.commonLoadMore) { Task { await load(reset: false) } }
                            .disabled(isLoading)
                    }
                }
                .refreshable { await load(reset: true) }
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
