import SwiftUI
import EkitapligimCore

@MainActor
struct DirectoryView: View {
    @EnvironmentObject private var container: AppContainer
    let kind: DirectoryKind

    var body: some View {
        DirectoryContent(kind: kind)
            .id(kind.rawValue + container.sessionRevision.uuidString)
    }
}

@MainActor
private struct DirectoryContent: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var searchFocused: Bool
    let kind: DirectoryKind
    @StateObject private var model = DirectoryListModel()
    @State private var query = ""
    @State private var selectedLetter = "#"
    @State private var sortAscending = true
    private var filter: DirectoryFilter { DirectoryFilter(query: query, letter: selectedLetter) }
    private var filteredItems: [DirectoryItemDTO] { filter.sorted(model.items, ascending: sortAscending) }
    private var title: String { kind == .author ? L10n.directoryAuthorsTitle : L10n.directoryPublishersTitle }
    private var accent: Color { DirectoryStyle.accent(kind) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                DirectoryScenicHeader(kind: kind, totalEntries: model.totalEntries, totalBooks: model.totalBooks)
                filterCard
                resultsHeading
                if model.isLoading && model.items.isEmpty {
                    ProgressView(DirectoryDesignL10n.text("results.loading"))
                        .tint(accent).font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 24)
                } else if model.items.isEmpty && model.errorMessage == nil {
                    VStack(spacing: 14) {
                        EKStateCard(title: L10n.directoryEmptyTitle, message: L10n.directoryEmptyDescription)
                        if !filter.isUnfiltered {
                            Button(DirectoryDesignL10n.text("results.reset")) { query = ""; selectedLetter = "#" }
                                .buttonStyle(CommunityButtonStyle(primary: false))
                                .accessibilityIdentifier("directory.reset")
                        }
                    }
                }
                ForEach(filteredItems) { item in
                    NavigationLink {
                        DirectoryBooksView(kind: kind, item: item)
                    } label: {
                        DirectoryEntryCard(kind: kind, item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("directory.item.\(item.id)")
                }
                if let error = model.errorMessage {
                    EKErrorState(title: L10n.directoryUnavailableTitle, message: error) {
                        Task { await load(reset: model.currentPage == 0) }
                    }
                } else if model.isLoading || model.hasMore {
                    Button { Task { await load(reset: false) } } label: {
                        HStack(spacing: 10) {
                            if model.isLoading { ProgressView().tint(accent) }
                            else { Image(systemName: "arrow.down") }
                            Text(model.isLoading ? DirectoryDesignL10n.text("results.loading") : L10n.commonLoadMore)
                        }
                    }
                    .buttonStyle(CommunityButtonStyle(primary: false))
                    .disabled(model.isLoading)
                    .accessibilityIdentifier("directory.loadMore")
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("directory.scroll")
        .background { CommunityStyle.page.ignoresSafeArea() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(DirectoryDesignL10n.text("search.done")) { searchFocused = false }
            }
        }
        .task(id: filter) {
            let selection = filter
            let queryChanged = model.filter.query != selection.query
            model.select(selection)
            if queryChanged, !selection.query.isEmpty, !model.hasFreshSnapshot(for: selection) {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await load(reset: true)
        }
        .task {
            model.configure(kind: kind, repository: container.directories, site: container.site)
            await model.loadStatistics()
        }
        .refreshable { await load(reset: true, forceRefresh: true) }
        .onDisappear { model.cancelLoading() }
    }

    private var filterCard: some View {
        CommunityCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: DirectoryStyle.symbol(kind))
                    .font(.system(.title3, design: .serif).weight(.semibold)).foregroundStyle(DirectoryStyle.ink)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(accent).accessibilityHidden(true)
                    TextField(DirectoryDesignL10n.text(kind == .author ? "authors.search" : "publishers.search"), text: $query)
                        .font(.body).foregroundStyle(DirectoryStyle.ink).tint(accent)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($searchFocused).submitLabel(.search)
                        .onSubmit { searchFocused = false }
                        .accessibilityIdentifier("directory.search")
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(DirectoryStyle.muted)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain).accessibilityLabel(DirectoryDesignL10n.text("search.clear"))
                        .accessibilityIdentifier("directory.clearSearch")
                    }
                }
                .padding(.leading, 14).padding(.trailing, query.isEmpty ? 14 : 4).padding(.vertical, 5)
                .frame(minHeight: 54)
                .background(DirectoryStyle.cream.opacity(0.6), in: RoundedRectangle(cornerRadius: 15))
                .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(searchFocused ? accent : DirectoryStyle.border, lineWidth: searchFocused ? 1.5 : 1) }
                alphabetChips
            }
        }
    }

    private var alphabetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DirectoryFilter.letters, id: \.self) { letter in
                    Button {
                        selectedLetter = letter
                        searchFocused = false
                    } label: {
                        Text(letter == "#" ? DirectoryDesignL10n.text("all") : letter)
                            .font(.subheadline.weight(selectedLetter == letter ? .bold : .medium))
                            .foregroundStyle(selectedLetter == letter ? .white : DirectoryStyle.ink)
                            .padding(.horizontal, 13).padding(.vertical, 11).frame(minWidth: 44, minHeight: 44)
                            .background(selectedLetter == letter ? accent : .white, in: RoundedRectangle(cornerRadius: 13))
                            .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(selectedLetter == letter ? .clear : Color(hex: 0xE5D3B5)) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("directory.letter.\(letter)")
                    .accessibilityAddTraits(selectedLetter == letter ? .isSelected : [])
                }
            }.padding(.vertical, 2)
        }.accessibilityIdentifier("directory.alphabet")
    }

    private var resultsHeading: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 5) {
                Text((selectedLetter == "#" ? "" : selectedLetter + " · ") + DirectoryDesignL10n.resultCount(
                    kind: kind, count: model.items.count, complete: !model.hasMore && !model.isLoading && model.errorMessage == nil))
                    .font(.system(.headline, design: .serif)).foregroundStyle(DirectoryStyle.ink)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("directory.results")
                Text(DirectoryDesignL10n.text(model.isLoading ? "results.loading" : model.hasMore || model.errorMessage != nil ? "results.more" : "results.complete"))
                    .font(.caption).foregroundStyle(DirectoryStyle.muted).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button { sortAscending.toggle() } label: {
                Label(DirectoryDesignL10n.text(sortAscending ? "sort.ascending" : "sort.descending"), systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                    .padding(.horizontal, 13).padding(.vertical, 10).frame(minHeight: 44)
                    .background(.white, in: RoundedRectangle(cornerRadius: 13))
                    .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(DirectoryStyle.border) }
            }
            .buttonStyle(.plain).accessibilityIdentifier("directory.sort")
            .accessibilityLabel(sortAscending ? L10n.directorySortAscending : L10n.directorySortDescending)
        }
    }

    private func load(reset: Bool, forceRefresh: Bool = false) async {
        model.configure(kind: kind, repository: container.directories, site: container.site)
        await model.load(filter: filter, reset: reset, forceRefresh: forceRefresh)
    }
}

