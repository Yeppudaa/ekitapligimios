import SwiftUI
import EkitapligimCore

private let turkishAlphabet = ["#", "A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H", "I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P", "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"]

@MainActor
struct DirectoryView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let kind: DirectoryKind

    @State private var items: [DirectoryItemDTO] = []
    @State private var query = ""
    @State private var selectedLetter = "#"
    @State private var sortAscending = true
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var totalEntries = 0
    @State private var totalBooks = 0
    @State private var isLoading = true
    @State private var loadGeneration = UUID()
    @State private var errorMessage: String?

    private var filteredItems: [DirectoryItemDTO] {
        var result = items
        if selectedLetter != "#" {
            result = result.filter { directoryFirstLetter($0.name) == selectedLetter }
        }
        result.sort { sortAscending ? $0.name.localizedCompare($1.name) == .orderedAscending : $0.name.localizedCompare($1.name) == .orderedDescending }
        return result
    }

    private var entryStatTitle: String {
        kind == .author ? L10n.homeAuthors : L10n.homePublishers
    }

    private var entryStatImage: String {
        kind == .author ? "person.2.fill" : "building.2.fill"
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && items.isEmpty {
                    EKLoadingState(message: L10n.directoryLoading)
                } else if let errorMessage, items.isEmpty {
                    EKErrorState(title: L10n.directoryUnavailableTitle, message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            heroCard
                            statsRow
                            alphabetChips
                            sortChip
                            Text(CommunityRefreshL10n.count("directory.results", filteredItems.count))
                                .font(.caption).foregroundStyle(EKitapligimPalette.muted)
                            if filteredItems.isEmpty {
                                EKStateCard(title: L10n.directoryEmptyTitle, message: L10n.directoryEmptyDescription)
                            } else {
                                ForEach(filteredItems) { item in
                                    NavigationLink {
                                        DirectoryBooksView(kind: kind, item: item)
                                    } label: {
                                        DirectoryCard(kind: kind, item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if currentPage < lastPage {
                                    EKLoadMoreButton(isLoading: isLoading) {
                                        Task { await load(reset: false) }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle(kind == .author ? L10n.directoryAuthorsTitle : L10n.directoryPublishersTitle)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: L10n.directorySearchPrompt)
        .task { await load(reset: true) }
        .onSubmit(of: .search) { Task { await load(reset: true) } }
        .refreshable { await load(reset: true) }
    }

    private var heroCard: some View {
        ModernHeroView(
            artwork: kind == .author ? "directory_authors_hero" : "directory_publishers_hero",
            eyebrow: CommunityRefreshL10n.text(kind == .author ? "directory.authorsEyebrow" : "directory.publishersEyebrow"),
            title: CommunityRefreshL10n.text(kind == .author ? "directory.authorsTitle" : "directory.publishersTitle"),
            subtitle: CommunityRefreshL10n.text(kind == .author ? "directory.authorsBody" : "directory.publishersBody"),
            accent: kind == .author ? EKitapligimPalette.teal : EKitapligimPalette.amber,
            minHeight: 250
        )
    }
    private var statsRow: some View {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            DirectoryStatTile(title: entryStatTitle, value: EKitapligimFormat.count(totalEntries), systemImage: entryStatImage)
            DirectoryStatTile(title: L10n.directoryStatBooks, value: EKitapligimFormat.count(totalBooks), systemImage: "books.vertical.fill")
        }
    }

    private var alphabetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(turkishAlphabet, id: \.self) { letter in
                    EKChip(
                        title: letter,
                        isSelected: selectedLetter == letter,
                        selectedBackground: kind == .author ? EKitapligimPalette.teal : EKitapligimPalette.amber
                    ) {
                        selectedLetter = letter
                    }
                }
            }
        }
    }

    private var sortChip: some View {
        Button {
            sortAscending.toggle()
        } label: {
            Label(
                sortAscending ? L10n.directorySortAscending : L10n.directorySortDescending,
                systemImage: "arrow.up.arrow.down"
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(EKitapligimPalette.tealDark)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(EKitapligimPalette.tealSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func load(reset: Bool) async {
        guard !isLoading || reset else { return }
        let generation = UUID()
        loadGeneration = generation
        isLoading = true
        errorMessage = nil
        defer { if loadGeneration == generation { isLoading = false } }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let page = reset ? 1 : currentPage + 1
        do {
            async let directoryRequest = container.directories.items(
                kind: kind,
                page: page,
                query: trimmedQuery.nilIfEmpty
            )
            async let statsRequest = loadSiteStatsIfNeeded(reset)

            let result = try await directoryRequest
            let stats = await statsRequest
            guard loadGeneration == generation, !Task.isCancelled else { return }
            items = reset ? result.items : items + result.items.filter { newItem in
                !items.contains(where: { $0.id == newItem.id })
            }
            currentPage = result.currentPage
            lastPage = result.lastPage
            applyDirectoryTotals(result: result, stats: stats, isSearching: !trimmedQuery.isEmpty)
        } catch {
            guard loadGeneration == generation, !Task.isCancelled else { return }
            if reset { errorMessage = L10n.directoryLoadFailed }
        }
    }

    private func loadSiteStatsIfNeeded(_ reset: Bool) async -> SiteStatsDTO? {
        guard reset else { return nil }
        return try? await container.site.stats()
    }

    private func applyDirectoryTotals(result: DirectoryPageDTO, stats: SiteStatsDTO?, isSearching: Bool) {
        let totals = result.displayTotals(
            kind: kind,
            stats: stats,
            loadedBookCount: items.reduce(0) { $0 + $1.bookCount },
            existingBookTotal: totalBooks,
            isSearching: isSearching
        )
        totalEntries = totals.entries
        totalBooks = totals.books
    }

    private func directoryFirstLetter(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "#" }
        let upper = String(first).uppercased(with: Locale(identifier: "tr_TR"))
        return turkishAlphabet.contains(upper) ? upper : "#"
    }
}

@MainActor
private struct DirectoryStatTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let value: String
    var systemImage: String = "books.vertical.fill"

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        layout {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(EKitapligimPalette.teal)
                .frame(width: 30, height: 30)
                .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline.weight(.heavy)).foregroundStyle(EKitapligimPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(title).font(.caption2).foregroundStyle(EKitapligimPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(EKitapligimPalette.border)
        }
    }
}

@MainActor
private struct DirectoryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let kind: DirectoryKind
    let item: DirectoryItemDTO

    private var accent: Color { kind == .author ? EKitapligimPalette.teal : EKitapligimPalette.amber }
    private var accentSoft: Color { kind == .author ? EKitapligimPalette.tealSoft : EKitapligimPalette.amberSoft }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .padding(.vertical, 10)

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
            layout {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentSoft, .white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(directoryInitials(item.name))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(accent)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.directoryBookCount(item.bookCount))
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text(EKitapligimFormat.count(item.bookCount))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accentSoft, in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(EKitapligimPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EKitapligimPalette.border)
        }
        .shadow(color: EKitapligimPalette.ink.opacity(0.05), radius: 10, y: 4)
    }

    private func directoryInitials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let initials = parts.compactMap(\.first)
        let value = String(initials)
        return value.isEmpty ? "#" : value.uppercased(with: Locale(identifier: "tr_TR"))
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
