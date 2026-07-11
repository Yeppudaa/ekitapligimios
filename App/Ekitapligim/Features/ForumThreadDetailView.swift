import SwiftUI
import EkitapligimCore

struct ForumThreadDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let thread: ForumThreadDTO

    @State private var posts: [ForumPostDTO] = []
    @State private var replyText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var reportTarget: ReportTarget?
    @State private var showingTerms = false

    private let contentSafety = ContentSafety()

    var body: some View {
        List {
            if isLoading {
                ProgressView(L10n.forumThreadLoading)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else {
                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(posts) { post in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(post.username)
                                .font(.headline)
                            Spacer()
                            if let postID = Int(post.id) {
                                Button {
                                    reportTarget = ReportTarget(postID: postID)
                                } label: {
                                    Image(systemName: "flag")
                                }
                                .accessibilityLabel(L10n.forumThreadReportPost)
                            }
                            if let userID = post.userId {
                                Button {
                                    Task { await blockAuthor(userID: userID) }
                                } label: {
                                    Image(systemName: "person.crop.circle.badge.xmark")
                                }
                                .accessibilityLabel(L10n.forumThreadBlockUser)
                            }
                        }
                        Text(post.message)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }

            if thread.canReply {
                Section(L10n.forumThreadReplySection) {
                    TextEditor(text: $replyText)
                        .frame(minHeight: 100)
                        .accessibilityLabel(L10n.forumThreadReplyTextLabel)
                    Button(L10n.forumThreadSubmitReply) {
                        Task { await reply() }
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                }
            }
        }
        .navigationTitle(thread.title)
        .task { await load() }
        .sheet(item: $reportTarget) { target in
            ReportContentView(kind: .post(postID: target.postID))
        }
        .sheet(isPresented: $showingTerms) {
            TermsAcceptanceView()
        }
    }

    private func load() async {
        guard let threadID = Int(thread.id) else {
            errorMessage = L10n.forumThreadInvalidThread
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await container.community.posts(threadID: threadID).posts
        } catch {
            errorMessage = L10n.forumThreadLoadFailed
        }
    }

    private func reply() async {
        guard let threadID = Int(thread.id) else { return }
        switch contentSafety.validateUserGeneratedText(replyText) {
        case .accepted:
            break
        case .rejected(let reason):
            errorMessage = reason.userMessage
            return
        }
        do {
            let terms = try? await container.account.termsStatus()
            if terms?.requiresAcceptance == true {
                showingTerms = true
                return
            }
            let post = try await container.community.reply(threadID: threadID, message: replyText)
            posts.append(post)
            replyText = ""
            statusMessage = L10n.forumThreadReplyPublished
        } catch {
            errorMessage = L10n.forumThreadReplyFailed
        }
    }

    private func blockAuthor(userID: Int) async {
        do {
            try await container.safety.blockMember(userID: userID)
            statusMessage = L10n.blockMemberSuccess
        } catch {
            statusMessage = L10n.blockMemberFailure
        }
    }
}

private struct ReportTarget: Identifiable {
    let postID: Int
    var id: Int { postID }
}