@MainActor
struct DirectoryBooksView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let kind: DirectoryKind
    let item: DirectoryItemDTO

    @State private var books: [BookDTO] = []
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var totalBooks = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 16)]
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && books.isEmpty {
                    EKLoadingState(message: L10n.catalogLoading)
                } else if let errorMessage, books.isEmpty {
                    EKErrorState(title: L10n.catalogUnavailableTitle, message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else if books.isEmpty {
                    EKEmptyState(title: L10n.catalogEmptyTitle, message: L10n.catalogEmptyDescription, systemImage: "books.vertical")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            heroCard
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(books) { book in
                                    NavigationLink {
                                        BookDetailView(bookID: Int(book.id) ?? 0)
                                    } label: {
                                        DirectoryBookGridCard(book: book, kind: kind)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if currentPage < lastPage {
                                EKLoadMoreButton(isLoading: isLoading) {
                                    Task { await load(reset: false) }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(reset: true) }
    }

    private var heroCard: some View {
        ModernHeroView(
            artwork: kind == .author ? "directory_authors_hero" : "directory_publishers_hero",
            eyebrow: kind == .author ? L10n.directoryAuthorArchive : L10n.directoryPublisherArchive,
            title: item.name,
            subtitle: L10n.directoryBookCount(max(item.bookCount, totalBooks, books.count)),
            accent: kind == .author ? EKitapligimPalette.teal : EKitapligimPalette.amber,
            minHeight: 200
        )
    }

    private func load(reset: Bool) async {
        guard !isLoading || reset else { return }
        guard reset || currentPage < lastPage else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await container.directories.books(kind: kind, slug: item.slug, page: reset ? 1 : currentPage + 1)
            if reset {
                books = result.books
            } else {
                books += result.books.filter { newBook in !books.contains(where: { $0.id == newBook.id }) }
            }
            currentPage = result.currentPage
            lastPage = result.lastPage
            totalBooks = max(item.bookCount, result.totalBooks, books.count)
        } catch {
            if reset { errorMessage = L10n.catalogLoadFailed }
        }
    }
}

@MainActor
private struct DirectoryBookGridCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let book: BookDTO
    let kind: DirectoryKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: EKitapligimPalette.ink.opacity(0.08), radius: 8, y: 4)
            Text(book.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            Text(kind == .author ? book.publisher : book.author)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.muted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
            if let rating = book.rating, rating > 0 {
                Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.amber)
            }
        }
        .padding(12)
        .background(EKitapligimPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(EKitapligimPalette.border)
        }
        .shadow(color: EKitapligimPalette.ink.opacity(0.04), radius: 8, y: 3)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
