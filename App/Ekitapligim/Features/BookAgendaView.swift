import SwiftUI
import EkitapligimCore

// MARK: - Sekme ve filtre modelleri

enum BookAgendaFilter: String, CaseIterable, Identifiable {
    case all = ""
    case book
    case review
    case quotation
    case progress
    case popular
    case saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.agendaFilterAll
        case .book: L10n.agendaFilterBooks
        case .review: L10n.agendaFilterReviews
        case .quotation: L10n.agendaFilterQuotations
        case .progress: L10n.agendaFilterProgress
        case .popular: L10n.agendaFilterPopular
        case .saved: L10n.agendaFilterSaved
        }
    }

    /// The API only knows about saved posts for the signed-in member's personal feed.
    var requiresAuthentication: Bool { self == .saved }
}

extension BookAgendaTab {
    var title: String {
        switch self {
        case .personal: L10n.agendaTabPersonal
        case .following: L10n.agendaTabFollowing
        case .agenda: L10n.agendaTabAgenda
        }
    }

    var requiresAuthentication: Bool { self != .agenda }
}

// MARK: - Akış

@MainActor
struct BookAgendaView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var posts: [BookAgendaPostDTO] = []
    @State private var tab: BookAgendaTab = .agenda
    @State private var filter: BookAgendaFilter = .all
    @State private var page = 1
    @State private var hasMore = false
    @State private var canCreate = false
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var showingComposer = false
    @State private var showingLogin = false
    @State private var selectedPostID: String?
    @State private var editingPost: BookAgendaPostDTO?
    @State private var pendingDeletion: BookAgendaPostDTO?

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    hero
                    tabStrip
                    filterStrip
                    composerPrompt
                    if let actionMessage {
                        EKInlineError(message: actionMessage)
                    }
                    feed
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .refreshable { await load(reset: true) }
        }
        .navigationTitle(L10n.agendaTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedPostID) { id in
            BookAgendaDetailView(postID: id)
        }
        .sheet(isPresented: $showingComposer) {
            NavigationStack {
                BookAgendaComposerView { created in
                    posts.insert(created, at: 0)
                }
            }
        }
        .sheet(item: $editingPost) { post in
            NavigationStack {
                BookAgendaEditView(post: post) { updated in
                    replace(updated)
                }
            }
        }
        .sheet(isPresented: $showingLogin) { LoginView() }
        .alert(L10n.agendaPostDeleteTitle, isPresented: deletionBinding) {
            Button(L10n.commonDismiss, role: .cancel) { pendingDeletion = nil }
            Button(L10n.commonDelete, role: .destructive) {
                if let post = pendingDeletion { Task { await delete(post) } }
            }
        } message: {
            Text(L10n.agendaPostDeleteMessage)
        }
        .task { await load(reset: true) }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    // MARK: Başlık alanı

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.agendaHeroEyebrow)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.9)
                .foregroundStyle(.white.opacity(0.85))
            Text(L10n.agendaTitle)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
            Text(L10n.agendaHeroBody)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [EKitapligimPalette.agendaPurple, EKitapligimPalette.agendaTeal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tabStrip: some View {
        HStack(spacing: 8) {
            ForEach(BookAgendaTab.allCases, id: \.self) { item in
                let locked = item.requiresAuthentication && !container.isSignedIn
                EKChip(
                    title: item.title,
                    isSelected: tab == item,
                    selectedBackground: EKitapligimPalette.agendaPurple,
                    isEnabled: !locked
                ) {
                    tab = item
                    if filter.requiresAuthentication && item != .personal { filter = .all }
                    Task { await load(reset: true) }
                }
            }
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters) { item in
                    EKChip(
                        title: item.title,
                        isSelected: filter == item,
                        selectedBackground: EKitapligimPalette.agendaPurple
                    ) {
                        filter = item
                        if item.requiresAuthentication { tab = .personal }
                        Task { await load(reset: true) }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var availableFilters: [BookAgendaFilter] {
        BookAgendaFilter.allCases.filter { container.isSignedIn || !$0.requiresAuthentication }
    }

    private var composerPrompt: some View {
        Button {
            if container.isSignedIn { showingComposer = true } else { showingLogin = true }
        } label: {
            HStack(spacing: 12) {
                EKAvatar(
                    urlString: container.profileState?.avatarUrl,
                    username: container.profileState?.username ?? "",
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.isSignedIn ? L10n.agendaComposerPromptTitle : L10n.agendaComposerGuestTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.agendaInk)
                    Text(container.isSignedIn ? L10n.agendaComposerPromptSubtitle : L10n.agendaComposerGuestSubtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: container.isSignedIn ? "square.and.pencil" : "arrow.right.circle.fill")
                    .foregroundStyle(EKitapligimPalette.agendaPurple)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ekitapligimCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Akış içeriği

    @ViewBuilder private var feed: some View {
        if isLoading && posts.isEmpty {
            EKSkeletonCard(height: 168)
            EKSkeletonCard(height: 168)
        } else if let errorMessage, posts.isEmpty {
            EKStateCard(
                title: L10n.agendaFeedErrorTitle,
                message: errorMessage,
                retryTitle: L10n.commonRetry
            ) {
                Task { await load(reset: true) }
            }
        } else if posts.isEmpty {
            EKStateCard(title: L10n.agendaFeedEmptyTitle, message: L10n.agendaFeedEmptySubtitle)
        } else {
            ForEach(posts) { post in
                BookAgendaPostCard(
                    post: post,
                    onOpen: { selectedPostID = post.id },
                    onReact: { Task { await react(post) } },
                    onBookmark: { Task { await bookmark(post) } },
                    onRepost: { Task { await repost(post) } },
                    onEdit: { editingPost = post },
                    onDelete: { pendingDeletion = post },
                    onFollow: { Task { await toggleFollow(post) } },
                    onRequireLogin: { showingLogin = true },
                    isSignedIn: container.isSignedIn
                )
            }
            if hasMore {
                EKLoadMoreButton(isLoading: isLoadingMore, tint: EKitapligimPalette.agendaPurple) {
                    Task { await load(reset: false) }
                }
            }
        }
    }

    // MARK: Veri

    private func load(reset: Bool) async {
        if reset {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore, hasMore else { return }
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        errorMessage = nil
        let targetPage = reset ? 1 : page + 1
        do {
            let response = try await container.bookAgenda.feed(
                tab: tab,
                filter: filter.rawValue.isEmpty ? nil : filter.rawValue,
                page: targetPage,
                perPage: 15
            )
            posts = reset ? response.items : posts + response.items
            page = targetPage
            hasMore = response.hasMore
            canCreate = response.canCreate
        } catch {
            errorMessage = L10n.agendaFeedLoadFailed
            if reset { posts = [] }
        }
    }

    private func replace(_ post: BookAgendaPostDTO) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
    }

    private func react(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            _ = try await container.bookAgenda.toggleReaction(postID: post.id)
            await reloadPost(post.id)
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func bookmark(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            _ = try await container.bookAgenda.toggleBookmark(postID: post.id)
            await reloadPost(post.id)
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func repost(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            _ = try await container.bookAgenda.toggleRepost(postID: post.id)
            await reloadPost(post.id)
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func toggleFollow(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            let result = try await container.bookAgenda.setFollow(
                userID: post.actor.id,
                follow: !post.viewer.followingActor
            )
            if result == nil {
                actionMessage = L10n.agendaFollowUnavailable
            } else {
                await load(reset: true)
            }
        } catch {
            actionMessage = L10n.agendaFollowFailed
        }
    }

    private func delete(_ post: BookAgendaPostDTO) async {
        pendingDeletion = nil
        do {
            try await container.bookAgenda.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
        } catch {
            actionMessage = L10n.agendaPostDeleteFailed
        }
    }

    private func reloadPost(_ id: String) async {
        guard let refreshed = try? await container.bookAgenda.post(id: id) else { return }
        replace(refreshed)
        actionMessage = nil
    }
}

// MARK: - Gönderi kartı

struct BookAgendaPostCard: View {
    let post: BookAgendaPostDTO
    var onOpen: () -> Void = {}
    var onReact: () -> Void = {}
    var onBookmark: () -> Void = {}
    var onRepost: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onFollow: () -> Void = {}
    var onRequireLogin: () -> Void = {}
    var isSignedIn: Bool = false
    var showsCommentAction: Bool = true

    private var kind: BookAgendaPostType {
        BookAgendaPostType(rawValue: post.type) ?? .standard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            typeBadges
            bodyContent
            if let book = post.book {
                BookAgendaBookChip(book: book)
            }
            attachments
            actionsRow
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private var header: some View {
        HStack(spacing: 11) {
            EKAvatar(urlString: post.actor.avatarUrl, username: post.actor.username, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(post.actor.username)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.agendaInk)
                        .lineLimit(1)
                    if post.actor.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(EKitapligimPalette.agendaTeal)
                            .accessibilityLabel(L10n.profileVerifiedAccessibility)
                    }
                }
                Text(EKitapligimFormat.relativeTime(post.createdAt))
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.agendaMuted)
            }
            Spacer(minLength: 0)

            if post.viewer.canEdit || post.viewer.canDelete {
                Menu {
                    if post.viewer.canEdit { Button(L10n.commonEdit, action: onEdit) }
                    if post.viewer.canDelete { Button(L10n.commonDelete, role: .destructive, action: onDelete) }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel(L10n.menuTitle)
            } else if isSignedIn {
                Button(action: onFollow) {
                    Text(post.viewer.followingActor ? L10n.agendaFollowing : L10n.agendaFollow)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(post.viewer.followingActor ? EKitapligimPalette.agendaMuted : EKitapligimPalette.agendaPurple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay {
                            Capsule().stroke(
                                post.viewer.followingActor ? EKitapligimPalette.agendaBorder : EKitapligimPalette.agendaPurple
                            )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var typeBadges: some View {
        HStack(spacing: 6) {
            EKPill(
                title: typeTitle,
                systemImage: typeIcon,
                foreground: EKitapligimPalette.agendaPurple,
                background: EKitapligimPalette.agendaPurpleSoft
            )
            if post.isPinned {
                EKPill(title: L10n.agendaPinned, systemImage: "pin.fill", foreground: EKitapligimPalette.agendaGold, background: EKitapligimPalette.amberSoft)
            }
            if post.isFeatured {
                EKPill(title: L10n.agendaFeatured, systemImage: "sparkles", foreground: EKitapligimPalette.agendaGreen, background: EKitapligimPalette.successSoft)
            }
            Spacer(minLength: 0)
        }
    }

    private var typeTitle: String {
        switch kind {
        case .book: L10n.agendaTypeBook
        case .quotation: L10n.agendaTypeQuotation
        case .review: L10n.agendaTypeReview
        case .progress: L10n.agendaTypeProgress
        case .standard: L10n.agendaTypeStandard
        }
    }

    private var typeIcon: String {
        switch kind {
        case .book: "book.fill"
        case .quotation: "quote.opening"
        case .review: "star.fill"
        case .progress: "chart.bar.fill"
        case .standard: "text.bubble.fill"
        }
    }

    @ViewBuilder private var bodyContent: some View {
        switch kind {
        case .quotation:
            quotationBody
        case .review:
            reviewBody
        case .progress:
            progressBody
        default:
            messageText
        }
    }

    private var messageText: some View {
        Text(EKitapligimFormat.plainText(post.message))
            .font(.subheadline)
            .foregroundStyle(EKitapligimPalette.agendaInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }

    private var quotationBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.agendaPurple)
                Text(EKitapligimFormat.plainText(post.message))
                    .font(.subheadline.italic())
                    .foregroundStyle(EKitapligimPalette.agendaInk)
                    .multilineTextAlignment(.leading)
            }
            if post.pageNumber > 0 {
                Text(L10n.agendaPageLabel(post.pageNumber))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.agendaMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(EKitapligimPalette.agendaQuoteBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(EKitapligimPalette.agendaQuoteBorder)
        }
    }

    private var reviewBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !post.reviewTitle.isEmpty {
                Text(post.reviewTitle)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.agendaInk)
            }
            if post.rating > 0 {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= post.rating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(EKitapligimPalette.agendaGold)
                    }
                }
                .accessibilityLabel(L10n.bookCommentsRating(post.rating))
            }
            messageText
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            messageText
            if post.progressTotal > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.agendaProgressLabel)
                            .font(.caption2)
                            .foregroundStyle(EKitapligimPalette.agendaMuted)
                        Spacer(minLength: 0)
                        Text("\(post.progressCurrent) / \(post.progressTotal)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.agendaTeal)
                    }
                    ProgressView(
                        value: Double(min(post.progressCurrent, post.progressTotal)),
                        total: Double(max(post.progressTotal, 1))
                    )
                    .tint(EKitapligimPalette.agendaTeal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var attachments: some View {
        if !post.attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(post.attachments) { attachment in
                        EKitapligimRemoteCover(urlString: attachment.thumbnailUrl ?? attachment.url)
                            .frame(width: 128, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .accessibilityLabel(L10n.agendaPostImage)
                    }
                }
            }
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 4) {
            actionButton(
                systemImage: post.viewer.reacted ? "heart.fill" : "heart",
                count: post.reactionScore,
                tint: post.viewer.reacted ? EKitapligimPalette.agendaPurple : EKitapligimPalette.agendaMuted,
                label: L10n.agendaReact,
                action: post.viewer.canReact || isSignedIn ? onReact : onRequireLogin
            )
            if showsCommentAction {
                actionButton(
                    systemImage: "bubble.right",
                    count: post.commentCount,
                    tint: EKitapligimPalette.agendaMuted,
                    label: L10n.agendaComments,
                    action: onOpen
                )
            }
            actionButton(
                systemImage: post.viewer.reposted ? "arrow.2.squarepath" : "arrow.2.squarepath",
                count: post.repostCount,
                tint: post.viewer.reposted ? EKitapligimPalette.agendaGreen : EKitapligimPalette.agendaMuted,
                label: L10n.agendaRepost,
                action: isSignedIn ? onRepost : onRequireLogin
            )
            Spacer(minLength: 0)
            actionButton(
                systemImage: post.viewer.bookmarked ? "bookmark.fill" : "bookmark",
                count: nil,
                tint: post.viewer.bookmarked ? EKitapligimPalette.agendaGold : EKitapligimPalette.agendaMuted,
                label: L10n.agendaBookmark,
                action: isSignedIn ? onBookmark : onRequireLogin
            )
        }
    }

    private func actionButton(
        systemImage: String,
        count: Int?,
        tint: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.caption)
                if let count, count > 0 {
                    Text(EKitapligimFormat.count(count)).font(.caption2.weight(.bold))
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count.map { "\(label), \($0)" } ?? label)
    }
}

struct BookAgendaBookChip: View {
    let book: BookAgendaBookDTO

    var body: some View {
        HStack(spacing: 10) {
            EKitapligimRemoteCover(urlString: book.coverUrl ?? "")
                .frame(width: 38, height: 55)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.agendaInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let id = Int(book.id) {
                NavigationLink { BookDetailView(bookID: id) } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.agendaTeal)
                }
                .accessibilityLabel(L10n.agendaOpenBook)
            }
        }
        .padding(10)
        .background(EKitapligimPalette.agendaSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Gönderi detayı

@MainActor
struct BookAgendaDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let postID: String

    @State private var post: BookAgendaPostDTO?
    @State private var comments: [BookAgendaCommentDTO] = []
    @State private var draft = ""
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var showingLogin = false
    @State private var editingComment: BookAgendaCommentDTO?
    @State private var pendingCommentDeletion: BookAgendaCommentDTO?

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if isLoading && post == nil {
                        EKSkeletonCard(height: 180)
                    } else if let post {
                        BookAgendaPostCard(
                            post: post,
                            onReact: { Task { await react() } },
                            onBookmark: { Task { await bookmark() } },
                            onRepost: { Task { await repost() } },
                            onRequireLogin: { showingLogin = true },
                            isSignedIn: container.isSignedIn,
                            showsCommentAction: false
                        )
                        if let actionMessage {
                            EKInlineError(message: actionMessage)
                        }
                        commentsSection(post: post)
                    } else {
                        EKStateCard(
                            title: L10n.agendaDetailErrorTitle,
                            message: errorMessage ?? L10n.agendaDetailErrorMessage,
                            retryTitle: L10n.commonRetry
                        ) {
                            Task { await load() }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(L10n.agendaTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogin) { LoginView() }
        .sheet(item: $editingComment) { comment in
            NavigationStack {
                BookAgendaCommentEditView(comment: comment) { updated in
                    if let index = comments.firstIndex(where: { $0.id == updated.id }) {
                        comments[index] = updated
                    }
                }
            }
        }
        .alert(L10n.agendaCommentDeleteTitle, isPresented: commentDeletionBinding) {
            Button(L10n.commonDismiss, role: .cancel) { pendingCommentDeletion = nil }
            Button(L10n.commonDelete, role: .destructive) {
                if let comment = pendingCommentDeletion { Task { await deleteComment(comment) } }
            }
        } message: {
            Text(L10n.agendaCommentDeleteMessage)
        }
        .task { await load() }
    }

    private var commentDeletionBinding: Binding<Bool> {
        Binding(get: { pendingCommentDeletion != nil }, set: { if !$0 { pendingCommentDeletion = nil } })
    }

    private func commentsSection(post: BookAgendaPostDTO) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(L10n.agendaCommentsHeader(comments.count))
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.agendaInk)

            if comments.isEmpty {
                EKStateCard(title: L10n.agendaCommentsEmptyTitle, message: L10n.agendaCommentsEmptySubtitle)
            } else {
                ForEach(comments) { comment in
                    BookAgendaCommentRow(
                        comment: comment,
                        onEdit: { editingComment = comment },
                        onDelete: { pendingCommentDeletion = comment }
                    )
                }
            }

            composer(post: post)
        }
    }

    private func composer(post: BookAgendaPostDTO) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(container.isSignedIn ? L10n.agendaCommentComposerTitle : L10n.agendaCommentGuestTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(EKitapligimPalette.agendaInk)

            if container.isSignedIn {
                TextField(L10n.agendaCommentPlaceholder, text: $draft, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(11)
                    .background(EKitapligimPalette.agendaSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    Task { await submitComment(post: post) }
                } label: {
                    Text(isSubmitting ? L10n.agendaCommentSubmitting : L10n.agendaCommentSubmit)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(EKitapligimPalette.agendaPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button(L10n.commonLogin) { showingLogin = true }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.agendaPurple)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loaded = try await container.bookAgenda.post(id: postID)
            post = loaded
            comments = loaded.comments.isEmpty
                ? ((try? await container.bookAgenda.comments(postID: postID)) ?? [])
                : loaded.comments
        } catch {
            errorMessage = L10n.agendaDetailErrorMessage
        }
    }

    private func react() async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            _ = try await container.bookAgenda.toggleReaction(postID: postID)
            post = try? await container.bookAgenda.post(id: postID)
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func bookmark() async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            _ = try await container.bookAgenda.toggleBookmark(postID: postID)
            post = try? await container.bookAgenda.post(id: postID)
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func repost() async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            _ = try await container.bookAgenda.toggleRepost(postID: postID)
            post = try? await container.bookAgenda.post(id: postID)
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func submitComment(post: BookAgendaPostDTO) async {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let created = try await container.bookAgenda.createComment(postID: post.id, message: message)
            comments.append(created)
            draft = ""
            actionMessage = nil
        } catch {
            actionMessage = L10n.agendaCommentFailed
        }
    }

    private func deleteComment(_ comment: BookAgendaCommentDTO) async {
        pendingCommentDeletion = nil
        do {
            try await container.bookAgenda.deleteComment(commentID: comment.id)
            comments.removeAll { $0.id == comment.id }
        } catch {
            actionMessage = L10n.agendaCommentDeleteFailed
        }
    }
}

private struct BookAgendaCommentRow: View {
    let comment: BookAgendaCommentDTO
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            EKAvatar(urlString: comment.actor.avatarUrl, username: comment.actor.username, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.actor.username)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.agendaInk)
                    Text(EKitapligimFormat.relativeTime(comment.createdAt))
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                    Spacer(minLength: 0)
                    if comment.viewer.canEdit || comment.viewer.canDelete {
                        Menu {
                            if comment.viewer.canEdit { Button(L10n.commonEdit, action: onEdit) }
                            if comment.viewer.canDelete { Button(L10n.commonDelete, role: .destructive, action: onDelete) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(EKitapligimPalette.agendaMuted)
                        }
                        .accessibilityLabel(L10n.menuTitle)
                    }
                }
                Text(EKitapligimFormat.plainText(comment.message))
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.agendaInk)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EKitapligimPalette.agendaSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Oluşturma ve düzenleme

@MainActor
struct BookAgendaComposerView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    let onCreated: (BookAgendaPostDTO) -> Void

    @State private var type: BookAgendaPostType = .standard
    @State private var visibility: BookAgendaVisibility = .public
    @State private var message = ""
    @State private var reviewTitle = ""
    @State private var rating = 5
    @State private var pageNumber = ""
    @State private var progressCurrent = ""
    @State private var progressTotal = ""
    @State private var selectedBook: BookDTO?
    @State private var showingBookPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var requiresBook: Bool { type == .book || type == .quotation || type == .review || type == .progress }

    var body: some View {
        Form {
            Section {
                Picker(L10n.agendaComposerTitle, selection: $type) {
                    Text(L10n.agendaTypeStandard).tag(BookAgendaPostType.standard)
                    Text(L10n.agendaTypeBook).tag(BookAgendaPostType.book)
                    Text(L10n.agendaTypeQuotation).tag(BookAgendaPostType.quotation)
                    Text(L10n.agendaTypeReview).tag(BookAgendaPostType.review)
                    Text(L10n.agendaTypeProgressCompose).tag(BookAgendaPostType.progress)
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.agendaComposerSubtitle)
            }

            if requiresBook {
                Section(L10n.agendaComposerSelectBook) {
                    Button {
                        showingBookPicker = true
                    } label: {
                        HStack {
                            Text(selectedBook?.title ?? L10n.agendaComposerSelectBook)
                                .foregroundStyle(selectedBook == nil ? EKitapligimPalette.muted : EKitapligimPalette.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "magnifyingglass")
                                .accessibilityHidden(true)
                                .foregroundStyle(EKitapligimPalette.teal)
                        }
                    }
                    .accessibilityLabel(L10n.agendaComposerSelectBook)
                }
            }

            Section {
                TextField(
                    type == .quotation ? L10n.agendaComposerQuotePlaceholder : L10n.agendaComposerPlaceholder,
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(4...12)
                .onChange(of: message) { _, value in message = String(value.prefix(5_000)) }
            }

            if type == .quotation {
                Section {
                    TextField(L10n.agendaComposerPageNumber, text: $pageNumber)
                        .keyboardType(.numberPad)
                        .onChange(of: pageNumber) { _, value in pageNumber = digits(value) }
                }
            }

            if type == .review {
                Section {
                    TextField(L10n.agendaComposerReviewTitle, text: $reviewTitle)
                        .onChange(of: reviewTitle) { _, value in reviewTitle = String(value.prefix(120)) }
                    Stepper(L10n.agendaComposerRating(rating), value: $rating, in: 1...5)
                }
            }

            if type == .progress {
                Section {
                    HStack(spacing: 12) {
                        TextField(L10n.agendaComposerProgressCurrent, text: $progressCurrent)
                            .keyboardType(.numberPad)
                            .onChange(of: progressCurrent) { _, value in progressCurrent = digits(value) }
                        TextField(L10n.agendaComposerProgressTotal, text: $progressTotal)
                            .keyboardType(.numberPad)
                            .onChange(of: progressTotal) { _, value in progressTotal = digits(value) }
                    }
                }
            }

            Section(L10n.agendaPostVisibilityTitle) {
                Picker(L10n.agendaPostVisibilityTitle, selection: $visibility) {
                    Text(L10n.agendaVisibilityPublic).tag(BookAgendaVisibility.public)
                    Text(L10n.agendaVisibilityMembers).tag(BookAgendaVisibility.members)
                    Text(L10n.agendaVisibilityFollowers).tag(BookAgendaVisibility.followers)
                    Text(L10n.agendaVisibilityPrivate).tag(BookAgendaVisibility.private)
                }
                .pickerStyle(.menu)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(EKitapligimPalette.danger) }
            }
        }
        .navigationTitle(L10n.agendaComposerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(L10n.commonCancel) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSubmitting ? L10n.agendaComposerSubmitting : L10n.agendaComposerSubmit) {
                    Task { await submit() }
                }
                .disabled(isSubmitting)
            }
        }
        .sheet(isPresented: $showingBookPicker) {
            NavigationStack {
                BookAgendaBookPicker { book in
                    selectedBook = book
                    showingBookPicker = false
                }
            }
        }
    }

    private func digits(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(6))
    }

    private func submit() async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L10n.agendaComposerEmptyMessage
            return
        }
        if requiresBook && selectedBook == nil {
            errorMessage = L10n.agendaComposerBookRequired
            return
        }
        if type == .progress,
           let current = Int(progressCurrent), let total = Int(progressTotal),
           total > 0, current > total {
            errorMessage = L10n.agendaComposerProgressInvalid
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let created = try await container.bookAgenda.createPost(
                message: trimmed,
                postType: type,
                visibility: visibility,
                bookThreadID: selectedBook?.id,
                reviewTitle: type == .review ? reviewTitle : nil,
                rating: type == .review ? rating : nil,
                pageNumber: type == .quotation ? Int(pageNumber) : nil,
                progressCurrent: type == .progress ? Int(progressCurrent) : nil,
                progressTotal: type == .progress ? Int(progressTotal) : nil
            )
            onCreated(created)
            dismiss()
        } catch {
            errorMessage = (error as? APIClientError)?.serverMessage ?? L10n.agendaComposerFailed
        }
    }
}

