import SwiftUI
import UIKit
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

    @StateObject private var model = BookAgendaFeedModel()
    @State private var tab: BookAgendaTab
    @State private var filter: BookAgendaFilter = .all
    @State private var selectedInitialTab = false
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
                    if let actionMessage = model.actionMessage {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load(reset: true) } } label: {
                    Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44)
                }.disabled(model.isLoading).accessibilityLabel(L10n.agendaRefresh)
                    .accessibilityIdentifier("agenda.refresh")
            }
        }
        .task {
            configureModel()
            if !selectedInitialTab {
                tab = container.isSignedIn ? .personal : .agenda
                selectedInitialTab = true
            }
            await load(reset: true)
        }
        .onChange(of: container.sessionRevision) { _, _ in
            configureModel()
            tab = container.isSignedIn ? .personal : .agenda
            if !container.isSignedIn { filter = .all }
            selectedPostID = nil
            editingPost = nil
            pendingDeletion = nil
            showingComposer = false
            Task { await load(reset: true) }
        }
        .onChange(of: container.blockedUserIDs) { _, ids in
            model.setBlockedActors(Set(ids.map { String($0) }))
        }
        .navigationDestination(item: $selectedPostID) { id in
            BookAgendaDetailView(postID: id, onPostUpdated: { model.replace($0) }, onPostDeleted: { model.remove(postID: $0) })
        }
        .sheet(isPresented: $showingComposer) {
            BookAgendaComposerView { _ in Task { await load(reset: true) } }
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
        VStack(alignment: .leading, spacing: 12) {
            ModernHeroView(
                artwork: "agenda_reader_community",
                eyebrow: CommunityRefreshL10n.text("agenda.eyebrow"),
                title: CommunityRefreshL10n.text("agenda.title"),
                subtitle: CommunityRefreshL10n.text("agenda.body"),
                accent: Color(hex: 0x21636A),
                minHeight: 285,
                actionTitle: CommunityRefreshL10n.text(container.isSignedIn ? "agenda.join" : "agenda.guestJoin")
            ) {
                if !container.isSignedIn { showingLogin = true }
                else if model.canCreate { showingComposer = true }
                else { model.actionMessage = L10n.forumThreadReplyPermissionHint }
            }
            Button {
                filter = .quotation
                Task { await load(reset: true) }
            } label: {
                Label(CommunityRefreshL10n.text("agenda.quotations"), systemImage: "quote.opening")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x2B6268))
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color(hex: 0xFFFCF5), in: Capsule())
                    .overlay(Capsule().stroke(Color(hex: 0xDDE4D6)))
            }.buttonStyle(.plain)
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
            if !container.isSignedIn {
                showingLogin = true
            } else if model.canCreate {
                showingComposer = true
            }
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
                    Text(
                        container.isSignedIn
                            ? (model.canCreate ? L10n.agendaComposerPromptSubtitle : L10n.forumThreadReplyPermissionHint)
                            : L10n.agendaComposerGuestSubtitle
                    )
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                        .fixedSize(horizontal: false, vertical: true)
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
        .disabled(container.isSignedIn && !model.canCreate)
        .accessibilityIdentifier("agenda.composer.open")
    }

    // MARK: Akış içeriği

    @ViewBuilder private var feed: some View {
        if model.isLoading && model.posts.isEmpty {
            EKSkeletonCard(height: 168)
            EKSkeletonCard(height: 168)
        } else if let errorMessage = model.errorMessage, model.posts.isEmpty {
            EKStateCard(
                title: L10n.agendaFeedErrorTitle,
                message: errorMessage,
                retryTitle: L10n.commonRetry,
                retry: { Task { await load(reset: true) } },
                systemImage: "books.vertical.fill"
            )
        } else if model.posts.isEmpty {
            EKStateCard(title: L10n.agendaFeedEmptyTitle, message: L10n.agendaFeedEmptySubtitle, systemImage: "books.vertical.fill")
        } else {
            ForEach(model.posts.filter { post in
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
                        model.removeBlockedActor(actorID)
                    },
                    isSignedIn: container.isSignedIn,
                    currentUserID: container.profileState?.id,
                    isBusy: model.isMutating(postID: post.id)
                )
            }
            if let errorMessage = model.errorMessage, !model.posts.isEmpty {
                EKInlineError(
                    message: errorMessage,
                    retryTitle: L10n.commonRetryAgain,
                    retry: { Task { await load(reset: false) } },
                    showsIcon: false
                )
            }
            if model.hasMore {
                EKLoadMoreButton(
                    isLoading: model.isLoadingMore,
                    title: L10n.commonLoadMoreItems,
                    tint: EKitapligimPalette.agendaPurple
                ) {
                    Task { await load(reset: false) }
                }
            }
        }
    }

    // MARK: Veri

    private func configureModel() {
        model.configure(dependencies: .init(repository: container.bookAgenda), signedIn: container.isSignedIn,
                        sessionID: container.sessionRevision.uuidString)
        model.setBlockedActors(Set(container.blockedUserIDs.map { String($0) }))
    }

    private func load(reset: Bool) async {
        configureModel()
        await model.load(tab: tab, filter: filter.rawValue.isEmpty ? nil : filter.rawValue, reset: reset)
    }

    private func replace(_ post: BookAgendaPostDTO) { model.replace(post) }

    private func react(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        await model.react(post)
    }

    private func bookmark(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        await model.bookmark(post)
    }

    private func repost(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        await model.repost(post)
    }

    private func toggleFollow(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        await model.toggleFollow(post)
    }

    private func delete(_ post: BookAgendaPostDTO) async {
        pendingDeletion = nil
        await model.delete(post)
    }
}

