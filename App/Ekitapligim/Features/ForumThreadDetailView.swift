import SwiftUI
import EkitapligimCore

@MainActor
struct ForumThreadDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let thread: ForumThreadDTO

    @State private var canReply: Bool
    @State private var posts: [ForumPostDTO] = []
    @State private var replyText = ""
    @FocusState private var isReplyFocused: Bool
    @State private var isLoading = true
    @State private var isReplySending = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var showingTerms = false
    @State private var showLoginAlert = false
    @State private var heroCollapseProgress: CGFloat = 0

    private let contentSafety = ContentSafety()

    init(thread: ForumThreadDTO) {
        self.thread = thread
        _canReply = State(initialValue: thread.canReply)
    }

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }

    private var showsPinnedReply: Bool {
        !isLoading && errorMessage == nil
    }

    var body: some View {
        EKitapligimScreen {
            ScrollView {
                LazyVStack(spacing: 12) {
                    EKScrollOffsetTracker()
                    threadHero

                    if isLoading {
                        EKLoadingState(message: L10n.forumThreadLoading)
                    } else if let errorMessage {
                        EKErrorState(title: L10n.forumThreadLoadFailed, message: errorMessage) {
                            Task { await load() }
                        }
                    } else {
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(EKitapligimPalette.success)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(EKitapligimPalette.successSoft, in: RoundedRectangle(cornerRadius: 12))
                        }

                        if posts.isEmpty {
                            Text(L10n.forumThreadEmptyPosts)
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else {
                            ForEach(posts.filter { post in
                                guard let userID = post.userId else { return true }
                                return !container.blockedUserIDs.contains(userID)
                            }) { post in
                                postCard(post)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .ekCollapsibleScrollTracking { heroCollapseProgress = $0 }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsPinnedReply {
                    replySection
                        .padding(12)
                        .background(.white)
                        .overlay(alignment: .top) {
                            Rectangle().fill(EKitapligimPalette.border).frame(height: 1)
                        }
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xFFFCF4), Color(hex: 0xFAF6EC), Color(hex: 0xF5FBFA), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .navigationTitle(thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showingTerms) {
            TermsAcceptanceView()
        }
        .alert(L10n.bookRequestsLoginRequiredTitle, isPresented: $showLoginAlert) {
            Button(L10n.bookRequestsGoToLogin) { container.selectedTab = .profile }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.forumThreadGuestReplyMessage)
        }
    }

    private var threadHero: some View {
        EKCollapsibleHero(progress: heroCollapseProgress) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x087A80))
                    .frame(width: 68, height: 68)
                    .background(Color(hex: 0xF1F8F7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: 0xD9C79F), lineWidth: 1)
                    }
                VStack(alignment: .leading, spacing: 8) {
                    Text(thread.title)
                        .font(.system(.title3, design: .serif).weight(.heavy))
                        .foregroundStyle(Color(hex: 0x0E1B2B))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Text(L10n.forumThreadDetailMeta(max(thread.replyCount + 1, posts.count)))
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0x687385))
                }
                Spacer(minLength: 0)
                if let postID = thread.firstPostId {
                    UGCSafetyMenu(type: .forumPost, contentID: postID, userID: thread.userId) {
                        if let userID = thread.userId {
                            posts.removeAll { $0.userId == userID }
                        }
                    }
                }
            }
            .padding(18)
            .forumHeroSurface(radius: 12)
        } collapsed: {
            HStack(spacing: 14) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x087A80))
                    .frame(width: 58, height: 58)
                    .background(Color(hex: 0xF1F8F7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(hex: 0xD9C79F), lineWidth: 1)
                    }
                VStack(alignment: .leading, spacing: 6) {
                    Text(thread.title)
                        .font(.system(.headline, design: .serif).weight(.heavy))
                        .foregroundStyle(Color(hex: 0x0E1B2B))
                        .lineLimit(2)
                    Text(L10n.forumThreadDetailMeta(max(thread.replyCount + 1, posts.count)))
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0x687385))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .forumHeroSurface(radius: 10)
        }
    }

    @ViewBuilder
    private var replySection: some View {
        if !isSignedIn {
            guestReplyPrompt
        } else {
            replyCard
        }
    }

    private var guestReplyPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.teal)
                .frame(width: 36, height: 36)
                .background(Color(hex: 0xE8F7F7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.forumThreadGuestReplyTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: 0x1E2433))
                Text(L10n.forumThreadGuestReplyMessage)
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0x6E7482))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Button {
                container.selectedTab = .profile
            } label: {
                Label(L10n.forumThreadGuestLoginShort, systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(hex: 0xF7F2EA), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { showLoginAlert = true }
    }

    private var replyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Android keeps the composer enabled and re-checks permission on submit.
            if !canReply {
                Text(L10n.forumThreadReplyPermissionHint)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            TextEditor(text: $replyText)
                .focused($isReplyFocused)
                .accessibilityLabel(L10n.forumThreadReplyPlaceholder)
                .frame(minHeight: 88)
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: isReplyFocused ? 0x087A80 : 0xD7C59C), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(L10n.forumThreadReplyPlaceholder)
                            .font(.body)
                            .foregroundStyle(EKitapligimPalette.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(L10n.forumThreadReplyTextLabel)
            HStack {
                Spacer(minLength: 0)
                Button {
                    Task { await reply() }
                } label: {
                    Group {
                        if isReplySending {
                            ProgressView().tint(.white)
                        } else {
                            Label(L10n.forumThreadSubmitReply, systemImage: "paperplane.fill")
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(isReplySending || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func postCard(_ post: ForumPostDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                if let userID = post.userId {
                    NavigationLink {
                        MemberProfileView(memberID: String(userID))
                    } label: {
                        postAuthorHeader(post)
                    }
                    .buttonStyle(.plain)
                } else {
                    postAuthorHeader(post)
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(Color(hex: 0xE9D9BA))
                .frame(height: 1.2)
                .padding(.vertical, 14)

            ForumMessageBody(message: post.message)
            postImages(post)

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.99), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func postAuthorHeader(_ post: ForumPostDTO) -> some View {
        HStack(spacing: 14) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xFFF7EA), Color(hex: 0xF5EDDC)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                EKAvatar(
                    urlString: post.avatarUrl,
                    username: ForumMessageFormatting.displayUsername(post.username),
                    size: 58,
                    cornerRadius: 12,
                    background: Color.clear,
                    foreground: Color(hex: 0x087A80)
                )
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: 0xF5EDDC), lineWidth: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(ForumMessageFormatting.displayUsername(post.username))
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(Color(hex: 0x0E1B2B))
                        .lineLimit(1)
                    if post.isAdmin == true {
                        EKPill(title: L10n.chatRoleAdmin, foreground: .white, background: EKitapligimPalette.danger)
                    } else if post.isModerator == true {
                        EKPill(title: L10n.chatRoleModerator, foreground: .white, background: EKitapligimPalette.teal)
                    } else if post.isPremium == true {
                        EKPill(
                            title: L10n.chatRolePremium,
                            foreground: Color(hex: 0x8A5A00),
                            background: Color(hex: 0xFFF3D6)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func postImages(_ post: ForumPostDTO) -> some View {
        if let imageUrls = post.imageUrls, !imageUrls.isEmpty {
            VStack(spacing: 8) {
                ForEach(imageUrls, id: \.self) { url in
                    forumPostImage(urlString: url)
                }
            }
        }
    }

    @ViewBuilder
    private func forumPostImage(urlString: String) -> some View {
        if let url = URL(string: urlString), url.scheme?.lowercased() == "https" {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .empty:
                    ProgressView()
                        .tint(EKitapligimPalette.teal)
                        .frame(maxWidth: .infinity, minHeight: 120)
                default:
                    Color(hex: 0xF2F4F7)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 120, maxHeight: 360)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(Color(hex: 0xF2F4F7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(L10n.forumThreadPostImage)
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
            canReply = posts.last?.canReply ?? thread.canReply
        } catch {
            errorMessage = L10n.forumThreadLoadFailed
        }
    }

    private func reply() async {
        let message = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSignedIn, let threadID = Int(thread.id), !isReplySending, !message.isEmpty else { return }
        isReplySending = true
        defer { isReplySending = false }
        switch contentSafety.validateUserGeneratedText(message) {
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
            let post = try await container.community.reply(threadID: threadID, message: message)
            posts.append(post)
            canReply = post.canReply
            replyText = ""
            statusMessage = L10n.forumThreadReplyPublished
        } catch {
            errorMessage = L10n.forumThreadReplyFailed
        }
    }

}