@MainActor
private struct BookAgendaBookPicker: View {
    @EnvironmentObject private var container: AppContainer
    let onSelect: (BookDTO) -> Void

    @State private var query = ""
    @State private var results: [BookDTO] = []
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading && results.isEmpty {
                ProgressView().tint(EKitapligimPalette.teal)
            }
            ForEach(results) { book in
                Button {
                    onSelect(book)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EKitapligimPalette.ink)
                        if !book.author.isEmpty {
                            Text(book.author)
                                .font(.caption)
                                .foregroundStyle(EKitapligimPalette.muted)
                            }
                        }
                    }
                }
            }
        .navigationTitle(L10n.agendaComposerSelectBook)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: L10n.agendaComposerSearchBook)
        .onSubmit(of: .search) { Task { await search() } }
        .task { await search() }
    }

    private func search() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        results = (try? await container.books.books(page: 1, query: query.isEmpty ? nil : query).books) ?? []
    }
}

@MainActor
struct BookAgendaEditView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    let post: BookAgendaPostDTO
    let onUpdated: (BookAgendaPostDTO) -> Void

    @State private var message: String
    @State private var visibility: BookAgendaVisibility
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(post: BookAgendaPostDTO, onUpdated: @escaping (BookAgendaPostDTO) -> Void) {
        self.post = post
        self.onUpdated = onUpdated
        _message = State(initialValue: EKitapligimFormat.plainText(post.message))
        _visibility = State(initialValue: BookAgendaVisibility(rawValue: post.visibility) ?? .public)
    }

    var body: some View {
        Form {
            Section(L10n.agendaPostLabel) {
                TextField(L10n.agendaComposerPlaceholder, text: $message, axis: .vertical)
                    .lineLimit(4...12)
                    .onChange(of: message) { _, value in message = String(value.prefix(5_000)) }
            }
            Section(L10n.agendaPostVisibilityTitle) {
                Picker(L10n.agendaPostVisibilityTitle, selection: $visibility) {
                    Text(L10n.agendaVisibilityPublic).tag(BookAgendaVisibility.public)
                    Text(L10n.agendaVisibilityMembers).tag(BookAgendaVisibility.members)
                    Text(L10n.agendaVisibilityFollowers).tag(BookAgendaVisibility.followers)
                    Text(L10n.agendaVisibilityPrivate).tag(BookAgendaVisibility.private)
                }
                .pickerStyle(.menu)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(EKitapligimPalette.danger) }
            }
        }
        .navigationTitle(L10n.agendaPostEditTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button(L10n.commonCancel) { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? L10n.commonSaving : L10n.commonSave) { Task { await save() } }
                    .disabled(isSaving)
            }
        }
    }

    private func save() async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L10n.agendaComposerEmptyMessage
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await container.bookAgenda.updatePost(id: post.id, message: trimmed, visibility: visibility)
            onUpdated(updated)
            dismiss()
        } catch {
            errorMessage = L10n.agendaPostUpdateFailed
        }
    }
}

@MainActor
private struct BookAgendaCommentEditView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    let comment: BookAgendaCommentDTO
    let onUpdated: (BookAgendaCommentDTO) -> Void

    @State private var message: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(comment: BookAgendaCommentDTO, onUpdated: @escaping (BookAgendaCommentDTO) -> Void) {
        self.comment = comment
        self.onUpdated = onUpdated
        _message = State(initialValue: EKitapligimFormat.plainText(comment.message))
    }

    var body: some View {
        Form {
            Section {
                TextField(L10n.agendaCommentPlaceholder, text: $message, axis: .vertical)
                    .lineLimit(3...10)
                    .onChange(of: message) { _, value in message = String(value.prefix(5_000)) }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(EKitapligimPalette.danger) }
            }
        }
        .navigationTitle(L10n.agendaCommentEditTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button(L10n.commonCancel) { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? L10n.commonSaving : L10n.commonSave) { Task { await save() } }
                    .disabled(isSaving)
            }
        }
    }

    private func save() async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await container.bookAgenda.updateComment(commentID: comment.id, message: trimmed)
            onUpdated(updated)
            dismiss()
        } catch {
            errorMessage = L10n.agendaCommentUpdateFailed
        }
    }
}