// MARK: - Gönderi kartı

struct BookAgendaPostCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var actionColumnWidth = 72.0
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
    var currentUserID: String? = nil
    var showsCommentAction: Bool = true
    var isBusy: Bool = false

    private var canManagePost: Bool {
        isSignedIn && (post.viewer.canEdit || post.viewer.canDelete)
    }

    private var isOwnPost: Bool {
        guard let currentUserID, !currentUserID.isEmpty else { return false }
        return post.actor.id == currentUserID
    }

    private var kind: BookAgendaPostType {
        BookAgendaPostType(rawValue: post.type) ?? .standard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            VStack(alignment: .leading, spacing: 11) {
            typeBadges
            bodyContent
            if let quotedPost = post.quotedPost {
                quotedPostCard(quotedPost)
            }
            if let book = post.book {
                BookAgendaBookChip(book: book)
            }
            attachments
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityIdentifier("agenda.post.\(post.id)")
            actionsRow.disabled(isBusy)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AgendaCardPalette(type: post.type).paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(post.isFeatured ? Color(hex: 0xE6C878) : AgendaCardPalette(type: post.type).border, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    private var header: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 11)) : AnyLayout(HStackLayout(spacing: 11))) {
            NavigationLink {
                MemberProfileView(memberID: post.actor.id)
            } label: {
            HStack(spacing: 11) {
            EKAvatar(urlString: post.actor.avatarUrl, username: post.actor.username, size: 44, cornerRadius: 15, background: Color(hex: 0xE7F7F7))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(post.actor.username)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.agendaInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(Int(post.actor.id).map { $0 <= 0 } ?? true)
            .accessibilityIdentifier("agenda-author-\(post.id)")
            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if isSignedIn && !isOwnPost {
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
                    .disabled(isBusy)
                }

                if canManagePost || (!isOwnPost && Int(post.id) != nil) {
                    if let contentID = Int(post.id) {
                        UGCSafetyMenu(
                            type: .agendaPost,
                            contentID: contentID,
                            userID: isOwnPost ? nil : Int(post.actor.id),
                            onBlocked: onBlocked,
                            onEdit: (post.viewer.canEdit) ? onEdit : nil,
                            onDelete: (post.viewer.canDelete) ? onDelete : nil,
                            includeSafetyActions: !isOwnPost
                        )
                    } else if canManagePost {
                        Menu {
                            if post.viewer.canEdit { Button(L10n.commonEdit, action: onEdit) }
                            if post.viewer.canDelete { Button(L10n.commonDelete, role: .destructive, action: onDelete) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(EKitapligimPalette.agendaMuted)
                                .frame(width: 30, height: 30)
                        }
                        .accessibilityLabel(L10n.agendaPostOptions)
                    }
                }
            }
        }
    }

    private var typeBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { typeBadgeItems }
                .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) { typeBadgeItems }
        }
    }

    @ViewBuilder private var typeBadgeItems: some View {
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

    private var typeAccent: Color { AgendaCardPalette(type: post.type).accent }

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
                MemberProfileLink(memberID: quoted.userId) {
                    Text(L10n.agendaQuotedFrom(quoted.username))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.agendaPurple)
                }
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: min(actionColumnWidth, 180)), spacing: 4)], alignment: .leading, spacing: 4) {
            actionButton(
                systemImage: post.viewer.reacted ? "heart.fill" : "heart",
                count: post.reactionScore,
                tint: post.viewer.reacted ? EKitapligimPalette.agendaPurple : EKitapligimPalette.agendaMuted,
                label: L10n.agendaReact,
                action: isSignedIn ? onReact : onRequireLogin,
                isEnabled: !isSignedIn || post.viewer.canReact
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
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel(EKitapligimFormat.count(post.viewCount))
            }
        }
    }

    private func actionButton(
        systemImage: String,
        count: Int?,
        tint: Color,
        label: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true
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
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(count.map { "\(label), \($0)" } ?? label)
    }
}

