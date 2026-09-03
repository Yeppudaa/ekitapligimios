import SwiftUI
import EkitapligimCore

@MainActor
struct CatalogView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var books: [BookDTO] = []
    @State private var categories: [ForumDTO] = CatalogBookCategories.sortedFallbacks
    @State private var query = ""
    @State private var filters = CatalogFilters()
    @State private var currentPage = 1
    @State private var lastPage = 1
    @State private var totalBooks = 0
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var isLoadingMore = false
    @State private var showingFilters = false
    @State private var errorMessage: String?
    @State private var heroCollapseProgress: CGFloat = 0
    @AppStorage("catalog.displayMode") private var displayModeRawValue = CatalogDisplayMode.grid.rawValue

    private var displayMode: CatalogDisplayMode {
        CatalogDisplayMode(rawValue: displayModeRawValue) ?? .grid
    }

    private var selectedCategoryTitle: String {
        guard !filters.categoryID.isEmpty else { return L10n.catalogFilterAllCategories }
        return categories.first(where: { $0.id == filters.categoryID })?.title ?? L10n.catalogFilterAllCategories
    }

    private var formattedTotalBooks: String {
        totalBooks > 0 ? EKitapligimFormat.count(totalBooks) : "—"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EKitapligimPageBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        EKScrollOffsetTracker()
                        catalogHero
                        categoryChips
                        if isLoading || isRefreshing {
                            ProgressView()
                                .tint(EKitapligimPalette.teal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        catalogBookArea
                        loadMoreButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .ekCollapsibleScrollTracking { heroCollapseProgress = $0 }
            }
            .navigationTitle(L10n.catalogTitle)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: L10n.catalogSearchPrompt)
            .tint(EKitapligimPalette.teal)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        displayModeRawValue = displayMode.toggled.rawValue
                    } label: {
                        Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                    }
                    .accessibilityLabel(displayMode == .list ? L10n.catalogShowGrid : L10n.catalogShowList)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingFilters = true } label: {
                        Image(systemName: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(L10n.catalogFiltersTitle)
                }
            }
            .navigationDestination(for: String.self) { id in
                BookDetailDestination(bookIDString: id)
            }
            .task {
                await loadCategories()
                await load(reset: true)
            }
            .onSubmit(of: .search) { Task { await load(reset: true) } }
            .sheet(isPresented: $showingFilters) {
                CatalogFiltersView(filters: filters, categories: categories) { updated in
                    filters = updated
                    showingFilters = false
                    Task { await load(reset: true) }
                }
            }
        }
    }

    private var catalogHero: some View {
        EKCollapsibleHero(progress: heroCollapseProgress, expandedHeight: 298, collapsedHeight: 64) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.catalogEyebrow)
                            .font(.caption.weight(.heavy))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.72))
                        Text(L10n.catalogHeroTitle)
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.catalogHeroSubtitle(category: selectedCategoryTitle, page: currentPage, lastPage: lastPage))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    catalogCoverStack
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedTotalBooks)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .accessibilityLabel(L10n.catalogHeroBookCount(formattedTotalBooks))
                    Text(L10n.catalogHeroBooksCaption.uppercased(with: EKitapligimFormat.locale))
                        .font(.caption.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(EKitapligimPalette.profileGold)
                }

                HStack(spacing: 8) {
                    CatalogHeroMetric(title: L10n.catalogStatTotal, value: formattedTotalBooks)
                    CatalogHeroMetric(title: L10n.catalogStatLoaded, value: EKitapligimFormat.count(books.count))
                    CatalogHeroMetric(title: L10n.catalogStatCatalogPage, value: L10n.catalogPagePosition(currentPage, lastPage))
                }
            }
            .padding(20)
            .background(EKitapligimPalette.profileHeroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.12))
            }
            .shadow(color: Color(hex: 0x0B343B).opacity(0.28), radius: 22, y: 12)
        } collapsed: {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.catalogHeroTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(L10n.catalogHeroBookCount(formattedTotalBooks))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(L10n.catalogPagePosition(currentPage, lastPage))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.profileGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(EKitapligimPalette.profileBannerGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var catalogCoverStack: some View {
        ZStack {
            ForEach(Array(books.prefix(3).enumerated()), id: \.element.id) { index, book in
                EKitapligimRemoteCover(urlString: book.coverUrl)
                    .frame(width: index == 1 ? 58 : 50, height: index == 1 ? 88 : 76)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .rotationEffect(.degrees(Double(index - 1) * 9))
                    .offset(x: CGFloat(index - 1) * 16, y: index == 1 ? -6 : 8)
                    .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
            }
            if books.isEmpty {
                Image(systemName: "books.vertical.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 58, height: 88)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(width: 96, height: 102)
        .accessibilityHidden(true)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CatalogCategoryChip(
                    title: L10n.catalogFilterAllChip,
                    countLabel: filters.categoryID.isEmpty && totalBooks > 0 ? EKitapligimFormat.count(totalBooks) : nil,
                    isSelected: filters.categoryID.isEmpty
                ) {
                    filters.categoryID = ""
                    Task { await load(reset: true) }
                }
                ForEach(categories) { forum in
                    CatalogCategoryChip(
                        title: forum.title,
                        countLabel: forum.threadCount.flatMap { $0 > 0 ? EKitapligimFormat.count($0) : nil },
                        isSelected: filters.categoryID == forum.id
                    ) {
                        filters.categoryID = forum.id
                        Task { await load(reset: true) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var catalogBookArea: some View {
        if let message = errorMessage, books.isEmpty {
            ContentUnavailableView(
                L10n.catalogUnavailableTitle,
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
            .frame(minHeight: 220)
        } else if books.isEmpty && !isLoading && !isRefreshing {
            ContentUnavailableView(
                L10n.catalogEmptyTitle,
                systemImage: "magnifyingglass",
                description: Text(L10n.catalogEmptyDescription)
            )
            .frame(minHeight: 220)
        } else {
            catalogGridOrList
        }
    }

    @ViewBuilder
    private var catalogGridOrList: some View {
        switch displayMode {
        case .list:
            ForEach(books) { book in
                NavigationLink(value: book.id) { BookRow(book: book) }
                    .buttonStyle(.plain)
            }
        case .grid:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118, maximum: 180), spacing: 14)],
                spacing: 18
            ) {
                ForEach(books) { book in
                    NavigationLink(value: book.id) { BookGridItem(book: book) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        if currentPage < lastPage, !books.isEmpty {
            EKLoadMoreButton(
                isLoading: isLoadingMore,
                title: L10n.catalogLoadMore,
                loadingTitle: L10n.catalogLoadingMore
            ) {
                Task { await load(reset: false) }
            }
            .padding(.top, 4)
        }
    }

    private func load(reset: Bool) async {
        guard reset || !isLoadingMore else { return }
        if reset {
            if books.isEmpty {
                isLoading = true
            } else {
                isRefreshing = true
            }
        } else {
            isLoadingMore = true
        }
        errorMessage = nil
        defer {
            isLoading = false
            isRefreshing = false
            isLoadingMore = false
        }
        do {
            let page = reset ? 1 : currentPage + 1
            let result = try await container.books.books(
                page: page,
                query: query.nilIfBlank,
                category: filters.categoryID.nilIfBlank,
                author: filters.author.nilIfBlank,
                publisher: filters.publisher.nilIfBlank,
                isbn: filters.isbn.nilIfBlank,
                order: filters.order,
                premiumOnly: false
            )
            books = reset ? result.books : books + result.books.filter { item in !books.contains(where: { $0.id == item.id }) }
            currentPage = result.currentPage
            lastPage = result.lastPage
            totalBooks = result.totalBooks
        } catch {
            if reset, books.isEmpty {
                errorMessage = L10n.catalogLoadFailed
            }
        }
    }

    private func loadCategories() async {
        guard let result = try? await container.community.forums() else { return }
        categories = CatalogBookCategories.merged(live: result.forums)
    }
}

private enum CatalogBookCategories {
    static let fallback: [ForumDTO] = [
        ("6", "Roman"),
        ("7", "Edebiyat"),
        ("8", "Eğitim"),
        ("9", "Bilim"),
        ("10", "Tarih"),
        ("11", "Din"),
        ("12", "Psikoloji"),
        ("13", "Kişisel Gelişim"),
        ("14", "Ekonomi"),
        ("15", "Çocuk"),
        ("16", "Biyografi"),
        ("17", "Felsefe"),
        ("18", "Öykü / Hikaye"),
        ("19", "Siyaset"),
        ("20", "Romantik"),
        ("21", "Fantastik"),
        ("22", "Bilimkurgu"),
        ("23", "Macera"),
        ("24", "Polisiye"),
        ("25", "Korku / Gerilim"),
        ("26", "Gençlik"),
        ("27", "Sağlık"),
        ("28", "Türk Klasikleri"),
        ("29", "Dünya Klasikleri"),
        ("30", "Teknoloji / Bilişim"),
        ("32", "Yabancı Dil"),
        ("33", "Kültür / Sanat"),
        ("34", "Sinema / Tiyatro"),
        ("35", "Akademik"),
        ("36", "Aile ve Yaşam"),
        ("37", "Yemek / Mutfak"),
        ("38", "Masal")
    ].map { ForumDTO(id: $0.0, title: $0.1, isBookForum: true) }

    static var knownIDs: Set<String> {
        Set(fallback.map(\.id))
    }

    static var sortedFallbacks: [ForumDTO] {
        sorted(fallback)
    }

    static func sorted(_ forums: [ForumDTO]) -> [ForumDTO] {
        forums.sorted { lhs, rhs in
            lhs.title.compare(rhs.title, locale: EKitapligimFormat.locale) == .orderedAscending
        }
    }

    static func merged(live: [ForumDTO]) -> [ForumDTO] {
        var byID = Dictionary(uniqueKeysWithValues: fallback.map { ($0.id, $0) })
        for forum in live where knownIDs.contains(forum.id) {
            let title = forum.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.caseInsensitiveCompare("Genel") != .orderedSame else { continue }
            byID[forum.id] = ForumDTO(
                id: forum.id,
                title: title,
                description: forum.description,
                url: forum.url,
                stats: forum.stats,
                threadCount: forum.threadCount,
                isBookForum: true
            )
        }
        return sorted(Array(byID.values))
    }
}

private struct CatalogCategoryChip: View {
    let title: String
    var countLabel: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let countLabel {
                    Text(countLabel)
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isSelected ? Color.white.opacity(0.2) : EKitapligimPalette.tealSoft, in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? Color.white : EKitapligimPalette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? EKitapligimPalette.teal : Color.white, in: Capsule())
            .overlay {
                Capsule().stroke(isSelected ? EKitapligimPalette.teal : EKitapligimPalette.border)
            }
            .shadow(color: isSelected ? EKitapligimPalette.teal.opacity(0.22) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(countLabel.map { L10n.catalogCategoryChip(title, countLabel: $0) } ?? title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct CatalogFilters: Equatable {
    var categoryID = ""
    var author = ""
    var publisher = ""
    var isbn = ""
    var order = "latest"

    var isActive: Bool {
        !categoryID.isEmpty || !author.isEmpty || !publisher.isEmpty || !isbn.isEmpty || order != "latest"
    }
}

@MainActor
private struct CatalogFiltersView: View {
    @State private var filters: CatalogFilters
    let categories: [ForumDTO]
    let apply: (CatalogFilters) -> Void

    init(filters: CatalogFilters, categories: [ForumDTO], apply: @escaping (CatalogFilters) -> Void) {
        _filters = State(initialValue: filters)
        self.categories = categories
        self.apply = apply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.catalogFilterDetails) {
                    TextField(L10n.catalogFilterAuthor, text: $filters.author)
                    TextField(L10n.catalogFilterPublisher, text: $filters.publisher)
                    TextField(L10n.catalogFilterISBN, text: $filters.isbn)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.never)
                }
                Section(L10n.catalogFilterCategory) {
                    Picker(L10n.catalogFilterCategory, selection: $filters.categoryID) {
                        Text(L10n.catalogFilterAllCategories).tag("")
                        ForEach(categories) { forum in
                            Text(categoryPickerTitle(for: forum)).tag(forum.id)
                        }
                    }
                }
                Section(L10n.catalogFilterOrder) {
                    Picker(L10n.catalogFilterOrder, selection: $filters.order) {
                        Text(L10n.catalogOrderLatest).tag("latest")
                        Text(L10n.catalogOrderPopular).tag("popular")
                        Text(L10n.catalogOrderRated).tag("rated")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L10n.catalogFiltersTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.catalogFilterReset) { filters = CatalogFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.catalogFilterApply) { apply(filters) }
                }
            }
        }
    }

    private func categoryPickerTitle(for forum: ForumDTO) -> String {
        if let count = forum.threadCount, count > 0 {
            return L10n.catalogCategoryChip(forum.title, countLabel: EKitapligimFormat.count(count))
        }
        return forum.title
    }
}

private struct CatalogHeroMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.08))
        }
    }
}

@MainActor
private struct BookRow: View {
    let book: BookDTO

    var body: some View {
        HStack(spacing: 14) {
            CatalogBookCover(book: book)
                .frame(width: 78, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: EKitapligimPalette.ink.opacity(0.16), radius: 10, y: 5)
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(2)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !book.category.isEmpty {
                        Text(book.category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EKitapligimPalette.tealDark)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(EKitapligimPalette.tealSoft)
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }
                    if book.pageCount > 1 {
                        Text(L10n.catalogBookPageCount(book.pageCount))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EKitapligimPalette.muted)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    if let rating = book.rating, rating > 0 {
                        Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .foregroundStyle(EKitapligimPalette.amber)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(EKitapligimPalette.teal)
                }.font(.caption.weight(.bold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EKitapligimPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EKitapligimPalette.border)
        }
    }
}

@MainActor
private struct BookGridItem: View {
    let book: BookDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CatalogBookCover(book: book)
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
            Text(book.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.ink)
                .lineLimit(2)
                .frame(minHeight: 32, alignment: .topLeading)
            Text(book.author)
                .font(.caption2)
                .foregroundStyle(EKitapligimPalette.muted)
                .lineLimit(1)
            HStack(spacing: 6) {
                if book.pageCount > 1 {
                    Text(L10n.catalogBookPageCount(book.pageCount))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(EKitapligimPalette.tealDark)
                }
                if let rating = book.rating, rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                        Text(rating.formatted(.number.precision(.fractionLength(1))))
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(EKitapligimPalette.amber)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct CatalogBookCover: View {
    @EnvironmentObject private var container: AppContainer
    let book: BookDTO

    private var isFavorite: Bool {
        container.libraryItems.first(where: { $0.bookId == book.id })?.isFavoriteItem ?? false
    }

    private var isDownloaded: Bool {
        if container.libraryItems.first(where: { $0.bookId == book.id })?.isDownloaded == true {
            return true
        }
        if case .downloaded = container.downloadManager.states[book.id] {
            return true
        }
        return container.downloadManager.localFile(for: book.id) != nil
    }

    var body: some View {
        ZStack {
            BookCover(book: book)

            if isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.46), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(7)
                    .accessibilityLabel(L10n.libraryFavoriteBadge)
            }


            if book.isPremiumOnly {
                HStack(spacing: 3) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("PREMIUM")
                        .font(.system(size: 9, weight: .heavy))
                }
                .foregroundStyle(EKitapligimPalette.teal)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.94), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(8)
                .accessibilityLabel(L10n.premiumShortTitle)
            }

            if isDownloaded {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(EKitapligimPalette.teal, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(6)
                    .accessibilityLabel(L10n.libraryDownloadedBadge)
            }
        }
    }
}

@MainActor
private struct BookCover: View {
    let book: BookDTO

    var body: some View {
        Group {
            if let secureCoverURL {
                AsyncImage(url: secureCoverURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ZStack {
                            Rectangle().fill(.quaternary)
                            ProgressView()
                        }
                    default:
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
        }
        .clipped()
        .background(EKitapligimPalette.tealSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }

    private var secureCoverURL: URL? {
        guard let url = URL(string: book.coverUrl), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private var coverPlaceholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "book.closed")
                .foregroundStyle(.secondary)
        }
    }
}

private enum CatalogDisplayMode: String {
    case list
    case grid

    var toggled: CatalogDisplayMode { self == .list ? .grid : .list }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
