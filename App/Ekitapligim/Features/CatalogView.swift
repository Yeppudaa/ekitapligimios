import SwiftUI
import EkitapligimCore

@MainActor
struct CatalogView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var books: [BookDTO] = []
    @State private var categories: [ForumDTO] = []
    @State private var query = ""
    @State private var filters = CatalogFilters()
    @State private var currentPage = 1
    @State private var lastPage = 1
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var showingFilters = false
    @State private var errorMessage: String?
    @State private var heroCollapseProgress: CGFloat = 0
    @AppStorage("catalog.displayMode") private var displayModeRawValue = CatalogDisplayMode.list.rawValue

    private var displayMode: CatalogDisplayMode {
        CatalogDisplayMode(rawValue: displayModeRawValue) ?? .list
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EKitapligimPageBackground()
                Group {
                    if isLoading {
                        ProgressView(L10n.catalogLoading).tint(EKitapligimPalette.teal)
                    } else if let message = errorMessage {
                        ContentUnavailableView(L10n.catalogUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(message))
                    } else if books.isEmpty {
                        ContentUnavailableView(L10n.catalogEmptyTitle, systemImage: "magnifyingglass", description: Text(L10n.catalogEmptyDescription))
                    } else {
                        catalogContent
                    }
                }
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

    @ViewBuilder
    private var catalogContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                EKScrollOffsetTracker()
                catalogHero
                categoryChips
                catalogControls
                catalogGridOrList
                loadMoreButton.buttonStyle(.bordered)
            }
            .padding(16)
        }
        .ekCollapsibleScrollTracking { heroCollapseProgress = $0 }
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
            HStack(spacing: 8) {
                EKChip(title: L10n.catalogFilterAllCategories, isSelected: filters.categoryID.isEmpty) {
                    filters.categoryID = ""
                    Task { await load(reset: true) }
                }
                ForEach(categories) { forum in
                    EKChip(title: forum.title, isSelected: filters.categoryID == forum.id) {
                        filters.categoryID = forum.id
                        Task { await load(reset: true) }
                    }
                }
            }
        }
    }

    private var catalogControls: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $filters.premiumOnly) {
                Text(L10n.catalogFilterPremium)
                    .font(.caption.weight(.bold))
            }
            .toggleStyle(.switch)
            .tint(EKitapligimPalette.teal)
            .onChange(of: filters.premiumOnly) { _, _ in Task { await load(reset: true) } }
            Spacer(minLength: 0)
            CatalogMetric(title: L10n.catalogStatBooks, value: EKitapligimFormat.count(books.count))
            CatalogMetric(title: L10n.catalogStatPages, value: "\(lastPage)")
        }
        .padding(14)
        .ekitapligimCard(radius: 14)
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
        if currentPage < lastPage {
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
        if reset { isLoading = true } else { isLoadingMore = true }
        errorMessage = nil
        defer {
            isLoading = false
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
                premiumOnly: filters.premiumOnly
            )
            books = reset ? result.books : books + result.books.filter { item in !books.contains(where: { $0.id == item.id }) }
            currentPage = result.currentPage
            lastPage = result.lastPage
        } catch {
            if reset { errorMessage = L10n.catalogLoadFailed }
        }
    }

    private func loadCategories() async {
        guard categories.isEmpty else { return }
        if let result = try? await container.community.forums() {
            categories = result.forums.filter { $0.isBookForum == true }
        }
    }
}

private struct CatalogFilters: Equatable {
    var categoryID = ""
    var author = ""
    var publisher = ""
    var isbn = ""
    var order = "latest"
    var premiumOnly = false

    var isActive: Bool {
        !categoryID.isEmpty || !author.isEmpty || !publisher.isEmpty || !isbn.isEmpty || order != "latest" || premiumOnly
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
                    Toggle(L10n.catalogFilterPremium, isOn: $filters.premiumOnly)
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

            if isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.46), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
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
                .accessibilityLabel(L10n.catalogFilterPremium)
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