struct BookAgendaBookChip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let book: BookAgendaBookDTO

    var body: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))) {
            EKitapligimRemoteCover(urlString: book.coverUrl ?? "", title: book.title, author: book.author)
                .frame(width: 46, height: 66)
                .background(Color(hex: 0xE6EBEF))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.agendaInk)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.replyViewportHeight) private var replyViewportHeight
    let postID: String
    var onPostUpdated: ((BookAgendaPostDTO) -> Void)? = nil
    var onPostDeleted: ((String) -> Void)? = nil

    @StateObject private var model = BookAgendaDetailModel()
    @FocusState private var commentFocused: Bool
    @State private var showingLogin = false
    @State private var editingPost: BookAgendaPostDTO?
    @State private var pendingDeletion: BookAgendaPostDTO?
    @State private var editingComment: BookAgendaCommentDTO?
    @State private var pendingCommentDeletion: BookAgendaCommentDTO?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if model.isLoading && model.post == nil {
                        EKSkeletonCard(height: 180)
                    } else if let post = model.post {
                        BookAgendaPostCard(
                            post: post,
                            onReact: { Task { await react() } },
                            onBookmark: { Task { await bookmark() } },
                            onRepost: { Task { await repost() } },
                            onEdit: { editingPost = post },
                            onDelete: { pendingDeletion = post },
                            onFollow: { Task { await toggleFollow(post) } },
                            onRequireLogin: { showingLogin = true },
                            onBlocked: {
                                if let userID = Int(post.actor.id) { container.rememberBlockedUser(userID) }
                                model.invalidate()
                                dismiss()
                            },
                            isSignedIn: container.isSignedIn,
                            currentUserID: container.profileState?.id,
                            showsCommentAction: false,
                            isBusy: model.isPerformingAction || model.isSubmitting
                        )
                        if let errorMessage = model.errorMessage {
                            EKInlineError(message: errorMessage, retryTitle: L10n.commonRetry,
                                          retry: { Task { await load() } })
                        }
                        commentsSection(post: post)
                    } else {
                        EKStateCard(
                            title: L10n.agendaDetailErrorTitle,
                            message: model.errorMessage ?? L10n.agendaDetailErrorMessage,
                            retryTitle: L10n.commonRetry,
                            retry: { Task { await load() } },
                            systemImage: "books.vertical.fill"
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("agenda.detail.scroll")
            .onChange(of: commentFocused) { _, focused in
                if focused {
                    withAnimation { proxy.scrollTo("agenda.comment.composer", anchor: .bottom) }
                }
            }
            .task(id: replyViewportHeight) {
                guard commentFocused else { return }
                await Task.yield()
                guard !Task.isCancelled, commentFocused else { return }
                proxy.scrollTo("agenda.comment.composer", anchor: .bottom)
            }
        }
        .background { EKitapligimPageBackground() }
        // The floating assistant otherwise covers the comment submit button on small screens.
        .preference(key: AILauncherHiddenKey.self, value: true)
        .navigationTitle(L10n.agendaTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.commonClose) { commentFocused = false }
                    .accessibilityIdentifier("agenda.comment.keyboard.close")
            }
        }
        .sheet(isPresented: $showingLogin) { LoginView() }
        .sheet(item: $editingPost) { item in
            NavigationStack {
                BookAgendaEditView(post: item) { updated in
                    model.updatePost(updated)
                    publishPostUpdate()
                }
            }
        }
        .sheet(item: $editingComment) { comment in
            NavigationStack {
                BookAgendaCommentEditView(comment: comment) { updated in
                    model.updateComment(updated)
                    publishPostUpdate()
                }
            }
        }
        .alert(L10n.agendaPostDeleteTitle, isPresented: postDeletionBinding) {
            Button(L10n.commonDismiss, role: .cancel) { pendingDeletion = nil }
            Button(L10n.commonDelete, role: .destructive) {
                if let item = pendingDeletion { Task { await deletePost(item) } }
            }
        } message: { Text(L10n.agendaPostDeleteMessage) }
        .alert(L10n.agendaCommentDeleteTitle, isPresented: commentDeletionBinding) {
            Button(L10n.commonDismiss, role: .cancel) { pendingCommentDeletion = nil }
            Button(L10n.commonDelete, role: .destructive) {
                if let comment = pendingCommentDeletion { Task { await deleteComment(comment) } }
            }
        } message: { Text(L10n.agendaCommentDeleteMessage) }
        .task { await load() }
        .onChange(of: container.sessionRevision) { _, _ in
            model.invalidate()
            commentFocused = false
            editingPost = nil
            editingComment = nil
            pendingDeletion = nil
            pendingCommentDeletion = nil
            Task { await load() }
        }
        .onDisappear { commentFocused = false; model.invalidate(clear: false) }
    }

    private var postDeletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var commentDeletionBinding: Binding<Bool> {
        Binding(get: { pendingCommentDeletion != nil }, set: { if !$0 { pendingCommentDeletion = nil } })
    }

    private var visibleComments: [BookAgendaCommentDTO] {
        model.comments.filter { comment in
            guard let userID = Int(comment.actor.id) else { return true }
            return !container.blockedUserIDs.contains(userID)
        }
    }

    private func commentsSection(post: BookAgendaPostDTO) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(L10n.agendaCommentsHeader(post.commentCount))
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.agendaInk)
                .accessibilityIdentifier("agenda.comments.count")
            if let commentsError = model.commentsError {
                EKInlineError(message: commentsError, retryTitle: L10n.commonRetry) {
                    Task {
                        let repository = container.bookAgenda
                        await model.loadComments { try await repository.comments(postID: postID) }
                    }
                }
                .accessibilityIdentifier("agenda.comments.error")
            }
            if model.isLoadingComments && visibleComments.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 60)
            } else if visibleComments.isEmpty && model.commentsError == nil {
                EKStateCard(title: L10n.agendaCommentsEmptyTitle, message: L10n.agendaCommentsEmptySubtitle, systemImage: "books.vertical.fill")
            }
            ForEach(visibleComments) { comment in
                BookAgendaCommentRow(
                    comment: comment,
                    currentUserID: container.profileState?.id,
                    onEdit: { editingComment = comment },
                    onDelete: { pendingCommentDeletion = comment },
                    onBlocked: { model.removeComments(actorID: comment.actor.id) }
                )
                .disabled(model.isPerformingAction)
            }
            composer(post: post).id("agenda.comment.composer")
        }
    }

    private var usesCompactCommentComposer: Bool { replyViewportHeight < 300 }

    private func composer(post: BookAgendaPostDTO) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if container.isSignedIn && post.viewer.canComment {
                if !usesCompactCommentComposer {
                    Button { commentFocused = true } label: {
                        Text(L10n.agendaCommentComposerTitle)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("agenda.comment.focus")
                }
                (usesCompactCommentComposer
                    ? AnyLayout(HStackLayout(alignment: .bottom, spacing: 8))
                    : AnyLayout(VStackLayout(alignment: .leading, spacing: 9))) {
                TextField(L10n.agendaCommentPlaceholder, text: $model.draft, axis: .vertical)
                    .lineLimit(usesCompactCommentComposer ? 1...1 : 2...6)
                    .focused($commentFocused)
                    .padding(usesCompactCommentComposer ? 6 : 11)
                    .frame(maxWidth: .infinity, minHeight: usesCompactCommentComposer ? 44 : 72, alignment: .topLeading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(commentFocused ? EKitapligimPalette.agendaPurple : EKitapligimPalette.agendaBorder, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture().onEnded { commentFocused = true })
                    .onChange(of: model.draft) { _, value in
                        if value.count > 2_000 { model.draft = String(value.prefix(2_000)) }
                    }
                    .accessibilityLabel(L10n.agendaCommentComposerTitle)
                    .accessibilityIdentifier("agenda.comment.message")

                Button {
                    Task { await submitComment() }
                } label: {
                    HStack(spacing: 6) {
                        if model.isSubmitting { ProgressView().tint(.white) }
                        else {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.system(size: 17, weight: .semibold))
                                .accessibilityHidden(true)
                        }
                        if !usesCompactCommentComposer {
                            Text(model.isSubmitting ? L10n.agendaCommentSubmitting : L10n.agendaCommentSubmit)
                                .font(.subheadline.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minWidth: 44, maxWidth: usesCompactCommentComposer ? 44 : .infinity, minHeight: 44)
                    .background(EKitapligimPalette.agendaPurple, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.isSubmitting || model.isPerformingAction || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(model.isSubmitting ? L10n.agendaCommentSubmitting : L10n.agendaCommentSubmit)
                .accessibilityIdentifier("agenda.comment.submit")
                }
            } else if container.isSignedIn {
                Text(CommunityRefreshL10n.text("agenda.commentPermission"))
                    .font(.subheadline)
                    .accessibilityIdentifier("agenda.comment.permission")
            } else {
                Text(L10n.agendaCommentGuestTitle).font(.subheadline.weight(.bold))
                Button(L10n.commonLogin) { showingLogin = true }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("agenda.comment.login")
            }
            if let actionMessage = model.actionMessage {
                EKInlineError(message: actionMessage).accessibilityIdentifier("agenda.comment.error")
            }
        }
        .foregroundStyle(EKitapligimPalette.agendaInk)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EKitapligimPalette.agendaBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func publishPostUpdate() {
        if let post = model.post { onPostUpdated?(post) }
    }

    private func load() async {
        let repository = container.bookAgenda
        await model.load(fetchPost: { try await repository.post(id: postID) },
                         fetchComments: { try await repository.comments(postID: postID) })
    }

    private func react() async {
        guard container.isSignedIn else { showingLogin = true; return }
        let repository = container.bookAgenda
        await model.performAction(mutate: {
            guard try await repository.toggleReaction(postID: postID).success else { throw APIClientError.invalidResponse }
        },
                                  refresh: { try await repository.post(id: postID) })
        publishPostUpdate()
    }

    private func bookmark() async {
        guard container.isSignedIn else { showingLogin = true; return }
        let repository = container.bookAgenda
        await model.performAction(mutate: {
            guard try await repository.toggleBookmark(postID: postID).success else { throw APIClientError.invalidResponse }
        },
                                  refresh: { try await repository.post(id: postID) })
        publishPostUpdate()
    }

    private func repost() async {
        guard container.isSignedIn else { showingLogin = true; return }
        let repository = container.bookAgenda
        await model.performAction(mutate: {
            guard try await repository.toggleRepost(postID: postID).success else { throw APIClientError.invalidResponse }
        },
                                  refresh: { try await repository.post(id: postID) })
        publishPostUpdate()
    }

    private func toggleFollow(_ post: BookAgendaPostDTO) async {
        guard container.isSignedIn else { showingLogin = true; return }
        let repository = container.bookAgenda
        await model.performAction(mutate: {
            guard let response = try await repository.setFollow(userID: post.actor.id, follow: !post.viewer.followingActor), response.success else {
                throw URLError(.unsupportedURL)
            }
        }, refresh: { try await repository.post(id: postID) })
        publishPostUpdate()
    }

    private func submitComment() async {
        guard container.isSignedIn else { showingLogin = true; return }
        let repository = container.bookAgenda
        let submitted = await model.submitComment { try await repository.createComment(postID: postID, message: $0) }
        if submitted { commentFocused = false; publishPostUpdate() }
    }

    private func deletePost(_ item: BookAgendaPostDTO) async {
        pendingDeletion = nil
        let repository = container.bookAgenda
        if await model.deletePost(delete: { try await repository.deletePost(id: item.id) }) {
            onPostDeleted?(item.id)
            dismiss()
        }
    }

    private func deleteComment(_ comment: BookAgendaCommentDTO) async {
        pendingCommentDeletion = nil
        let repository = container.bookAgenda
        await model.deleteComment(comment, delete: { try await repository.deleteComment(commentID: comment.id) })
        publishPostUpdate()
    }
}
private struct BookAgendaCommentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let comment: BookAgendaCommentDTO
    var currentUserID: String? = nil
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onBlocked: () -> Void

    private var isOwn: Bool {
        guard let currentUserID, !currentUserID.isEmpty else { return false }
        return comment.actor.id == currentUserID
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MemberProfileLink(memberID: comment.actor.id) {
                EKAvatar(urlString: comment.actor.avatarUrl, username: comment.actor.username, size: 38, cornerRadius: 13, background: Color(hex: 0xE7F7F7))
            }
            VStack(alignment: .leading, spacing: 4) {
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))) {
                    MemberProfileLink(memberID: comment.actor.id) {
                        Text(comment.actor.username)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.agendaInk)
                    }
                    Spacer(minLength: 0)
                    Text(EKitapligimFormat.relativeTime(comment.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(EKitapligimPalette.agendaMuted)
                    if comment.viewer.canEdit || comment.viewer.canDelete || Int(comment.id) != nil {
                        if let contentID = Int(comment.id) {
                            UGCSafetyMenu(
                                type: .agendaComment,
                                contentID: contentID,
                                userID: isOwn ? nil : Int(comment.actor.id),
                                onBlocked: onBlocked,
                                onEdit: (comment.viewer.canEdit) ? onEdit : nil,
                                onDelete: (comment.viewer.canDelete) ? onDelete : nil,
                                includeSafetyActions: !isOwn
                            )
                        } else {
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
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
    @FocusState private var focusedField: ComposerField?

    private enum ComposerField: String, Hashable {
        case message, page, current, total
    }

    private var requiresBook: Bool { type == .book || type == .quotation || type == .review || type == .progress }
    private var palette: AgendaComposerPalette { AgendaComposerPalette(colorScheme: colorScheme) }

    private var writingTitle: String {
        let key: String
        switch type {
        case .standard: key = "composer.noteTitle"
        case .book: key = "composer.bookTitle"
        case .quotation: key = "composer.quotationTitle"
        case .review: key = "composer.reviewTitle"
        case .progress: key = "composer.progressTitle"
        }
        return CommunityRefreshL10n.text(key)
    }

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    composerHeader
                    VStack(alignment: .leading, spacing: 18) {
                        typePicker
                        if requiresBook { bookSelection }
                        writingCard
                        if type == .quotation { quotationDetails }
                        if type == .review { reviewDetails }
                        if type == .progress { progressDetails }
                    }
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("agenda.composer.scroll")
            .background(palette.page)
            .safeAreaInset(edge: .bottom, spacing: 0) { submitBar }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.commonClose) { focusedField = nil }
                        .tint(palette.accent)
                        .accessibilityIdentifier("agenda.composer.keyboard.close")
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
        .presentationBackground(palette.page)
        .presentationCornerRadius(30)
        .interactiveDismissDisabled(isSubmitting)
        .accessibilityIdentifier("agenda.composer")
    }

    private var composerHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.menuBookAgenda, systemImage: "square.and.pencil")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.accent)
                    Text(L10n.agendaComposerTitle)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.muted)
                        .frame(width: 44, height: 44)
                        .background(palette.surface, in: Circle())
                        .overlay { Circle().strokeBorder(palette.border, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .accessibilityLabel(L10n.commonClose)
                .accessibilityIdentifier("agenda.composer.close")
            }
            Text(L10n.agendaComposerSubtitle)
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CommunityRefreshL10n.text("composer.typeTitle"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.muted)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 140 : 90), spacing: 8)], spacing: 8) {
                ForEach(composerTypeOptions, id: \.0) { option in
                    typeOption(option.0, title: option.1)
                }
            }
        }
    }

    private func typeOption(_ option: BookAgendaPostType, title: String) -> some View {
        let selected = type == option
        return Button {
            type = option
        } label: {
            VStack(spacing: 8) {
                Image(systemName: typeIcon(option))
                    .font(.body.weight(.medium))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(selected ? .white : palette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? palette.selection : LinearGradient(colors: [palette.surface], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? .clear : palette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("agenda.composer.type.\(option.rawValue)")
    }

    private func typeIcon(_ type: BookAgendaPostType) -> String {
        switch type {
        case .standard: "square.and.pencil"
        case .book: "book.closed"
        case .quotation: "quote.opening"
        case .review: "star.bubble"
        case .progress: "bookmark"
        }
    }

    private var bookSelection: some View {
        Button {
            focusedField = nil
            showingBookPicker = true
        } label: {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(spacing: 14))) {
                if let book = selectedBook {
                    EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
                        .frame(width: 42, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "book.closed")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 44, height: 56)
                        .background(palette.tintedSurface, in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    if let book = selectedBook {
                        Text(L10n.agendaTypeBook)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(palette.accent)
                        Text(book.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        if !book.author.isEmpty {
                            Text(book.author)
                                .font(.caption)
                                .foregroundStyle(palette.muted)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        }
                    } else {
                        Text(L10n.agendaComposerSelectBook)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text(CommunityRefreshL10n.text("composer.bookHint"))
                            .font(.caption)
                            .foregroundStyle(palette.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                Image(systemName: selectedBook == nil ? "plus" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(palette.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.agendaComposerSelectBook)
        .accessibilityValue(selectedBook.map { "\($0.title) · \($0.author)" } ?? CommunityRefreshL10n.text("composer.bookHint"))
        .accessibilityHint(selectedBook == nil ? L10n.agendaComposerSelectBook : CommunityRefreshL10n.text("composer.changeBook"))
        .accessibilityIdentifier("agenda.composer.book")
    }

    private var writingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(writingTitle, systemImage: typeIcon(type))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(palette.border).frame(height: 1).accessibilityHidden(true)
            TextField(
                type == .quotation ? L10n.agendaComposerQuotePlaceholder : L10n.agendaComposerPlaceholder,
                text: $message,
                axis: .vertical
            )
            .font(type == .quotation ? .system(.body, design: .serif) : .body)
            .foregroundStyle(palette.ink)
            .tint(palette.accent)
            .lineSpacing(4)
            .lineLimit(6...14)
            .focused($focusedField, equals: .message)
            .onChange(of: message) { _, value in message = String(value.prefix(5_000)) }
            .accessibilityLabel(writingTitle)
            .accessibilityIdentifier("agenda.composer.message")
            Text(CommunityRefreshL10n.count("composer.characterCount", message.count))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(palette.muted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(CommunityRefreshL10n.count("composer.characterCountAccessibility", message.count))
        }
        .padding(18)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(focusedField == .message ? palette.accent.opacity(0.65) : palette.border, lineWidth: 1)
        }
        .shadow(color: palette.accent.opacity(0.04), radius: 12, y: 4)
    }

    private var quotationDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            numericField(L10n.agendaComposerPageNumber, text: $pageNumber, field: .page)
            Text(CommunityRefreshL10n.text("composer.pageHint"))
                .font(.caption)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    private var reviewDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(CommunityRefreshL10n.text("composer.ratingTitle"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
            HStack(spacing: 7) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityHidden(true)
            Text(L10n.agendaComposerRating(rating))
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.muted)
            Slider(
                value: Binding(get: { Double(rating) }, set: { rating = Int($0.rounded()) }),
                in: 1...5,
                step: 1
            )
            .tint(palette.accent)
            .accessibilityLabel(L10n.agendaComposerRating(rating))
            .accessibilityIdentifier("agenda.composer.rating")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(palette.border, lineWidth: 1) }
    }

    private var progressDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CommunityRefreshL10n.text("composer.progressDetails"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) { progressFields }
            } else {
                HStack(alignment: .top, spacing: 10) { progressFields }
            }
        }
    }

    @ViewBuilder private var progressFields: some View {
        numericField(L10n.agendaComposerProgressCurrent, text: $progressCurrent, field: .current)
        numericField(L10n.agendaComposerProgressTotal, text: $progressTotal, field: .total)
    }

    private func numericField(_ title: String, text: Binding<String>, field: ComposerField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            TextField(CommunityRefreshL10n.text("composer.numberPlaceholder"), text: text)
                .font(.body.monospacedDigit())
                .foregroundStyle(palette.ink)
                .tint(palette.accent)
                .keyboardType(.numberPad)
                .frame(minHeight: 44)
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { _, value in text.wrappedValue = digits(value) }
                .accessibilityLabel(title)
                .accessibilityIdentifier("agenda.composer.\(field.rawValue)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(palette.border, lineWidth: 1) }
    }

    private var submitBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(palette.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("agenda.composer.error")
            }
            Label(L10n.agendaVisibilityPublic, systemImage: "globe.europe.africa")
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.muted)
                .accessibilityLabel("\(L10n.agendaPostVisibilityTitle) \(L10n.agendaVisibilityPublic)")
            Button {
                focusedField = nil
                Task { await submit() }
            } label: {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .accessibilityHidden(true)
                    }
                    Text(isSubmitting ? L10n.agendaComposerSubmitting : L10n.agendaComposerSubmit)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(palette.selection, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: palette.accent.opacity(0.15), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .accessibilityLabel(isSubmitting ? L10n.agendaComposerSubmitting : L10n.agendaComposerSubmit)
            .accessibilityIdentifier("agenda.composer.submit")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .background {
            palette.surface
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Rectangle().fill(palette.border).frame(height: 1) }
        }
    }

    private func digits(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(6))
    }

    private func submit() async {
        guard container.isSignedIn, !isSubmitting else { return }
        let sessionRevision = container.sessionRevision
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
            guard sessionRevision == container.sessionRevision, !Task.isCancelled else { return }
            onCreated(created)
            dismiss()
        } catch {
            errorMessage = (error as? APIClientError)?.serverMessage ?? L10n.agendaComposerFailed
        }
    }
}

