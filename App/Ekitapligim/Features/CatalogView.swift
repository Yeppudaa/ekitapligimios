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

    var body: some View {
        NavigationStack {
            ZStack {
                EKitapligimPageBackground()
                ScrollView {
                    LazyVStack(spacing: 14) {
                        EKScrollOffsetTracker()
                        catalogHero
                        categoryChips
                        catalogControls
                        if isLoading || isRefreshing {
                            ProgressView()
                                .tint(EKitapligimPalette.teal)
                                .frame(maxWidth: .infinity)
                        }
                        catalogBookArea
                        loadMoreButton.buttonStyle(.bordered)
                    }
                    .padding(16)
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
        EKCollapsibleHero(progress: heroCollapseProgress) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.catalogHeroTitle)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                Text(L10n.catalogHeroSubtitle(books.count, lastPage))
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xE8F7F7), Color(hex: 0xFFFCF4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(EKitapligimPalette.border) }
        } collapsed: {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(EKitapligimPalette.teal)
                Text(L10n.catalogHeroTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(L10n.catalogHeroSubtitle(books.count, lastPage))
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(EKitapligimPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(EKitapligimPalette.border) }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CatalogCategoryChip(title: L10n.catalogFilterAllChip, isSelected: filters.categoryID.isEmpty) {
                    filters.categoryID = ""
                    Task { await load(reset: true) }
                }
                ForEach(categories) { forum in
                    CatalogCategoryChip(title: forum.title, isSelected: filters.categoryID == forum.id) {
                        filters.categoryID = forum.id
                        Task { await load(reset: true) }
                    }
                }
            }
        }
    }

    private var catalogControls: some View {
        HStack(spacing: 10) {
            CatalogMetric(title: L10n.catalogStatBooks, value: EKitapligimFormat.count(books.count))
                .frame(maxWidth: .infinity)
            CatalogMetric(title: L10n.catalogStatPages, value: "\(currentPage)/\(lastPage)")
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .ekitapligimCard(radius: 14)
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
                columns: [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 16)],
                spacing: 20
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
            Button {
                Task { await load(reset: false) }
            } label: {
                HStack {
                    Spacer()
                    if isLoadingMore { ProgressView() }
                    Text(isLoadingMore ? L10n.catalogLoadingMore : L10n.catalogLoadMore)
                    Spacer()
                }
            }
            .disabled(isLoadingMore)
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color(hex: 0x2A3443))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? EKitapligimPalette.teal : Color.white.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? EKitapligimPalette.teal : Color(hex: 0xD8E2E5))
                }
        }
        .buttonStyle(.plain)
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
                        ForEach(categories) { forum in Text(forum.title).tag(forum.id) }
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
}

private struct CatalogMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.weight(.heavy)).foregroundStyle(EKitapligimPalette.tealDark)
            Text(title).font(.caption2).foregroundStyle(EKitapligimPalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

@MainActor
private struct BookRow: View {
    let book: BookDTO

    var body: some View {
        HStack(spacing: 14) {
            CatalogBookCover(book: book)
                .frame(width: 76, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title).font(.headline).foregroundStyle(EKitapligimPalette.ink).lineLimit(2)
                Text(book.author).font(.subheadline).foregroundStyle(EKitapligimPalette.muted).lineLimit(1)
                if !book.category.isEmpty {
                    Text(book.category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EKitapligimPalette.tealDark)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(EKitapligimPalette.tealSoft)
                        .clipShape(Capsule())
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }
}

@MainActor
private struct BookGridItem: View {
    let book: BookDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CatalogBookCover(book: book)
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Text(book.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.ink)
                .lineLimit(2)
            Text(book.author)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.muted)
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 12)
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

            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.46), in: Circle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(7)
                .accessibilityLabel(L10n.libraryFavoriteBadge)
                .accessibilityHidden(!isFavorite)


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
