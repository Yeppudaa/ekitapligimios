import SwiftUI
import EkitapligimCore

@MainActor
struct CatalogView: View {
    @EnvironmentObject private var container: AppContainer
    let onOpenMenu: (() -> Void)?
    let embeddedInNavigationStack: Bool
    let hostsAudioNavigation: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var heroTitleSize: CGFloat = 25
    @ScaledMetric(relativeTo: .caption2) private var heroEyebrowSize: CGFloat = 11
    @State private var editorialSpotlight: BookDTO?
    @State private var heroExpanded = true
    @State private var showingReadingHelp = false
    @State private var books: [BookDTO] = []
    @State private var categories: [ForumDTO] = BookCategoryCatalog.sorted(BookCategoryCatalog.defaults)
    @State private var query = ""
    @State private var filters = CatalogFilters()
    @State private var currentPage = 1
    @State private var lastPage = 1
    @State private var totalBooks = 0
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var isLoadingMore = false
    @State private var loadGeneration = UUID()
    @State private var loadedRequest: CatalogRequestIdentity?
    @State private var showingFilters = false
    @State private var errorMessage: String?
    @State private var retryResetsResults = true
    @AppStorage("catalog.displayMode") private var displayModeRawValue = CatalogDisplayMode.grid.rawValue

    init(initialCategoryID: String = "", initialOrder: String = "latest", embeddedInNavigationStack: Bool = false,
         hostsAudioNavigation: Bool = false,
         onOpenMenu: (() -> Void)? = nil) {
        self.onOpenMenu = onOpenMenu
        self.embeddedInNavigationStack = embeddedInNavigationStack
        self.hostsAudioNavigation = hostsAudioNavigation
        _filters = State(initialValue: CatalogFilters(categoryID: initialCategoryID, order: initialOrder))
    }

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
        Group {
            if embeddedInNavigationStack { catalogContent }
            else { NavigationStack { catalogContent } }
        }
    }

    private var catalogContent: some View {
            ZStack {
                EKitapligimPageBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
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
                .refreshable { await load(reset: true) }
                .accessibilityIdentifier("catalog.scroll")
            }
            .navigationTitle(L10n.catalogTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .searchable(
                text: $query,
                isPresented: $container.isCatalogSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: L10n.catalogSearchPrompt
            )
            .tint(EKitapligimPalette.teal)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        displayModeRawValue = displayMode.toggled.rawValue
                    } label: {
                        Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                    }
                    .accessibilityLabel(displayMode == .list ? L10n.catalogShowGrid : L10n.catalogShowList)
                    .accessibilityIdentifier("catalog.displayMode")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingFilters = true } label: {
                        Image(systemName: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(L10n.catalogFiltersTitle)
                    .accessibilityIdentifier("catalog.filters")
                }
                if let onOpenMenu {
                    EKitapligimMenuToolbarItem(action: onOpenMenu)
                }
            }
            .audioPageNavigation(enabled: hostsAudioNavigation)
            .task {
                async let editorRequest: Void = loadEditorSelection()
                async let categoryRequest: Void = loadCategories()
                await load(reset: true)
                await categoryRequest
                await editorRequest
            }
            .alert(HomeRefreshL10n.text("catalog.help"), isPresented: $showingReadingHelp) {
                Button(L10n.commonClose, role: .cancel) { }
            } message: { Text(HomeRefreshL10n.text("catalog.helpBody")) }
            .onSubmit(of: .search) { Task { await load(reset: true) } }
            .onChange(of: query) { previous, current in
                if !previous.isEmpty && current.isEmpty {
                    Task { await load(reset: true) }
                }
            }
            .sheet(isPresented: $showingFilters) {
                CatalogFiltersView(filters: filters, categories: categories) { updated in
                    filters = updated
                    showingFilters = false
                    Task { await load(reset: true) }
                }
            }
    }

    private var catalogHero: some View {
        Group {
            if heroExpanded && !dynamicTypeSize.isAccessibilitySize && query.isEmpty {
                CatalogHeroColumns {
                    catalogHeroCopy
                    ZStack { catalogSpotlight }
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(filters.categoryID.isEmpty ? HomeRefreshL10n.text("catalog.title") : selectedCategoryTitle)
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .foregroundStyle(EKitapligimPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.catalogHeroBookCount(formattedTotalBooks))
                            .font(.caption).foregroundStyle(EKitapligimPalette.tealDark)
                    }
                    Spacer(minLength: 0)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Button { heroExpanded = true } label: {
                            Image(systemName: "arrow.up.and.down")
                                .frame(width: 48, height: 48)
                        }.accessibilityLabel(HomeRefreshL10n.text("catalog.expand"))
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { geometry in
                Image(ModernCatalogArtwork.asset(categoryID: filters.categoryID))
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
                    .clipped()
                    .overlay {
                        LinearGradient(stops: [
                            .init(color: Color(hex: 0xFFFAF2).opacity(0.98), location: 0),
                            .init(color: Color(hex: 0xFFFAF2).opacity(0.90), location: 0.36),
                            .init(color: Color(hex: 0xFFFAF2).opacity(0.40), location: 0.64),
                            .init(color: Color(hex: 0xFFFAF2).opacity(0.04), location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                    }
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(hex: 0xDCE5DF).opacity(0.8))
        }
        .shadow(color: Color(hex: 0x294F4C).opacity(0.06), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("catalog.scenicHero")
    }

    private var catalogHeroCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(HomeRefreshL10n.text("catalog.eyebrow"))
                .font(.system(size: heroEyebrowSize, weight: .semibold)).tracking(0.9)
                .foregroundStyle(Color(hex: 0x236673))
                .fixedSize(horizontal: false, vertical: true)
            catalogHeroTitle
                .font(.system(size: heroTitleSize, weight: .medium, design: .serif))
                .foregroundStyle(Color(hex: 0x173F4B))
                .lineSpacing(1)
            Text(HomeRefreshL10n.text("catalog.subtitle"))
                .font(.caption).foregroundStyle(Color(hex: 0x4D6D78))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            catalogHeroActions
        }
        .frame(maxWidth: 440, alignment: .leading)
    }

    @ViewBuilder private var catalogHeroTitle: some View {
        if filters.categoryID.isEmpty {
            (Text(HomeRefreshL10n.text("catalog.title.lead"))
                + Text("\n")
                + Text(HomeRefreshL10n.text("catalog.title.emphasis"))
                    .italic().foregroundColor(Color(hex: 0x237785)))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(HomeRefreshL10n.text("catalog.title"))
        } else {
            Text(selectedCategoryTitle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var catalogHeroActions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { heroExpanded = false } label: {
                Label(HomeRefreshL10n.text("catalog.explore"), systemImage: "book.pages")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 13).padding(.vertical, 10).frame(minHeight: 44)
                    .background(Color(hex: 0x205865), in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.18)) }
            }.buttonStyle(.plain)
            Button { showingReadingHelp = true } label: {
                Label(HomeRefreshL10n.text("catalog.help"), systemImage: "questionmark.circle")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color(hex: 0x205865))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 13).padding(.vertical, 10).frame(minHeight: 44)
                    .background(.white.opacity(0.92), in: Capsule())
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder private var catalogSpotlight: some View {
        if let book = editorialSpotlight {
            NavigationLink { BookDetailDestination(bookIDString: book.id) } label: {
                VStack(spacing: 0) {
                    EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(.white.opacity(0.14))
                        }
                    Text(book.title)
                        .font(.system(size: 9, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: 0xF4EAD5))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .padding(.horizontal, 2)
                        .padding(.top, 3)
                }
                .padding(.horizontal, 7)
                .padding(.top, 7)
                .padding(.bottom, 3)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x31575A), Color(hex: 0x173B40)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.28))
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.14))
                        .frame(width: 2)
                        .padding(.leading, 3)
                        .padding(.vertical, 8)
                }
                .shadow(color: Color(hex: 0x102D32).opacity(0.28), radius: 12, x: 5, y: 12)
                .rotation3DEffect(.degrees(-6), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
                .rotationEffect(.degrees(-3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(book.title)
            .accessibilityValue(book.author)
            .accessibilityIdentifier("catalog.editorialSpotlight")
        } else {
            // Reserve the book column while the real editorial selection loads.
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .accessibilityHidden(true)
        }
    }

    private func loadEditorSelection() async {
        guard let loaded = try? await container.homeEditorial.books(), !Task.isCancelled else { return }
        editorialSpotlight = HomeEditorialSelection.select(from: loaded, retaining: editorialSpotlight?.id)
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
                        traceCatalog("category-selected")
                        Task { await load(reset: true) }
                    }
                    .accessibilityIdentifier("catalog.category.\(forum.id)")
                }
            }
        }
        .accessibilityIdentifier("catalog.categories")
    }

    @ViewBuilder
    private var catalogBookArea: some View {
        if let message = errorMessage, books.isEmpty {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    L10n.catalogUnavailableTitle,
                    systemImage: "wifi.exclamationmark",
                    description: Text(message)
                )
                Button { retryFailedLoad() } label: {
                    Label(L10n.commonRetry, systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white).padding(.horizontal, 20).padding(.vertical, 12)
                        .frame(minHeight: 48)
                        .background(EKitapligimPalette.teal, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("catalog.retry")
            }
            .frame(minHeight: 220)
        } else if books.isEmpty && !isLoading && !isRefreshing {
            ContentUnavailableView(
                L10n.catalogEmptyTitle,
                systemImage: "magnifyingglass",
                description: Text(L10n.catalogEmptyDescription)
            )
            .frame(minHeight: 220)
        } else {
            if let message = errorMessage {
                EKInlineError(message: message, retryTitle: L10n.commonRetry, retry: retryFailedLoad)
                    .accessibilityIdentifier("catalog.retryInline")
            }
            catalogGridOrList
        }
    }

    @ViewBuilder
    private var catalogGridOrList: some View {
        switch dynamicTypeSize.isAccessibilitySize ? CatalogDisplayMode.list : displayMode {
        case .list:
            ForEach(books) { book in
                NavigationLink { BookDetailDestination(bookIDString: book.id) } label: { BookRow(book: book) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("catalog.book.\(book.id)")
            }
        case .grid:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118, maximum: 180), spacing: 14)],
                spacing: 18
            ) {
                ForEach(books) { book in
                    NavigationLink { BookDetailDestination(bookIDString: book.id) } label: { BookGridItem(book: book) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("catalog.book.\(book.id)")
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
        guard reset || (!isLoadingMore && !isLoading && !isRefreshing) else { return }
        traceCatalog("load-start")
        // Pagination belongs to the last successful query, not text still being edited.
        let request: CatalogRequestIdentity
        if reset {
            request = CatalogRequestIdentity(query: query.nilIfBlank, filters: filters)
        } else {
            guard let loadedRequest else { return }
            request = loadedRequest
        }
        let generation = UUID()
        loadGeneration = generation
        if reset {
            if loadedRequest != request {
                books = []
                currentPage = 1
                lastPage = 1
                totalBooks = 0
                loadedRequest = nil
            }
            isLoadingMore = false
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
            if loadGeneration == generation {
                isLoading = false
                isRefreshing = false
                isLoadingMore = false
            }
        }
        do {
            let page = reset ? 1 : currentPage + 1
            let result = try await container.books.books(
                page: page,
                query: request.query,
                category: request.filters.categoryID.nilIfBlank,
                author: request.filters.author.nilIfBlank,
                publisher: request.filters.publisher.nilIfBlank,
                isbn: request.filters.isbn.nilIfBlank,
                order: request.filters.order,
                premiumOnly: false
            )
            guard loadGeneration == generation, !Task.isCancelled else { return }
            books = reset ? result.books : books + result.books.filter { item in !books.contains(where: { $0.id == item.id }) }
            currentPage = result.currentPage
            lastPage = result.lastPage
            totalBooks = result.totalBooks
            loadedRequest = request
            traceCatalog("load-succeeded")
        } catch {
            guard loadGeneration == generation, !Task.isCancelled else { return }
            retryResetsResults = reset
            errorMessage = L10n.catalogLoadFailed
            traceCatalog("load-failed")
        }
    }

    private func traceCatalog(_ phase: StaticString) {
        #if DEBUG
        let process = ProcessInfo.processInfo
        guard process.arguments.contains("-modern-parity-ui-fixture"),
              process.environment["MODERN_PARITY_CATALOG_FAILURE"] == "1" else { return }
        NSLog("MODERN_CATALOG_PHASE %@ filtered=%d books=%d error=%d",
              String(describing: phase), filters.categoryID.isEmpty ? 0 : 1, books.count, errorMessage == nil ? 0 : 1)
        #endif
    }

    private func retryFailedLoad() {
        let reset = retryResetsResults
        Task { await load(reset: reset) }
    }

    private func loadCategories() async {
        guard let result = try? await container.community.forums() else { return }
        categories = BookCategoryCatalog.sorted(BookCategoryCatalog.merging(live: result.forums))
    }
}

/// Measure wrapped copy at its actual column width instead of falling back to a vertical hero.
private struct CatalogHeroColumns: Layout {
    private let spacing: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let proposedWidth = proposal.width ?? 320
        let width = proposedWidth.isFinite ? max(0, proposedWidth) : 320
        let columns = columnWidths(for: width)
        let copy = subviews[0].sizeThatFits(ProposedViewSize(width: columns.copy, height: nil))
        let book = subviews[1].sizeThatFits(ProposedViewSize(width: columns.book, height: nil))
        return CGSize(width: width, height: max(copy.height, book.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let columns = columnWidths(for: bounds.width)
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: columns.copy, height: nil)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(width: columns.book, height: nil)
        )
    }

    private func columnWidths(for width: CGFloat) -> (copy: CGFloat, book: CGFloat) {
        let book = min(154, width * 0.32)
        return (max(0, width - book - spacing), book)
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
            .frame(minHeight: 44)
            .background(isSelected ? EKitapligimPalette.teal : Color.white, in: Capsule())
            .contentShape(Capsule())
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

private struct CatalogRequestIdentity: Equatable {
    let query: String?
    let filters: CatalogFilters
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
                    .pickerStyle(.inline)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let book: BookDTO

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        layout {
            CatalogBookCover(book: book)
                .frame(width: 78, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: EKitapligimPalette.ink.opacity(0.16), radius: 10, y: 5)
            VStack(alignment: .leading, spacing: 6) {
                UniformCardText(book.title, lines: 2)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                UniformCardText(book.author, lines: 1)
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.muted)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) { metadata }
                } else {
                    HStack(spacing: 8) { metadata }
                }
                Spacer(minLength: 0)
                HStack {
                    Label((book.rating ?? 0).formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                        .foregroundStyle(EKitapligimPalette.amber)
                        .lineLimit(1)
                        .opacity(hasRating ? 1 : 0)
                        .accessibilityHidden(!hasRating)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(EKitapligimPalette.teal)
                }.font(.caption.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder private var metadata: some View {
        if !dynamicTypeSize.isAccessibilitySize || !book.category.isEmpty {
            UniformCardText(book.category, lines: 1)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.tealDark)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(EKitapligimPalette.tealSoft, in: Capsule())
                .opacity(book.category.isEmpty ? 0 : 1)
                .accessibilityHidden(book.category.isEmpty)
        }
        if !dynamicTypeSize.isAccessibilitySize || book.pageCount > 1 {
            Text(L10n.catalogBookPageCount(book.pageCount))
                .font(.caption.weight(.semibold)).foregroundStyle(EKitapligimPalette.muted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .opacity(book.pageCount > 1 ? 1 : 0)
                .accessibilityHidden(book.pageCount <= 1)
        }
    }

    private var hasRating: Bool { (book.rating ?? 0) > 0 }
}

@MainActor
private struct BookGridItem: View {
    @ScaledMetric(relativeTo: .caption2) private var metadataLineHeight: CGFloat = 14
    let book: BookDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CatalogBookCover(book: book)
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
            UniformCardText(book.title, lines: 2)
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.ink)
            UniformCardText(book.author, lines: 1)
                .font(.caption2)
                .foregroundStyle(EKitapligimPalette.muted)
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
            .frame(minHeight: metadataLineHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
        Color.clear
            .overlay {
                EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
            }
            .clipped()
            .background(EKitapligimPalette.tealSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
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
