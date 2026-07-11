import SwiftUI
import EkitapligimCore

@MainActor
struct ForumThreadsView: View {
    @EnvironmentObject private var container: AppContainer
    let forum: ForumDTO

    @State private var threads: [ForumThreadDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L10n.forumThreadsLoading)
            } else if let errorMessage {
                ContentUnavailableView(L10n.forumThreadsUnavailableTitle, systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if threads.isEmpty {
                ContentUnavailableView(L10n.forumThreadsEmptyTitle, systemImage: "text.bubble")
            } else {
                List(threads) { thread in
                    NavigationLink {
                        ForumThreadDetailView(thread: thread)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thread.title)
                                .font(.headline)
                            Text(L10n.forumThreadsMeta(username: thread.username, replyCount: thread.replyCount, viewCount: thread.viewCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(forum.title)
        .task { await load() }
    }

    private func load() async {
        guard let forumID = Int(forum.id) else {
            errorMessage = L10n.forumThreadsInvalidForum
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            threads = try await container.community.threads(forumID: forumID).threads
        } catch {
            errorMessage = L10n.forumThreadsLoadFailed
        }
    }
}
