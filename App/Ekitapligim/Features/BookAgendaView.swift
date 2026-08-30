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

    var subtitle: String {
        switch self {
        case .personal: L10n.agendaTabPersonalSubtitle
        case .following: L10n.agendaTabFollowingSubtitle
        case .agenda: L10n.agendaTabAgendaSubtitle
        }
    }

    var requiresAuthentication: Bool { self != .agenda }
}

// MARK: - Akış

@MainActor
struct BookAgendaView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var posts: [BookAgendaPostDTO] = []
    @State private var tab: BookAgendaTab
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

    init() {
        // Android defaults signed-in users to the personal tab.
        _tab = State(initialValue: .agenda)
    }

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    hero
                    tabStrip
                    composerPrompt
                    filterStrip
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
        .task {
            if container.isSignedIn, tab == .agenda {
                tab = .personal
            }
            await load(reset: true)
        }
        .onChange(of: container.isSignedIn) { _, signedIn in
            if signedIn, tab == .agenda {
                tab = .personal
                Task { await load(reset: true) }
            }
        }
        .navigationDestination(item: $selectedPostID) { id in
            BookAgendaDetailView(postID: id) { updated in
                replace(updated)
            }
        }
        .sheet(isPresented: $showingComposer) {
            BookAgendaComposerView { created in
                posts.insert(created, at: 0)
            }
            .presentationDetents([.large, .fraction(0.92)])
            .presentationDragIndicator(.visible)
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
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    // MARK: Başlık alanı

    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x8B6BFF), EKitapligimPalette.agendaPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.agendaHeroEyebrow)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(EKitapligimPalette.agendaPurple)
                Text(L10n.agendaHeroBody)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.agendaInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                Task { await load(reset: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.agendaTeal)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel(L10n.agendaRefresh)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [.white, Color(hex: 0xF3EFFF), Color(hex: 0xEAFBFA)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: 0xDCD5FF))
        }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BookAgendaTab.allCases, id: \.self) { item in
                    let locked = item.requiresAuthentication && !container.isSignedIn
                    agendaTabCard(item, locked: locked)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func agendaTabCard(_ item: BookAgendaTab, locked: Bool) -> some View {
        let selected = tab == item
        return Button {
            if locked {
                showingLogin = true
                return
            }
            tab = item
            if filter.requiresAuthentication && item != .personal { filter = .all }
            Task { await load(reset: true) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: agendaTabIcon(item))
                    .font(.body)
                    .accessibilityHidden(true)
                    .foregroundStyle(selected ? EKitapligimPalette.agendaPurple : EKitapligimPalette.agendaTeal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.agendaInk)
                    Text(locked ? L10n.agendaTabLocked : item.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                }
            }
            .padding(13)
            .frame(maxWidth: 178, alignment: .leading)
            .background(selected ? Color(hex: 0xEDE8FF) : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color(hex: 0xC8BCFF) : EKitapligimPalette.agendaBorder)
            }
        }
        .accessibilityLabel(item.title)
        .buttonStyle(.plain)
    }

    private func agendaTabIcon(_ item: BookAgendaTab) -> String {
        switch item {
        case .personal: "sparkles"
        case .following: "person.3.fill"
        case .agenda: "safari.fill"
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters) { item in
                    EKChip(
                        title: item.title,
                        systemImage: item == .saved ? "bookmark.fill" : nil,
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
                Image(systemName: "square.and.pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.agendaTeal)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: 0xE7F7F7), in: Circle())
                    .accessibilityHidden(true)
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
                Image(systemName: "arrow.forward")
                    .foregroundStyle(EKitapligimPalette.agendaPurple)
            }
            .padding(16)
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
                retryTitle: L10n.commonRetry,
                retry: { Task { await load(reset: true) } },
                systemImage: "books.vertical.fill"
            )
        } else if posts.isEmpty {
            EKStateCard(title: L10n.agendaFeedEmptyTitle, message: L10n.agendaFeedEmptySubtitle, systemImage: "books.vertical.fill")
        } else {
            ForEach(posts.filter { post in
                guard let userID = Int(post.actor.id) else { return true }
                return !container.blockedUserIDs.contains(userID)
            }) { post in
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
                    onBlocked: {
                        let actorID = post.actor.id
                        posts.removeAll { $0.actor.id == actorID }
                    },
                    isSignedIn: container.isSignedIn
                )
            }
            if let errorMessage, !posts.isEmpty {
                EKInlineError(
                    message: errorMessage,
                    retryTitle: L10n.commonRetryAgain,
                    retry: { Task { await load(reset: false) } },
                    showsIcon: false
                )
            }
            if hasMore {
                EKLoadMoreButton(
                    isLoading: isLoadingMore,
                    title: L10n.commonLoadMoreItems,
                    tint: EKitapligimPalette.agendaPurple
                ) {
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
    var onBlocked: () -> Void = {}
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
            if let quotedPost = post.quotedPost {
                quotedPostCard(quotedPost)
            }
            if let book = post.book {
                BookAgendaBookChip(book: book)
            }
            attachments
            actionsRow
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(post.isFeatured ? Color(hex: 0xE6C878) : EKitapligimPalette.agendaBorder, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private var header: some View {
        HStack(spacing: 11) {
            EKAvatar(urlString: post.actor.avatarUrl, username: post.actor.username, size: 44, cornerRadius: 15, background: Color(hex: 0xE7F7F7))
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
                Text("@\(post.actor.username) · \(EKitapligimFormat.relativeTime(post.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.agendaMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)

            if let contentID = Int(post.id) {
                UGCSafetyMenu(
                    type: .agendaPost,
                    contentID: contentID,
                    userID: post.viewer.canEdit ? nil : Int(post.actor.id),
                    onBlocked: onBlocked
                )
            }

            if post.viewer.canEdit || post.viewer.canDelete {
                Menu {
                    if post.viewer.canEdit { Button(L10n.commonEdit, action: onEdit) }
                    if post.viewer.canDelete { Button(L10n.commonDelete, role: .destructive, action: onDelete) }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel(L10n.agendaPostOptions)
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
                foreground: typeAccent,
                background: typeAccent.opacity(0.10)
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
        if post.type == "quote" { return L10n.agendaTypeQuote }
        return switch kind {
        case .book: L10n.agendaTypeBook
        case .quotation: L10n.agendaTypeQuotation
        case .review: L10n.agendaTypeReview
        case .progress: L10n.agendaTypeProgress
        case .standard: L10n.agendaTypeStandard
        }
    }

    private var typeAccent: Color {
        if post.type == "quote" { return Color(hex: 0x5A67B7) }
        return switch kind {
        case .book: EKitapligimPalette.agendaTeal
        case .quotation: EKitapligimPalette.agendaPurple
        case .review: EKitapligimPalette.agendaGold
        case .progress: Color(hex: 0x27875F)
        case .standard: EKitapligimPalette.agendaMuted
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

    private func quotedPostCard(_ quoted: BookAgendaQuotedPostDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !quoted.username.isEmpty {
                Text(L10n.agendaQuotedFrom(quoted.username))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.agendaPurple)
            }
            Text(EKitapligimFormat.plainText(quoted.message))
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.agendaInk)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            if let bookTitle = quoted.bookTitle, !bookTitle.isEmpty {
                Text(bookTitle)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.agendaMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color(hex: 0xF8F6FF), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xDDD5FF), lineWidth: 1)
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
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(index <= post.rating ? EKitapligimPalette.agendaGold : Color(hex: 0xDDE2E6))
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
            if post.progressPercent > 0 || post.progressTotal > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.agendaProgressLabel)
                            .font(.caption2)
                            .foregroundStyle(EKitapligimPalette.agendaMuted)
                        Spacer(minLength: 0)
                        if post.progressPercent > 0 {
                            Text(L10n.commonPercent(post.progressPercent))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.agendaTeal)
                        } else {
                            Text("\(post.progressCurrent) / \(post.progressTotal)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.agendaTeal)
                        }
                    }
                    GeometryReader { geo in
                        let total = Double(post.progressPercent > 0 ? 100 : max(post.progressTotal, 1))
                        let value = Double(post.progressPercent > 0 ? post.progressPercent : min(post.progressCurrent, max(post.progressTotal, 1)))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: 0xE5F2F2))
                            Capsule()
                                .fill(EKitapligimPalette.agendaTeal)
                                .frame(width: geo.size.width * CGFloat(min(max(value / total, 0), 1)))
                        }
                    }
                    .frame(height: 7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var attachments: some View {
        if post.attachments.count == 1, let attachment = post.attachments.first {
            EKitapligimRemoteCover(urlString: attachment.thumbnailUrl ?? attachment.url)
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .background(Color(hex: 0xE9EDF1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(L10n.agendaPostImage)
        } else if post.attachments.count > 1 {
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
            if post.viewCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                    Text(EKitapligimFormat.count(post.viewCount))
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.agendaMuted)
                .padding(.horizontal, 8)
                .accessibilityLabel(EKitapligimFormat.count(post.viewCount))
            }
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
                .frame(width: 46, height: 66)
                .background(Color(hex: 0xE6EBEF))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .padding(11)
        .background(Color(hex: 0xF7FAFA), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xD9E9E9), lineWidth: 1)
        }
    }
}

// MARK: - Gönderi detayı

@MainActor
struct BookAgendaDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let postID: String
    var onPostUpdated: ((BookAgendaPostDTO) -> Void)? = nil

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
                            onBlocked: {
                                if let userID = Int(post.actor.id) { container.rememberBlockedUser(userID) }
                                self.post = nil
                            },
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
                            retryTitle: L10n.commonRetry,
                            retry: { Task { await load() } },
                            systemImage: "books.vertical.fill"
                        )
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
                EKStateCard(title: L10n.agendaCommentsEmptyTitle, message: L10n.agendaCommentsEmptySubtitle, systemImage: "books.vertical.fill")
            } else {
                ForEach(comments.filter { comment in
                    guard let userID = Int(comment.actor.id) else { return true }
                    return !container.blockedUserIDs.contains(userID)
                }) { comment in
                    BookAgendaCommentRow(
                        comment: comment,
                        onEdit: { editingComment = comment },
                        onDelete: { pendingCommentDeletion = comment },
                        onBlocked: {
                            let actorID = comment.actor.id
                            comments.removeAll { $0.actor.id == actorID }
                        }
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
                    .lineLimit(2...6)
                    .padding(11)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(EKitapligimPalette.agendaBorder, lineWidth: 1)
                    }
                    .onChange(of: draft) { _, newValue in
                        if newValue.count > 2_000 {
                            draft = String(newValue.prefix(2_000))
                        }
                    }

                HStack {
                    Spacer(minLength: 0)
                    Button {
                        Task { await submitComment(post: post) }
                    } label: {
                        HStack(spacing: 6) {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.subheadline.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                            Text(isSubmitting ? L10n.agendaCommentSubmitting : L10n.agendaCommentSubmit)
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(EKitapligimPalette.agendaPurple, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel(L10n.agendaCommentSubmit)
                    .buttonStyle(.plain)
                    .disabled(isSubmitting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button(L10n.commonLogin) { showingLogin = true }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(EKitapligimPalette.agendaTeal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EKitapligimPalette.agendaBorder, lineWidth: 1)
        }
    }

    private func publishPostUpdate() {
        guard let post else { return }
        onPostUpdated?(post)
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
            publishPostUpdate()
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func bookmark() async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            _ = try await container.bookAgenda.toggleBookmark(postID: postID)
            post = try? await container.bookAgenda.post(id: postID)
            publishPostUpdate()
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func repost() async {
        guard container.isSignedIn else { showingLogin = true; return }
        do {
            _ = try await container.bookAgenda.toggleRepost(postID: postID)
            post = try? await container.bookAgenda.post(id: postID)
            publishPostUpdate()
        } catch {
            actionMessage = L10n.agendaActionFailed
        }
    }

    private func submitComment(post: BookAgendaPostDTO) async {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard container.isSignedIn, !message.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let created = try await container.bookAgenda.createComment(postID: post.id, message: message)
            comments.append(created)
            self.post = post.updating(commentCount: comments.count, comments: comments)
            publishPostUpdate()
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
            if var current = post {
                current = current.updating(commentCount: comments.count, comments: comments)
                post = current
            }
            publishPostUpdate()
        } catch {
            actionMessage = L10n.agendaCommentDeleteFailed
        }
    }
}

private struct BookAgendaCommentRow: View {
    let comment: BookAgendaCommentDTO
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onBlocked: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            EKAvatar(urlString: comment.actor.avatarUrl, username: comment.actor.username, size: 38, cornerRadius: 13, background: Color(hex: 0xE7F7F7))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.actor.username)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.agendaInk)
                    Spacer(minLength: 0)
                    Text(EKitapligimFormat.relativeTime(comment.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                    if comment.viewer.canEdit || comment.viewer.canDelete {
                        Menu {
                            if comment.viewer.canEdit { Button(L10n.commonEdit, action: onEdit) }
                            if comment.viewer.canDelete { Button(L10n.commonDelete, role: .destructive, action: onDelete) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(EKitapligimPalette.agendaMuted)
                                .frame(width: 30, height: 30)
                        }
                        .accessibilityLabel(L10n.agendaCommentOptions)
                    }
                    if let contentID = Int(comment.id) {
                        UGCSafetyMenu(
                            type: .agendaComment,
                            contentID: contentID,
                            userID: comment.viewer.canEdit ? nil : Int(comment.actor.id),
                            onBlocked: onBlocked
                        )
                    }
                }
                Text(EKitapligimFormat.plainText(comment.message))
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.agendaInk)
                    .multilineTextAlignment(.leading)
                if comment.reactionScore > 0 {
                    Text("♥ \(comment.reactionScore)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EKitapligimPalette.agendaPurple)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(EKitapligimPalette.agendaBorder, lineWidth: 1)
        }
    }
}

// MARK: - Oluşturma ve düzenleme

@MainActor
struct BookAgendaComposerView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    let onCreated: (BookAgendaPostDTO) -> Void

    @State private var type: BookAgendaPostType = .standard
    @State private var message = ""
    @State private var rating = 5
    @State private var pageNumber = ""
    @State private var progressCurrent = ""
    @State private var progressTotal = ""
    @State private var selectedBook: BookDTO?
    @State private var showingBookPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var requiresBook: Bool { type == .book || type == .quotation || type == .review || type == .progress }

    private var composerTypeOptions: [(BookAgendaPostType, String)] {
        [
            (.standard, L10n.agendaTypeNote),
            (.book, L10n.agendaTypeBook),
            (.quotation, L10n.agendaTypeQuotation),
            (.review, L10n.agendaTypeReview),
            (.progress, L10n.agendaTypeProgressCompose)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                Text(L10n.agendaComposerTitle)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(EKitapligimPalette.agendaInk)
                Text(L10n.agendaComposerSubtitle)
                    .foregroundStyle(EKitapligimPalette.agendaMuted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(composerTypeOptions, id: \.0) { option in
                            EKChip(
                                title: option.1,
                                isSelected: type == option.0,
                                selectedBackground: EKitapligimPalette.agendaPurple
                            ) {
                                type = option.0
                            }
                        }
                    }
                }

                if requiresBook {
                    Button {
                        showingBookPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .accessibilityHidden(true)
                            Text(selectedBook.map { "\($0.title) · \($0.author)" } ?? L10n.agendaComposerSelectBook)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(EKitapligimPalette.agendaInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(EKitapligimPalette.agendaBorder, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.agendaComposerSelectBook)
                }

                TextField(
                    type == .quotation ? L10n.agendaComposerQuotePlaceholder : L10n.agendaComposerPlaceholder,
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(4...12)
                .padding(12)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(EKitapligimPalette.agendaBorder, lineWidth: 1)
                }
                .onChange(of: message) { _, value in message = String(value.prefix(5_000)) }

                if type == .quotation {
                    TextField(L10n.agendaComposerPageNumber, text: $pageNumber)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(EKitapligimPalette.agendaBorder, lineWidth: 1)
                        }
                        .onChange(of: pageNumber) { _, value in pageNumber = digits(value) }
                }

                if type == .review {
                    Text(L10n.agendaComposerRating(rating))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.agendaInk)
                    Slider(
                        value: Binding(
                            get: { Double(rating) },
                            set: { rating = Int($0.rounded()) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    .tint(EKitapligimPalette.agendaPurple)
                    .accessibilityLabel(L10n.agendaComposerRating(rating))
                }

                if type == .progress {
                    HStack(spacing: 10) {
                        TextField(L10n.agendaComposerProgressCurrent, text: $progressCurrent)
                            .keyboardType(.numberPad)
                            .onChange(of: progressCurrent) { _, value in progressCurrent = digits(value) }
                        TextField(L10n.agendaComposerProgressTotal, text: $progressTotal)
                            .keyboardType(.numberPad)
                            .onChange(of: progressTotal) { _, value in progressTotal = digits(value) }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.danger)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .accessibilityHidden(true)
                        }
                        Text(isSubmitting ? L10n.agendaComposerSubmitting : L10n.agendaComposerSubmit)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EKitapligimPalette.agendaPurple, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .accessibilityLabel(L10n.agendaComposerSubmit)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(.white)
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
        if type == .progress, BookAgendaComposerRules.isProgressCurrentExceedingTotal(progressCurrent, total: progressTotal) {
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
                visibility: .public,
                bookThreadID: selectedBook?.id,
                reviewTitle: nil,
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
    @Environment(\.dismiss) private var dismiss
    let onSelect: (BookDTO) -> Void

    @State private var query = ""
    @State private var catalog: [BookDTO] = []
    @State private var searchResults: [BookDTO]?
    @State private var isLoading = false

    private var filtered: [BookDTO] {
        let turkish = Locale(identifier: "tr-TR")
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: turkish)
        let source: [BookDTO]
        if normalized.isEmpty {
            source = catalog
        } else if let searchResults, !searchResults.isEmpty {
            source = searchResults
        } else {
            source = catalog
        }
        let matches = source.filter { book in
            guard !normalized.isEmpty else { return true }
            return book.title.lowercased(with: turkish).contains(normalized)
                || book.author.lowercased(with: turkish).contains(normalized)
        }
        return Array(matches.prefix(10))
    }

    var body: some View {
        List {
            if isLoading && catalog.isEmpty {
                ProgressView().tint(EKitapligimPalette.teal)
            }
            ForEach(filtered) { book in
                Button {
                    onSelect(book)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        EKitapligimRemoteCover(urlString: book.coverUrl)
                            .frame(width: 38, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(book.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EKitapligimPalette.ink)
                                .lineLimit(2)
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.caption)
                                    .foregroundStyle(EKitapligimPalette.muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.agendaComposerSelectBook)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: L10n.agendaComposerSearchBook)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.commonClose) { dismiss() }
                    .foregroundStyle(EKitapligimPalette.teal)
            }
        }
        .task { await loadCatalog() }
        .onChange(of: query) { _, value in
            Task { await searchRemoteIfNeeded(value) }
        }
    }

    private func loadCatalog() async {
        guard catalog.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        catalog = (try? await container.books.books(page: 1, query: nil).books) ?? []
    }

    private func searchRemoteIfNeeded(_ value: String) async {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = nil
            return
        }
        searchResults = (try? await container.books.books(page: 1, query: trimmed).books) ?? []
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
            ToolbarItem(placement: .topBarLeading) {
                Button(L10n.commonDismiss) { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? L10n.commonSaving : L10n.commonSave) { Task { await save() } }
                    .disabled(isSaving || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    .onChange(of: message) { _, value in message = String(value.prefix(2_000)) }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(EKitapligimPalette.danger) }
            }
        }
        .navigationTitle(L10n.agendaCommentEditTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(L10n.commonDismiss) { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? L10n.commonSaving : L10n.commonSave) { Task { await save() } }
                    .disabled(isSaving || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
