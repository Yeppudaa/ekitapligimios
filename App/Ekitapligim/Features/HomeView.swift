import SwiftUI
import EkitapligimCore

@MainActor
struct HomeView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var stats: SiteStatsDTO?
    @State private var popularBooks: [BookDTO] = []
    @State private var newestBooks: [BookDTO] = []
    @State private var dailyPickBooks: [BookDTO] = []
    @State private var premiumBooks: [BookDTO] = []
    @State private var agendaPosts: [BookAgendaPostDTO] = []
    @State private var liveItems: [LiveActivityItemDTO] = []
    @State private var chatRoom: ChatRoomDTO?
    @State private var chatPreview: [ChatMessageDTO] = []
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
                        statsCard
                        continueReadingCard
                        discoverySection
                        chatPreviewCard
                        agendaRail
                        bookRail(
                            title: L10n.homeDailyPickTitle,
                            subtitle: L10n.homeDailyPickSubtitle,
                            books: dailyPickBooks
                        )
                        bookRail(
                            title: L10n.homeNewestTitle,
                            subtitle: L10n.homeNewestSubtitle,
                            books: newestBooks
                        )
                        bookRail(
                            title: L10n.homePopularTitle,
                            subtitle: L10n.homePopularSubtitle,
                            books: popularBooks
                        )
                        liveActivityCard
                        if !premiumBooks.isEmpty {
                            bookRail(
                                title: L10n.homePremiumRailTitle,
                                subtitle: L10n.homePremiumRailSubtitle,
                                books: premiumBooks
                            )
                        }
                        requestCenterCard
                    }
                    .padding(.bottom, 28)
                }
                .refreshable { await load() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                BookDetailView(bookID: Int(id) ?? 0)
            }
            .task {
                await loadIfNeeded()
                startChatPolling()
            }
            .onDisappear { chatPollTask?.cancel() }
        }
    }

    @State private var chatPollTask: Task<Void, Never>?

    // MARK: - Üst bölüm

    private var headerBlock: some View {
        HStack(spacing: 12) {
            EKitapligimBrandLogo()
                .frame(maxWidth: 140, minHeight: 52, maxHeight: 56)
            Spacer(minLength: 4)
            Button { container.open(route: .premium) } label: {
                Label(container.isPremium ? L10n.premiumShortTitle : L10n.premiumShortTitle, systemImage: "crown.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(EKitapligimPalette.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.trailing, 58)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EKPill(
                title: L10n.homeHeroBadge,
                foreground: EKitapligimPalette.tealDark,
                background: EKitapligimPalette.tealSoft
            )

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.homeHeroHeadline)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(EKitapligimPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.homeHeroSubtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button { container.selectedTab = .catalog } label: {
                            Label(L10n.homeHeroPrimaryAction, systemImage: "books.vertical.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(EKitapligimPalette.teal)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button { container.open(route: .premium) } label: {
                            Label(L10n.premiumShortTitle, systemImage: "crown.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.tealDark)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay { RoundedRectangle(cornerRadius: 12).stroke(EKitapligimPalette.teal.opacity(0.4)) }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }

                heroCoverStack
            }

            HStack(spacing: 0) {
                signalPill(L10n.homeSignalFormats, systemImage: "doc.fill")
                signalDivider
                signalPill(L10n.homeSignalShelfSync, systemImage: "arrow.triangle.2.circlepath")
                signalDivider
                signalPill(L10n.homeSignalEverywhere, systemImage: "iphone")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 252 / 255, green: 254 / 255, blue: 253 / 255),
                         Color(red: 244 / 255, green: 250 / 255, blue: 248 / 255),
                         Color(red: 255 / 255, green: 251 / 255, blue: 242 / 255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color(red: 214 / 255, green: 231 / 255, blue: 228 / 255)) }
        .padding(.horizontal, 16)
    }

    private var heroCoverStack: some View {
        ZStack {
            ForEach(Array(newestBooks.prefix(3).enumerated()), id: \.offset) { index, book in
                EKitapligimRemoteCover(urlString: book.coverUrl)
                    .frame(width: index == 1 ? 56 : 48, height: index == 1 ? 88 : 76)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .rotationEffect(.degrees(Double(index - 1) * 8))
                    .offset(x: CGFloat(index - 1) * 18, y: index == 1 ? -4 : 6)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
            if newestBooks.isEmpty {
                Image(systemName: "books.vertical.fill")
                    .font(.title)
                    .foregroundStyle(EKitapligimPalette.teal)
                    .frame(width: 56, height: 88)
            }
        }
        .frame(width: 90, height: 96)
    }

    private func signalPill(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 10)).foregroundStyle(EKitapligimPalette.teal)
            Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(EKitapligimPalette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var signalDivider: some View {
        Rectangle().fill(Color(red: 230 / 255, green: 215 / 255, blue: 189 / 255)).frame(width: 1, height: 20)
    }

    private var searchBar: some View {
        Button { container.selectedTab = .catalog } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.teal)
                Text(L10n.homeSearchPlaceholder)
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(EKitapligimPalette.teal)
            }
            .padding(.horizontal, 17)
            .frame(height: 58)
            .ekitapligimCard(radius: 17)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.homeSearchPlaceholder)
        .padding(.horizontal, 16)
    }

    // MARK: - İstatistikler

    @ViewBuilder private var statsCard: some View {
        HStack(spacing: 0) {
            if let stats {
                HomeStat(value: stats.totalBooks, label: L10n.homeStatBooks, systemImage: "books.vertical.fill", tint: EKitapligimPalette.amber)
                divider
                HomeStat(value: stats.totalAuthors, label: L10n.homeStatAuthors, systemImage: "person.2.fill", tint: EKitapligimPalette.teal)
                divider
                HomeStat(value: stats.totalPublishers, label: L10n.homeStatPublishers, systemImage: "building.2.fill", tint: EKitapligimPalette.teal)
            } else if isLoading {
                ProgressView(L10n.homeStatsLoading)
                    .tint(EKitapligimPalette.teal)
                    .frame(maxWidth: .infinity, minHeight: 82)
            } else {
                Button { Task { await load() } } label: {
                    Label(errorMessage ?? L10n.homeStatsLoadFailed, systemImage: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .frame(maxWidth: .infinity, minHeight: 82)
                }
            }
        }
        .padding(.vertical, 10)
        .ekitapligimCard(radius: 12)
        .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle().fill(EKitapligimPalette.border).frame(width: 1, height: 46)
    }

    // MARK: - Devam et

    @ViewBuilder private var continueReadingCard: some View {
        if let item = container.continueReadingItem {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.homeContinueTitle)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.profileInk)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(EKitapligimPalette.teal)
                }
                .padding(.horizontal, 16)

                NavigationLink(value: item.bookId) {
                    HStack(spacing: 14) {
                        EKitapligimRemoteCover(urlString: item.coverUrl)
                            .frame(width: 72, height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.ink)
                                .lineLimit(2)
                            if !item.author.isEmpty {
                                Text(item.author).font(.caption).foregroundStyle(EKitapligimPalette.muted)
                            }
                            ProgressView(value: Double(item.progressPercent), total: 100)
                                .tint(EKitapligimPalette.amber)
                            HStack {
                                Text(L10n.commonPercent(item.progressPercent))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(EKitapligimPalette.muted)
                                Spacer()
                                Label(L10n.homeContinueAction, systemImage: "play.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(EKitapligimPalette.teal)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(14)
                    .ekitapligimCard(radius: 14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Keşif Merkezi

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EKitapligimSectionHeader(
                title: L10n.homeDiscoveryTitle,
                subtitle: L10n.homeDiscoverySubtitle,
                actionTitle: L10n.homeSeeAll
            ) { container.selectedTab = .catalog }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    discoveryCard(
                        badge: L10n.homeDiscoveryCatalogBadge,
                        title: L10n.tabCatalogShort,
                        subtitle: L10n.homeDiscoveryCatalogSubtitle,
                        tint: EKitapligimPalette.teal
                    ) { container.selectedTab = .catalog }

                    discoveryCard(
                        badge: L10n.homeDiscoveryAgendaBadge,
                        title: L10n.menuBookAgenda,
                        subtitle: L10n.homeDiscoveryAgendaSubtitle,
                        tint: EKitapligimPalette.agendaPurple
                    ) { container.open(route: .bookAgenda) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryChatBadge,
                        title: L10n.menuChat,
                        subtitle: L10n.homeDiscoveryChatSubtitle,
                        tint: EKitapligimPalette.chatTeal
                    ) { container.open(route: .chat) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryLiveBadge,
                        title: L10n.homeDiscoveryLiveTitle,
                        subtitle: L10n.homeDiscoveryLiveSubtitle,
                        tint: EKitapligimPalette.liveOrange
                    ) { container.open(route: .liveActivity) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryRequestsBadge,
                        title: L10n.menuRequests,
                        subtitle: L10n.homeDiscoveryRequestsSubtitle,
                        tint: Color(hex: 0xD45F7A)
                    ) { container.open(route: .requests) }

                    discoveryCard(
                        badge: L10n.homeDiscoveryForumBadge,
                        title: L10n.tabForum,
                        subtitle: L10n.homeDiscoveryForumSubtitle,
                        tint: Color(hex: 0x3D75C5)
                    ) { container.selectedTab = .forum }

                    discoveryCard(
                        badge: L10n.homeDiscoveryProfileBadge,
                        title: L10n.tabProfile,
                        subtitle: L10n.homeDiscoveryProfileSubtitle,
                        tint: Color(hex: 0x8A6B3E)
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(badge)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(width: 170, height: 112, alignment: .topLeading)
            .background(
                LinearGradient(colors: [.white, tint.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(EKitapligimPalette.border) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sohbet önizlemesi

    @ViewBuilder private var chatPreviewCard: some View {
        Button { container.open(route: .chat) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chatRoom?.name ?? L10n.menuChat)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(EKitapligimPalette.ink)
                        Text(chatRoom?.description ?? L10n.homeChatCardSubtitle)
                            .font(.caption)
                            .foregroundStyle(EKitapligimPalette.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    EKPill(title: L10n.chatLiveBadge, foreground: EKitapligimPalette.liveBadgeInk, background: EKitapligimPalette.liveBadgeBackground)
                }

                if chatPreview.isEmpty {
                    Text(L10n.homeChatCardEmpty)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                } else {
                    ForEach(chatPreview.prefix(2)) { message in
                        Text(message.message)
                            .font(.caption)
                            .foregroundStyle(EKitapligimPalette.ink)
                            .lineLimit(1)
                    }
                }

                HStack {
                    if let room = chatRoom, room.userCount > 0 {
                        Text(L10n.chatOnlineCount(room.userCount))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.tealDark)
                    }
                    Spacer()
                    Text(L10n.homeChatCardAction)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.tealDark)
                }
            }
            .padding(16)
            .ekitapligimCard()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Kitap Gündemi rayı

    private var agendaRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            EKitapligimSectionHeader(
                title: L10n.menuBookAgenda,
                subtitle: L10n.homeAgendaRailSubtitle,
                actionTitle: L10n.homeSeeAll
            ) { container.open(route: .bookAgenda) }
            .padding(.horizontal, 16)

            if agendaPosts.isEmpty {
                Text(L10n.homeAgendaRailEmpty)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(agendaPosts.prefix(4)) { post in
                            Button { container.open(route: .bookAgendaPost(Int(post.id) ?? 0)) } label: {
                                HomeAgendaCard(post: post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Kitap rayları

    private func bookRail(title: String, subtitle: String, books: [BookDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EKitapligimSectionHeader(title: title, subtitle: subtitle, actionTitle: L10n.homeSeeAll) {
                container.selectedTab = .catalog
            }
            .padding(.horizontal, 16)

            if isLoading && books.isEmpty {
                ProgressView().tint(EKitapligimPalette.teal).frame(maxWidth: .infinity, minHeight: 180)
            } else if !books.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(books.prefix(8)) { book in
                            NavigationLink(value: book.id) { HomeBookCard(book: book) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Canlı aktivite

    private var liveActivityCard: some View {
        Button { container.open(route: .liveActivity) } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.homeLiveCardEyebrow)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(EKitapligimPalette.agendaPurple)
                Text(L10n.liveActivityTitle)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                Text(L10n.homeLiveCardSubtitle)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)

                if liveItems.isEmpty {
                    Text(L10n.homeLiveCardEmpty)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                } else {
                    ForEach(liveItems.prefix(3)) { item in
                        LiveActivityRow(item: item)
                    }
                }

                HStack {
                    Spacer()
                    Text(L10n.homeLiveCardAction)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.tealDark)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.tealDark)
                }
            }
            .padding(16)
            .ekitapligimCard()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Kitap istek merkezi

    private var requestCenterCard: some View {
        Button { container.open(route: .requests) } label: {
            HStack(spacing: 14) {
                Image(systemName: "heart.text.square.fill")
                    .accessibilityHidden(true)
                    .font(.title2)
                    .foregroundStyle(EKitapligimPalette.gold)
                    .frame(width: 48, height: 48)
                    .background(EKitapligimPalette.amberSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.homeRequestCenterTitle)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.ink)
                    Text(L10n.homeRequestCenterSubtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .lineLimit(2)
                }
                Spacer()
                Text(L10n.homeRequestCenterAction)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(EKitapligimPalette.profileGoldDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(16)
            .ekitapligimCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.homeRequestCenterTitle)
        .padding(.horizontal, 16)
    }

    // MARK: - Veri

    private func loadIfNeeded() async {
        guard stats == nil && popularBooks.isEmpty else { return }
        await load()
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
            async let dailyRequest = container.books.books(
                page: dailyPickPage(), query: nil, category: "6", author: nil, publisher: nil, isbn: nil, order: "post_date", premiumOnly: false
            )
            async let agendaRequest = container.bookAgenda.feed(tab: .agenda, filter: nil, page: 1, perPage: 4)
            async let liveRequest = container.liveActivity.activity(limit: 5)

            let (loadedStats, popular, newest, daily, agenda, live) = try await (
                statsRequest, popularRequest, newestRequest, dailyRequest, agendaRequest, liveRequest
            )

            stats = loadedStats
            popularBooks = shuffledPopular(popular.books + newest.books)
            newestBooks = newest.books
            dailyPickBooks = dailySeededShuffle(daily.books)
            premiumBooks = newest.books.filter(\.isPremiumOnly).shuffled()
            agendaPosts = agenda.items
            liveItems = live.items

            if container.isSignedIn {
                await container.refreshLibrary()
            }
        } catch {
            errorMessage = L10n.homeStatsLoadFailed
        }

        await loadChatPreview()
    }

    private func dailyPickPage() -> Int {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return (day % 5) + 1
    }

    private func dailySeededShuffle(_ books: [BookDTO]) -> [BookDTO] {
        let seed = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        books.enumerated().sorted { ($0.offset ^ seed) % books.count < ($1.offset ^ seed) % books.count }.map(\.element)
    }

    private func shuffledPopular(_ books: [BookDTO]) -> [BookDTO] {
        Array(Set(books.map(\.id))).compactMap { id in books.first { $0.id == id } }.shuffled()
    }

    private func loadChatPreview() async {
        do {
            let rooms = try await container.chat.rooms()
            chatRoom = rooms.rooms.first
            if let roomID = chatRoom?.id {
                let page = try await container.chat.messages(roomID: roomID, limit: 6)
                chatPreview = page.messages
            }
        } catch {
            chatRoom = nil
            chatPreview = []
        }
    }

    private func startChatPolling() {
        chatPollTask?.cancel()
        chatPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { return }
                await loadChatPreview()
            }
        }
    }
}

// MARK: - Alt bileşenler

private struct HomeStat: View {
    let value: Int
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(EKitapligimFormat.compactCount(value))
                .font(.headline.monospacedDigit())
                .foregroundStyle(EKitapligimPalette.ink)
            Text(label).font(.caption2).foregroundStyle(EKitapligimPalette.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.homeStatAccessibility(label, value))
    }
}

private struct HomeBookCard: View {
    let book: BookDTO

    var body: some View {
        HStack(spacing: 0) {
            EKitapligimRemoteCover(urlString: book.coverUrl)
                .frame(width: 88, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 14,
                        bottomLeadingRadius: 14,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(2)
                Text(book.author)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let rating = book.rating, rating > 0 {
                    Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(EKitapligimPalette.amber)
                }
            }
            .padding(10)
            .frame(width: 150, height: 112, alignment: .topLeading)
        }
        .frame(width: 238, height: 112)
        .ekitapligimCard(radius: 14)
    }
}

private struct HomeAgendaCard: View {
    let post: BookAgendaPostDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                EKAvatar(urlString: post.actor.avatarUrl, username: post.actor.username, size: 28)
                Text(post.actor.username)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(1)
            }
            Text(EKitapligimFormat.plainText(post.message))
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.muted)
                .lineLimit(3)
            HStack(spacing: 12) {
                Label("\(post.reactionScore)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.left")
            }
            .font(.caption2)
            .foregroundStyle(EKitapligimPalette.muted)
        }
        .padding(14)
        .frame(width: 260, alignment: .topLeading)
        .frame(minHeight: 130, alignment: .topLeading)
        .ekitapligimCard(radius: 16)
    }
}
