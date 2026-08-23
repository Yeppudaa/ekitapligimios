import SwiftUI
import EkitapligimCore

@MainActor
struct HomeView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var stats: SiteStatsDTO?
    @State private var popularBooks: [BookDTO] = []
    @State private var newestBooks: [BookDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EKitapligimPageBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        homeHeader
                        statsCard
                        quickAccess
                        bookRail(title: L10n.homePopularBooks, subtitle: L10n.homePopularBooksSubtitle, books: popularBooks)
                        bookRail(title: L10n.homeNewestBooks, subtitle: L10n.homeNewestBooksSubtitle, books: newestBooks)
                        communityCard
                    }
                    .padding(.bottom, 26)
                }
                .refreshable { await load() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in
                BookDetailView(bookID: Int(id) ?? 0)
            }
            .task { await loadIfNeeded() }
        }
    }

    private var homeHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                EKitapligimBrandLogo()
                    .frame(maxWidth: 140, minHeight: 52, maxHeight: 56)
                Spacer(minLength: 4)
                NavigationLink {
                    PremiumView()
                } label: {
                    Label(L10n.premiumShortTitle, systemImage: "crown.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(EKitapligimPalette.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }
            .padding(.trailing, 58)
            Button {
                container.selectedTab = .catalog
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .accessibilityLabel(L10n.homeSearchPrompt)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(EKitapligimPalette.teal)
                    Text(L10n.homeSearchPrompt)
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
            .accessibilityLabel(L10n.homeSearchPrompt)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(
            LinearGradient(
                colors: [Color(red: 249 / 255, green: 252 / 255, blue: 252 / 255), EKitapligimPalette.cream.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder private var statsCard: some View {
        HStack(spacing: 0) {
            if let stats {
                HomeStat(value: stats.totalBooks, label: L10n.homeBooks, systemImage: "books.vertical.fill", tint: EKitapligimPalette.amber)
                divider
                HomeStat(value: stats.totalAuthors, label: L10n.homeAuthors, systemImage: "person.2.fill", tint: EKitapligimPalette.teal)
                divider
                HomeStat(value: stats.totalPublishers, label: L10n.homePublishers, systemImage: "building.2.fill", tint: EKitapligimPalette.teal)
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

    private var quickAccess: some View {
        VStack(alignment: .leading, spacing: 12) {
            EKitapligimSectionHeader(title: L10n.homeExploreSection)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                HomeShortcut(title: L10n.homeOpenCatalog, icon: "books.vertical.fill", tint: EKitapligimPalette.teal) {
                    container.selectedTab = .catalog
                }
                HomeShortcut(title: L10n.homeContinueReading, icon: "bookmark.fill", tint: EKitapligimPalette.amber) {
                    container.selectedTab = .library
                }
                NavigationLink { DirectoryView(kind: .author) } label: {
                    HomeShortcutLabel(title: L10n.directoryAuthorsTitle, icon: "person.2.fill", tint: EKitapligimPalette.teal)
                }.buttonStyle(.plain)
                NavigationLink { BookRequestsView() } label: {
                    HomeShortcutLabel(title: L10n.bookRequestsTitle, icon: "heart.text.square.fill", tint: EKitapligimPalette.amber)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func bookRail(title: String, subtitle: String, books: [BookDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EKitapligimSectionHeader(title: title, subtitle: subtitle, actionTitle: L10n.homeSeeAll) {
                container.selectedTab = .catalog
            }
            .padding(.horizontal, 16)
            if isLoading && books.isEmpty {
                ProgressView().tint(EKitapligimPalette.teal).frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(books.prefix(6)) { book in
                            NavigationLink(value: book.id) { HomeBookCard(book: book) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var communityCard: some View {
        Button { container.selectedTab = .community } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.3.fill")
                    .accessibilityLabel(L10n.communityTitle)
                    .font(.title2)
                    .foregroundStyle(EKitapligimPalette.teal)
                    .frame(width: 48, height: 48)
                    .background(EKitapligimPalette.tealSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.communityTitle).font(.headline).foregroundStyle(EKitapligimPalette.ink)
                    Text(L10n.homeCommunitySubtitle).font(.caption).foregroundStyle(EKitapligimPalette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(EKitapligimPalette.teal)
            }
            .padding(16)
            .ekitapligimCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.communityTitle)
        .padding(.horizontal, 16)
    }

    private func loadIfNeeded() async {
        guard stats == nil && popularBooks.isEmpty && newestBooks.isEmpty else { return }
        await load()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let statsRequest = container.site.stats()
            async let popularRequest = container.books.books(page: 1, query: nil, category: nil, author: nil, publisher: nil, isbn: nil, order: "popular", premiumOnly: false)
            async let newestRequest = container.books.books(page: 1, query: nil, category: nil, author: nil, publisher: nil, isbn: nil, order: "latest", premiumOnly: false)
            let (loadedStats, popular, newest) = try await (statsRequest, popularRequest, newestRequest)
            stats = loadedStats
            popularBooks = popular.books
            newestBooks = newest.books
        } catch {
            errorMessage = L10n.homeStatsLoadFailed
        }
    }
}

private struct HomeStat: View {
    let value: Int
    let label: String
    let systemImage: String
    let tint: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(value, format: .number.notation(.compactName)).font(.headline.monospacedDigit()).foregroundStyle(EKitapligimPalette.ink)
            Text(label).font(.caption2).foregroundStyle(EKitapligimPalette.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.homeStatAccessibility(label, value))
    }
}

private struct HomeShortcut: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) { HomeShortcutLabel(title: title, icon: icon, tint: tint) }.buttonStyle(.plain)
    }
}

private struct HomeShortcutLabel: View {
    let title: String
    let icon: String
    let tint: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title).font(.caption.weight(.bold)).foregroundStyle(EKitapligimPalette.ink).lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 62)
        .ekitapligimCard(radius: 16)
    }
}

private struct HomeBookCard: View {
    let book: BookDTO
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                EKitapligimRemoteCover(urlString: book.coverUrl)
                    .frame(width: 118, height: 172)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                if book.isPremiumOnly {
                    Image(systemName: "crown.fill").font(.caption).foregroundStyle(.white).padding(7)
                        .background(EKitapligimPalette.teal).clipShape(Circle()).padding(7)
                }
            }
            Text(book.title).font(.caption.weight(.bold)).foregroundStyle(EKitapligimPalette.ink).lineLimit(2)
            Text(book.author).font(.caption2).foregroundStyle(EKitapligimPalette.muted).lineLimit(1)
            if let rating = book.rating, rating > 0 {
                Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                    .font(.caption2.weight(.semibold)).foregroundStyle(EKitapligimPalette.amber)
            }
        }
        .padding(9)
        .frame(width: 138, height: 252, alignment: .topLeading)
        .ekitapligimCard(radius: 14)
    }
}
