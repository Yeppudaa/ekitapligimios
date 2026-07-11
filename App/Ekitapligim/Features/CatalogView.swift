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
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var showingFilters = false
    @State private var errorMessage: String?
    @AppStorage("catalog.displayMode") private var displayModeRawValue = CatalogDisplayMode.list.rawValue

    private var displayMode: CatalogDisplayMode {
        CatalogDisplayMode(rawValue: displayModeRawValue) ?? .list
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(L10n.catalogLoading)
                } else if let message = errorMessage {
                    ContentUnavailableView(L10n.catalogUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(message))
                } else if books.isEmpty {
                    ContentUnavailableView(L10n.catalogEmptyTitle, systemImage: "magnifyingglass", description: Text(L10n.catalogEmptyDescription))
                } else {
                    catalogContent
                }
            }
            .navigationTitle(L10n.catalogTitle)
            .searchable(text: $query, prompt: L10n.catalogSearchPrompt)
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
                BookDetailView(bookID: Int(id) ?? 0)
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
        switch displayMode {
        case .list:
            List {
                ForEach(books) { book in
                    NavigationLink(value: book.id) { BookRow(book: book) }
                }
                loadMoreButton
            }
        case .grid:
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 16)],
                    spacing: 20
                ) {
                    ForEach(books) { book in
                        NavigationLink(value: book.id) { BookGridItem(book: book) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
                if currentPage < lastPage {
                    loadMoreButton
                        .buttonStyle(.bordered)
                        .padding(.bottom, 20)
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

@MainActor
private struct BookRow: View {
    let book: BookDTO

    var body: some View {
        HStack(spacing: 12) {
            BookCover(book: book)
                .frame(width: 54, height: 81)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(.headline).lineLimit(2)
                Text(book.author).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Text(book.category).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
private struct BookGridItem: View {
    let book: BookDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            BookCover(book: book)
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Text(book.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(book.author)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 4))
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