private struct AgendaComposerPalette {
    let colorScheme: ColorScheme
    private var isDark: Bool { colorScheme == .dark }
    var page: Color { Color(hex: isDark ? 0x18161E : 0xF7F5FA) }
    var surface: Color { Color(hex: isDark ? 0x24212D : 0xFFFFFF) }
    var tintedSurface: Color { Color(hex: isDark ? 0x352C49 : 0xF0EBF8) }
    var ink: Color { Color(hex: isDark ? 0xF2EEF8 : 0x27213A) }
    var muted: Color { Color(hex: isDark ? 0xBCB6C8 : 0x6A6577) }
    var accent: Color { Color(hex: isDark ? 0xC7B8F1 : 0x6851A6) }
    var border: Color { Color(hex: isDark ? 0x443D53 : 0xE8E2F0) }
    var error: Color { Color(hex: isDark ? 0xFFB4AB : 0xB3261E) }
    var selection: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x735AB4), Color(hex: 0x59428F)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

@MainActor
private struct BookAgendaBookPicker: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                        EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
                            .frame(width: 38, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(book.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
        .task(id: query) { await searchRemoteIfNeeded(query) }
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
        do {
            try await Task.sleep(for: .milliseconds(250))
            let books = try await container.books.books(page: 1, query: trimmed).books
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
            searchResults = books
        } catch {
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
            searchResults = []
        }
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
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
        .onChange(of: container.sessionRevision) { _, _ in dismiss() }
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
        guard container.isSignedIn, !isSaving else { return }
        let sessionRevision = container.sessionRevision
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
            guard sessionRevision == container.sessionRevision, !Task.isCancelled else { return }
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
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
        .onChange(of: container.sessionRevision) { _, _ in dismiss() }
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
        guard container.isSignedIn, !isSaving else { return }
        let sessionRevision = container.sessionRevision
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await container.bookAgenda.updateComment(commentID: comment.id, message: trimmed)
            guard sessionRevision == container.sessionRevision, !Task.isCancelled else { return }
            onUpdated(updated)
            dismiss()
        } catch {
            errorMessage = L10n.agendaCommentUpdateFailed
        }
    }
}
