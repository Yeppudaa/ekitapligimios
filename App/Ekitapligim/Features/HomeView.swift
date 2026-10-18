import SwiftUI
import EkitapligimCore

@MainActor
struct HomeView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var hostsAudioNavigation = false
    var onOpenMenu: (() -> Void)? = nil

    @State private var stats: SiteStatsDTO?
    @State private var popularBooks: [BookDTO] = []
    @State private var newestBooks: [BookDTO] = []
    @State private var premiumBooks: [BookDTO] = []
    @State private var editorialBooks: [BookDTO] = []
    @State private var categoryForums: [ForumDTO] = BookCategoryCatalog.defaults
    @State private var agendaPosts: [BookAgendaPostDTO] = []
    @State private var liveItems: [LiveActivityItemDTO] = []
    @State private var chatRoom: ChatRoomDTO?
    @State private var chatPreview: [ChatMessageDTO] = []
    @State private var chatNewestID: String?
    @State private var bookRequestPreview: [BookRequestDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EKitapligimPageBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        headerBlock
                        heroCard
                        searchBar
                        nextBookSection
                        genreSection
                        chatPreviewCard
                        continueReadingCard
                        if let repository = container.audioRepository, let controller = container.audioPlayback {
                            AudioHomePreviewView(repository: repository, controller: controller, account: container.audioAccount,
                                onBook: { container.open(route: .audiobook($0)) },
                                onBrowse: { container.open(route: .audiobooks) },
                                onLibrary: { container.open(route: .audioLibrary(tab: "saved")) })
                                .padding(.horizontal, 16)
                        }
                        agendaRail
                        communityBanner
                        newArrivalsSection
                        dailySelectionSection
                        ModernHomePromoPair()
                            .padding(.horizontal, 16)
                        ModernHomeCategoryShowcase(forums: categoryForums, books: newestBooks + popularBooks) {
                            container.open(route: .catalog)
                        }
                        .padding(.horizontal, 16)
                        ModernHomeLibraryBanner(stats: stats,
                            onLibrary: { container.open(route: .library(tab: 0)) },
                            onBooks: { container.open(route: .catalog) },
                            onAuthors: { container.open(route: .authors) },
                            onCategories: { container.open(route: .catalog) })
                            .padding(.horizontal, 16)
                        if let errorMessage {
                            EKInlineError(message: errorMessage, retryTitle: L10n.commonRetry) {
                                Task { await load() }
                            }
                            .padding(.horizontal, 16)
                        }
                        discoverySection
                        liveActivityCard
                        if !premiumBooks.isEmpty {
                            bookRail(
                                title: L10n.homePremiumRailTitle,
                                subtitle: L10n.homePremiumRailSubtitle,
                                books: premiumBooks,
                                identifier: "premium"
                            )
                        }
                        requestCenterCard
                    }
                    .padding(.bottom, 28)
                }
                .refreshable {
                    async let categoryRequest: Void = loadCategoryForums()
                    await load()
                    await loadEditorialBooks()
                    await categoryRequest
                    await refreshDynamicContent(force: true)
                }
                .accessibilityIdentifier("home.scroll")
                .clipped()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                BookDetailDestination(bookIDString: id)
            }
            .audioPageNavigation(enabled: hostsAudioNavigation)
            .task {
                async let editorRequest: Void = loadEditorialBooks()
                async let categoryRequest: Void = loadCategoryForums()
                await loadIfNeeded()
                await editorRequest
                await categoryRequest
                await refreshDynamicContent()
                startChatPolling()
            }
            .onAppear {
                Task { await refreshDynamicContent() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .audioActivityChanged)) { _ in
                Task { await refreshDynamicContent(force: true) }
            }
            .onDisappear { chatPollTask?.cancel() }
        }
    }

    @State private var chatPollTask: Task<Void, Never>?
    @State private var isRefreshingDynamic = false
    @State private var lastDynamicRefresh: Date?

    // MARK: - Üst bölüm

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { headerBrand; Spacer(minLength: 4); premiumShortcut.fixedSize() }
                VStack(alignment: .leading, spacing: 10) { headerBrand; premiumShortcut }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onOpenMenu {
                EKitapligimMenuButton(action: onOpenMenu)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var headerBrand: some View {
        EKitapligimBrandLogo().frame(width: 130, height: 52)
    }

    private var premiumShortcut: some View {
        Button { container.open(route: .premium) } label: {
            Label(L10n.premiumShortTitle, systemImage: "crown.fill")
                .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 48)
                .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain)
        .accessibilityIdentifier("shell.home.premium")
    }

    private var heroCard: some View {
        ModernHeroView(
            artwork: "home_hero_scene",
            eyebrow: HomeRefreshL10n.text("hero.eyebrow"),
            title: HomeRefreshL10n.text("hero.title"),
            subtitle: HomeRefreshL10n.text("hero.subtitle"),
            minHeight: 260,
            actionTitle: HomeRefreshL10n.text("hero.explore")
        ) { container.open(route: .catalog) }
        .padding(.horizontal, 16)
        .accessibilityIdentifier("home.scenicHero")
    }

    @ViewBuilder private var nextBookSection: some View {
        if let newestBook = newestBooks.first {
            VStack(alignment: .leading, spacing: 12) {
                ModernSectionHeading(title: HomeRefreshL10n.text("next.title"), subtitle: "", actionTitle: L10n.homeSeeAll) {
                    container.open(route: .catalog)
                }
                ModernHomeSpotlight(book: newestBook)
            }
            .padding(.horizontal, 16)
        }
    }

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeading(title: HomeRefreshL10n.text("genre.title"), subtitle: "", actionTitle: L10n.homeSeeAll) {
                container.open(route: .catalog)
            }.padding(.horizontal, 16)
            ModernHomeGenreStrip()
        }
    }

    private var communityBanner: some View {
        ModernHeroView(artwork: "home_community_scene", eyebrow: HomeRefreshL10n.text("chat.eyebrow"),
            title: HomeRefreshL10n.text("community.title"), subtitle: HomeRefreshL10n.text("community.subtitle"),
            minHeight: 220, actionTitle: HomeRefreshL10n.text("community.action")) {
            container.open(route: .forum)
        }
        .padding(.horizontal, 16)
    }

    private var newArrivalsSection: some View {
        VStack(spacing: 16) {
            ModernHeroView(artwork: "home_section_new_arrivals", eyebrow: HomeRefreshL10n.text("new.eyebrow"),
                title: HomeRefreshL10n.text("new.title"), subtitle: HomeRefreshL10n.text("new.subtitle"), minHeight: 180,
                actionTitle: L10n.homeSeeAll) { container.open(route: .catalog) }
                .padding(.horizontal, 16)
            bookRail(title: L10n.homeNewestTitle, subtitle: L10n.homeNewestSubtitle, books: newestBooks, identifier: "newest")
        }
    }

    @ViewBuilder private var dailySelectionSection: some View {
        if !editorialBooks.isEmpty || !popularBooks.isEmpty {
            VStack(spacing: 16) {
                ModernHeroView(artwork: "home_section_daily_selection", eyebrow: HomeRefreshL10n.text("daily.eyebrow"),
                    title: HomeRefreshL10n.text("daily.title"), subtitle: HomeRefreshL10n.text("daily.subtitle"), minHeight: 180,
                    actionTitle: L10n.homeSeeAll) { container.open(route: .catalog) }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        editorialPanel.frame(minWidth: 300)
                        popularPanel.frame(minWidth: 300)
                    }
                    VStack(spacing: 14) { editorialPanel; popularPanel }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var editorialPanel: some View {
        if !editorialBooks.isEmpty {
            ModernHomeEditorialPanel(title: HomeRefreshL10n.text("daily.editor"), icon: "star", books: editorialBooks, tint: EKitapligimPalette.teal)
        }
    }

    @ViewBuilder private var popularPanel: some View {
        if !popularBooks.isEmpty {
            ModernHomeEditorialPanel(title: HomeRefreshL10n.text("daily.popular"), icon: "flame", books: popularBooks, tint: EKitapligimPalette.amber)
        }
    }

    private var searchBar: some View {
        Button { container.open(route: .catalog) } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.teal)
                Text(L10n.homeSearchPlaceholder)
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(EKitapligimPalette.teal)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 14)
            .frame(minHeight: 58)
            .ekitapligimCard(radius: 17)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.homeSearchPlaceholder)
        .padding(.horizontal, 16)
    }

    // MARK: - Devam et

    @ViewBuilder private var continueReadingCard: some View {
        if container.isSignedIn {
            VStack(alignment: .leading, spacing: 12) {
                Text(HomeRefreshL10n.text("continue.eyebrow"))
                    .font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(EKitapligimPalette.muted)
                ModernSectionHeading(title: HomeRefreshL10n.text("continue.title"), subtitle: "", actionTitle: L10n.libraryHeaderTitle) {
                    container.open(route: .library(tab: 0))
                }
                ModernHomeReadingPanel(item: container.continueReadingItem,
                    otherBooks: Array(container.currentlyReading.filter { $0.bookId != container.continueReadingItem?.bookId }.prefix(2)),
                    onRead: openReader)
            }
            .padding(.horizontal, 16)
        }
    }

    private func openReader(_ bookID: String) {
        guard let id = Int(bookID), id > 0, id <= Int(Int32.max) else { return }
        container.open(route: .reader(id))
    }

    // MARK: - Keşif Merkezi

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeading(
                title: L10n.homeDiscoveryTitle,
                subtitle: L10n.homeDiscoverySubtitle,
                actionTitle: L10n.homeSeeAll
            ) { container.open(route: .catalog) }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    discoveryCard(
                        badge: L10n.homeDiscoveryCatalogBadge,
                        title: L10n.tabCatalogShort,
                        subtitle: L10n.homeDiscoveryCatalogSubtitle,
                        tint: EKitapligimPalette.teal,
                        systemImage: "books.vertical.fill"
                    ) { container.open(route: .catalog) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryAgendaBadge,
                        title: L10n.menuBookAgenda,
                        subtitle: L10n.homeDiscoveryAgendaSubtitle,
                        tint: EKitapligimPalette.agendaPurple,
                        systemImage: "square.text.square.fill"
                    ) { container.open(route: .bookAgenda) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryChatBadge,
                        title: L10n.menuChat,
                        subtitle: L10n.homeDiscoveryChatSubtitle,
                        tint: EKitapligimPalette.chatTeal,
                        systemImage: "bubble.left.and.bubble.right.fill"
                    ) { container.open(route: .chat) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryLiveBadge,
                        title: L10n.homeDiscoveryLiveTitle,
                        subtitle: L10n.homeDiscoveryLiveSubtitle,
                        tint: EKitapligimPalette.liveOrange,
                        systemImage: "bolt.horizontal.circle.fill"
                    ) { container.open(route: .liveActivity) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryRequestsBadge,
                        title: L10n.menuRequests,
                        subtitle: L10n.homeDiscoveryRequestsSubtitle,
                        tint: Color(hex: 0xD45F7A),
                        systemImage: "heart.text.square.fill"
                    ) { container.open(route: .requests) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryForumBadge,
                        title: L10n.tabForum,
                        subtitle: L10n.homeDiscoveryForumSubtitle,
                        tint: Color(hex: 0x3D75C5),
                        systemImage: "text.bubble.fill"
                    ) { container.open(route: .forum) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryProfileBadge,
                        title: L10n.tabProfile,
                        subtitle: L10n.homeDiscoveryProfileSubtitle,
                        tint: Color(hex: 0x8A6B3E),
                        systemImage: "person.crop.circle.fill"
                    ) { container.selectedTab = .profile }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color(red: 242 / 255, green: 250 / 255, blue: 250 / 255), Color(red: 255 / 255, green: 252 / 255, blue: 246 / 255)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func discoveryCard(
        badge: String,
        title: String,
        subtitle: String,
        tint: Color,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    EKPill(title: badge, foreground: tint, background: tint.opacity(0.12))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    Spacer(minLength: 0)
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.9))
                }
                UniformCardText(title, lines: 2)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                UniformCardText(subtitle, lines: 2)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
            .padding(14)
            .containerRelativeFrame(.horizontal) { length, _ in
                min(220, max(1, length - 32))
            }
            .frame(minHeight: 140)
            .background(
                LinearGradient(
                    colors: [.white, tint.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.18))
            }
            .shadow(color: tint.opacity(0.12), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sohbet önizlemesi

    @ViewBuilder private var chatPreviewCard: some View {
        VStack(spacing: 0) {
            ModernHeroView(artwork: "community_reader_salon", eyebrow: HomeRefreshL10n.text("chat.eyebrow"),
                title: HomeRefreshL10n.text("chat.title"), subtitle: HomeRefreshL10n.text("chat.subtitle"), minHeight: 180)
            EKChatHomePreviewCard(
            roomName: chatRoom?.name ?? L10n.menuChat,
            roomDescription: {
                let trimmed = chatRoom?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? L10n.homeChatCardSubtitle : trimmed
            }(),
            onlineCount: chatRoom?.userCount ?? 0,
            messages: chatPreview,
            emptyMessage: L10n.homeChatCardEmpty,
            actionTitle: L10n.homeChatCardAction
        ) {
                container.open(route: .chat)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Kitap Gündemi rayı

    private var agendaRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeading(
                title: L10n.menuBookAgenda,
                subtitle: L10n.homeAgendaRailSubtitle,
                actionTitle: L10n.homeSeeAll
            ) { container.open(route: .bookAgenda) }
            .padding(.horizontal, 16)

            if agendaPosts.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "text.quote")
                        .font(.title2)
                        .foregroundStyle(HomeAgendaStyle.accent)
                        .accessibilityHidden(true)
                    Text(L10n.homeAgendaRailEmpty)
                        .font(.subheadline)
                        .foregroundStyle(HomeAgendaStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(HomeAgendaStyle.paper, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 16)
            } else if dynamicTypeSize.isAccessibilitySize {
                // Large text needs the full intrinsic height of names, quotations and book context.
                // Keep these cards in the page's vertical scroll instead of the fixed-height rail.
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(agendaPosts.prefix(4)) { post in
                        homeAgendaCard(post, layout: .adaptive)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 14) {
                        ForEach(agendaPosts.prefix(4)) { post in
                            homeAgendaCard(post, layout: .rail)
                            .containerRelativeFrame(.horizontal) { length, _ in
                                min(340, max(1, length - 52))
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func homeAgendaCard(_ post: BookAgendaPostDTO, layout: HomeAgendaCardLayout) -> some View {
        HomeAgendaCard(post: post, layout: layout) {
            guard let postID = Int(post.id), postID > 0 else { return }
            container.open(route: .bookAgendaPost(postID))
        }
        .accessibilityIdentifier("home.agenda.\(post.id)")
    }

    // MARK: - Kitap rayları

    private func bookRail(title: String, subtitle: String, books: [BookDTO], identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeading(title: title, subtitle: subtitle, actionTitle: L10n.homeSeeAll) {
                container.open(route: .catalog)
            }
            .padding(.horizontal, 16)

            if isLoading && books.isEmpty {
                ProgressView().tint(EKitapligimPalette.teal).frame(maxWidth: .infinity, minHeight: 180)
            } else if !books.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    // This bounded eight-card rail must supply its natural height inside the
                    // vertically scrolling home page, including at accessibility text sizes.
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(books.prefix(8)) { book in
                            NavigationLink(value: book.id) { HomeBookCard(book: book) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("home.bookRail.\(identifier).book.\(book.id)")
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.bookRail.\(identifier)")
            }
        }
    }

    // MARK: - Canlı aktivite

    private var liveActivityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { container.open(route: .liveActivity) } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        EKLiveBadge(showsPulse: true)
                        Text(L10n.liveActivityTitle)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                        Text(L10n.homeLiveCardSubtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "waveform.path.ecg")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .accessibilityElement(children: .combine)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [EKitapligimPalette.tealDark, EKitapligimPalette.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.liveActivityTitle)

            VStack(alignment: .leading, spacing: 0) {
                if liveItems.isEmpty {
                    Text(L10n.homeLiveCardEmpty)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .padding(16)
                } else {
                    ForEach(Array(liveItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                        LiveActivityRow(item: item, style: .compact, showsChevron: false)
                        if index < min(liveItems.count, 3) - 1 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }

                Button { container.open(route: .liveActivity) } label: {
                    HStack {
                        Spacer()
                        Text(L10n.homeLiveCardAction)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.tealDark)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(EKitapligimPalette.tealDark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.homeLiveCardAction)
            }
            .background(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EKitapligimPalette.border)
        }
        .shadow(color: EKitapligimPalette.liveOrange.opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal, 16)
    }

    // MARK: - Kitap istek merkezi

    private var requestCenterCard: some View {
        EKBookRequestHomePreviewCard(
            requests: bookRequestPreview,
            title: L10n.homeRequestCenterTitle,
            subtitle: L10n.homeRequestCenterSubtitle,
            emptyMessage: L10n.homeRequestCenterEmpty,
            actionTitle: L10n.homeRequestCenterAction
        ) {
            container.open(route: .requests)
        }
        .padding(.horizontal, 16)
        .accessibilityLabel(L10n.homeRequestCenterTitle)
    }

    // MARK: - Veri

    private func loadEditorialBooks() async {
        do {
            let loaded = try await container.homeEditorial.books()
            guard !Task.isCancelled else { return }
            editorialBooks = loaded
        } catch { /* Retain an existing valid selection during transient network failures. */ }
    }

    private func loadCategoryForums() async {
        guard let page = try? await container.community.forums(), !Task.isCancelled else { return }
        categoryForums = BookCategoryCatalog.merging(live: page.forums)
    }

    private func loadIfNeeded() async {
        guard stats == nil && popularBooks.isEmpty else { return }
        await load()
    }

    /// Refreshes library, agenda, live activity, and chat preview on every home visit.
    private func refreshDynamicContent(force: Bool = false) async {
        if isRefreshingDynamic { return }
        if !force, let lastDynamicRefresh, Date().timeIntervalSince(lastDynamicRefresh) < 2 {
            return
        }
        isRefreshingDynamic = true
        defer {
            isRefreshingDynamic = false
            lastDynamicRefresh = Date()
        }

        if container.isSignedIn {
            await container.refreshLibrary()
        }

        async let agendaRequest = container.bookAgenda.feed(tab: .agenda, filter: nil, page: 1, perPage: 4)
        async let liveRequest = container.liveActivity.activity(limit: 5)

        if let agenda = try? await agendaRequest {
            agendaPosts = agenda.items
        }
        if let live = try? await liveRequest {
            liveItems = live.items
        }

        await loadChatPreview(reset: true)
        await loadBookRequestPreview()
    }

    private func loadBookRequestPreview() async {
        guard let page = try? await container.bookRequests.requests() else {
            bookRequestPreview = []
            return
        }
        bookRequestPreview = page.items.filter { item in
            guard let userID = item.userId else { return true }
            return !container.blockedUserIDs.contains(userID)
        }.prefix(2).map { $0 }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let statsRequest = container.site.stats()
            async let popularRequest = container.books.books(
                page: 1, query: nil, category: nil, author: nil, publisher: nil, isbn: nil, order: "popular", premiumOnly: false
            )
            async let newestRequest = container.books.books(
                page: 1, query: nil, category: nil, author: nil, publisher: nil, isbn: nil, order: "latest", premiumOnly: false
            )
            let (loadedStats, popular, newest) = try await (
                statsRequest, popularRequest, newestRequest
            )

            stats = loadedStats
            popularBooks = uniqueBooks(popular.books.isEmpty
                ? newest.books.sorted { ($0.downloadCount ?? 0) > ($1.downloadCount ?? 0) }
                : popular.books)
            newestBooks = newest.books
            premiumBooks = newest.books.filter(\.isPremiumOnly).shuffled()
        } catch {
            errorMessage = L10n.homeStatsLoadFailed
        }
    }

    private func uniqueBooks(_ books: [BookDTO]) -> [BookDTO] {
        var seen = Set<String>()
        return books.filter { seen.insert($0.id).inserted }
    }

    private func loadChatPreview(reset: Bool = false) async {
        do {
            if reset || chatRoom == nil {
                let rooms = try await container.chat.rooms()
                chatRoom = rooms.rooms.first
                chatNewestID = nil
            }
            guard let roomID = chatRoom?.id else {
                chatPreview = []
                return
            }

            if reset || chatNewestID == nil {
                let page = try await container.chat.messages(roomID: roomID, limit: 6)
                chatPreview = page.messages
                chatNewestID = page.newestId ?? page.messages.last?.id
            } else if let afterID = chatNewestID {
                let page = try await container.chat.messages(roomID: roomID, limit: 20, afterID: afterID)
                guard !page.messages.isEmpty else { return }
                let existing = Set(chatPreview.map(\.id))
                chatPreview.append(contentsOf: page.messages.filter { !existing.contains($0.id) })
                if chatPreview.count > 8 {
                    chatPreview = Array(chatPreview.suffix(8))
                }
                chatNewestID = page.newestId ?? page.messages.last?.id ?? chatNewestID
            }
        } catch {
            if reset {
                chatRoom = nil
                chatPreview = []
                chatNewestID = nil
            }
        }
    }

    private func startChatPolling() {
        chatPollTask?.cancel()
        chatPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { return }
                await loadChatPreview(reset: false)
            }
        }
    }
}

// MARK: - Alt bileşenler

private struct HomeBookCard: View {
    @ScaledMetric(relativeTo: .body) private var cardWidth = 148.0
    let book: BookDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
                .aspectRatio(1 / 1.48, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(12)
                .background(EKitapligimPalette.tealSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            Label {
                UniformCardText(book.category, lines: 1)
            } icon: {
                Image(systemName: "book.closed").accessibilityHidden(true)
            }
            .font(.caption2.weight(.semibold)).foregroundStyle(EKitapligimPalette.teal)
            .opacity(book.category.isEmpty ? 0 : 1)
            .accessibilityHidden(book.category.isEmpty)
            UniformCardText(book.title, lines: 3).font(.subheadline.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.ink)
            UniformCardText(book.author, lines: 1).font(.caption).foregroundStyle(EKitapligimPalette.muted)
        }
        .padding(12)
        .containerRelativeFrame(.horizontal) { length, _ in
            min(cardWidth + 24, max(1, length - 32))
        }
        .ekitapligimCard(radius: 18)
    }
}

enum HomeAgendaCardLayout {
    case adaptive
    case rail
}

struct HomeAgendaCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let post: BookAgendaPostDTO
    var layout: HomeAgendaCardLayout = .adaptive
    let onOpen: () -> Void
    private var style: AgendaCardPalette { AgendaCardPalette(type: post.type) }

    static let railHeight: CGFloat = 360
    private var isRailLayout: Bool { layout == .rail }

    private var previewLineLimit: Int? { dynamicTypeSize.isAccessibilitySize ? nil : 5 }
    private var isQuotation: Bool { post.type == "quotation" }

    private var quotedMessage: String {
        plainText(post.quotedPost?.message ?? "")
    }

    private var preview: String {
        for candidate in [post.message, post.reviewTitle, quotedMessage] {
            let text = plainText(candidate)
            if !text.isEmpty { return text }
        }
        return L10n.homeAgendaEmptyPost
    }

    private var typeTitle: String {
        switch post.type {
        case "quotation": L10n.agendaTypeQuotation
        case "quote": L10n.agendaTypeQuote
        case "review": L10n.agendaTypeReview
        case "book": L10n.agendaTypeBook
        case "progress": L10n.agendaTypeProgress
        case "note": L10n.agendaTypeNote
        default: L10n.agendaTypeStandard
        }
    }

    private var typeIcon: String {
        switch post.type {
        case "quotation": "quote.opening"
        case "quote": "arrowshape.turn.up.left"
        case "review": "text.book.closed"
        case "book": "book.closed"
        case "progress": "bookmark"
        default: "text.alignleft"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Button(action: onOpen) {
                cardButtonContent
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(L10n.homeAgendaOpenPost)
            .accessibilityIdentifier("agenda.open.\(post.id)")
            .frame(maxHeight: isRailLayout ? .infinity : nil, alignment: .topLeading)
        }
        .foregroundStyle(style.ink)
        .multilineTextAlignment(.leading)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // The eager rail measures its tallest card, then stretches every card to that height.
        .frame(minHeight: isRailLayout ? Self.railHeight : nil, maxHeight: isRailLayout ? .infinity : nil, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: !isRailLayout)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    colors: [style.paper, .white],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(style.badge.opacity(0.5))
                        .frame(width: 150, height: 150)
                        .offset(x: 65, y: -80)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(style.border, lineWidth: 1)
                }
                .shadow(color: style.accent.opacity(0.07), radius: 6, y: 3)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var cardButtonContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(typeTitle, systemImage: typeIcon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(style.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(style.badge, in: Capsule())

            VStack(alignment: .leading, spacing: 10) {
                if isQuotation {
                    Image(systemName: "quote.opening")
                        .font(.system(.body, design: .serif, weight: .medium))
                        .foregroundStyle(style.accent.opacity(0.6))
                        .accessibilityHidden(true)
                }
                if post.type == "review", !plainText(post.reviewTitle).isEmpty,
                   plainText(post.reviewTitle) != preview {
                    Text(plainText(post.reviewTitle))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                }
                Text(preview)
                    .font(isQuotation ? .system(.callout, design: .serif, weight: .regular) : .subheadline)
                    .lineSpacing(3)
                    .lineLimit(previewLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                if isQuotation, post.pageNumber > 0 {
                    Text(L10n.agendaPageLabel(post.pageNumber))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(style.accent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: isRailLayout ? .infinity : nil, alignment: .topLeading)
            .clipped()

            if post.type == "quote", let quoted = post.quotedPost {
                quotedContext(quoted)
            }
            if let book = post.book, !plainText(book.title).isEmpty {
                bookContext(book)
            }

            if isRailLayout {
                Spacer(minLength: 0)
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: isRailLayout ? .infinity : nil, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private var header: some View {
        NavigationLink {
            MemberProfileView(memberID: post.actor.id)
        } label: {
        HStack(alignment: .top, spacing: 10) {
            EKAvatar(urlString: post.actor.avatarUrl, username: post.actor.username, size: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(post.actor.username)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if post.createdAt > 0 {
                    Text(EKitapligimFormat.relativeTime(post.createdAt))
                        .font(.caption2)
                        .foregroundStyle(style.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(Int(post.actor.id).map { $0 <= 0 } ?? true)
        .accessibilityIdentifier("agenda-author-\(post.id)")
    }

    @ViewBuilder
    private func quotedContext(_ quoted: BookAgendaQuotedPostDTO) -> some View {
        if !quoted.username.isEmpty || (!quotedMessage.isEmpty && quotedMessage != preview)
            || !plainText(quoted.bookTitle ?? "").isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !quoted.username.isEmpty {
                    Text(L10n.agendaQuotedFrom(quoted.username))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.accent)
                }
                if !quotedMessage.isEmpty, quotedMessage != preview {
                    Text(quotedMessage)
                        .font(.subheadline)
                        .lineSpacing(3)
                        .lineLimit(previewLineLimit)
                }
                if let title = quoted.bookTitle, !plainText(title).isEmpty {
                    Text(plainText(title))
                        .font(.caption)
                        .foregroundStyle(style.muted)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(style.badge.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func bookContext(_ book: BookAgendaBookDTO) -> some View {
        HStack(alignment: .top, spacing: 12) {
            EKitapligimRemoteCover(urlString: book.coverUrl ?? "", title: book.title, author: book.author)
                .frame(width: 42, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(plainText(book.title))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if !plainText(book.author).isEmpty {
                    Text(plainText(book.author))
                        .font(.caption)
                        .foregroundStyle(style.muted)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style.border.opacity(0.75), lineWidth: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Rectangle()
                .fill(style.border)
                .frame(height: 1)
                .accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    metrics
                    Spacer(minLength: 8)
                    openIndicator
                }
                VStack(alignment: .leading, spacing: 10) {
                    metrics
                    openIndicator
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var metrics: some View {
        Label(EKitapligimFormat.count(post.reactionScore), systemImage: "heart")
            .accessibilityLabel(L10n.homeAgendaReactionCount(post.reactionScore))
            .font(.caption)
            .foregroundStyle(style.muted)
            .fixedSize()
        Label(EKitapligimFormat.count(post.commentCount), systemImage: "bubble.left")
            .accessibilityLabel(L10n.homeAgendaCommentCount(post.commentCount))
            .font(.caption)
            .foregroundStyle(style.muted)
            .fixedSize()
    }

    private var openIndicator: some View {
        Image(systemName: "arrow.up.right")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(style.accent)
            .frame(width: 32, height: 32)
            .background(style.badge, in: Circle())
            .accessibilityHidden(true)
    }

    private func plainText(_ value: String) -> String {
        EKitapligimFormat.plainText(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum HomeAgendaStyle {
    static let paper = Color(hex: 0xF6F2FF)
    static let badge = Color(hex: 0xEBE3FA)
    static let border = Color(hex: 0xDDD3EE)
    static let ink = Color(hex: 0x252139)
    static let muted = Color(hex: 0x655D76)
    static let accent = Color(hex: 0x684399)
}
