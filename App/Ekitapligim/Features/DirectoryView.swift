import SwiftUI
import EkitapligimCore

private let turkishAlphabet = ["#", "A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H", "I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P", "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"]

@MainActor
struct DirectoryView: View {
    @EnvironmentObject private var container: AppContainer
    let kind: DirectoryKind

    @State private var items: [DirectoryItemDTO] = []
    @State private var query = ""
    @State private var selectedLetter = "#"
    @State private var sortAscending = true
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var heroCollapseProgress: CGFloat = 0

    private var filteredItems: [DirectoryItemDTO] {
        var result = items
        if selectedLetter != "#" {
            result = result.filter { directoryFirstLetter($0.name) == selectedLetter }
        }
        result.sort { sortAscending ? $0.name.localizedCompare($1.name) == .orderedAscending : $0.name.localizedCompare($1.name) == .orderedDescending }
        return result
    }

    private var totalBooks: Int { items.reduce(0) { $0 + $1.bookCount } }

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
                            EKScrollOffsetTracker()
                            heroCard
                            alphabetChips
                            sortChip
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
                    .ekCollapsibleScrollTracking { heroCollapseProgress = $0 }
                }
            }
        }
        .navigationTitle(kind == .author ? L10n.directoryAuthorsTitle : L10n.directoryPublishersTitle)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: L10n.directorySearchPrompt)
        .task { await load(reset: true) }
        .onSubmit(of: .search) { Task { await load(reset: true) } }
    }

    private var heroCard: some View {
        EKCollapsibleHero(progress: heroCollapseProgress) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(kind == .author ? EKitapligimPalette.tealSoft : EKitapligimPalette.amberSoft)
                        Image(systemName: kind == .author ? "person.fill" : "building.2.fill")
                            .font(.title2)
                            .foregroundStyle(kind == .author ? EKitapligimPalette.teal : EKitapligimPalette.amber)
                    }
                    .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind == .author ? L10n.directoryAuthorsTitle : L10n.directoryPublishersTitle)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(EKitapligimPalette.ink)
                        Text(L10n.directoryHeroSubtitle(items.count, totalBooks))
                            .font(.caption)
                            .foregroundStyle(EKitapligimPalette.muted)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    DirectoryStatTile(title: L10n.directoryStatEntries, value: EKitapligimFormat.count(items.count), systemImage: "person.2.fill")
                    DirectoryStatTile(title: L10n.directoryStatBooks, value: EKitapligimFormat.count(totalBooks), systemImage: "books.vertical.fill")
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: kind == .author
                        ? [Color(hex: 0xE8F7F7), Color(hex: 0xF7FAFA)]
                        : [Color(hex: 0xFFF8E8), Color(hex: 0xFFFCF4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(EKitapligimPalette.border) }
        } collapsed: {
            HStack(spacing: 10) {
                Image(systemName: kind == .author ? "person.fill" : "building.2.fill")
                    .foregroundStyle(kind == .author ? EKitapligimPalette.teal : EKitapligimPalette.amber)
                    .frame(width: 36, height: 36)
                    .background(
                        kind == .author ? EKitapligimPalette.tealSoft : EKitapligimPalette.amberSoft,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind == .author ? L10n.directoryAuthorsTitle : L10n.directoryPublishersTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.ink)
                        .lineLimit(1)
                    Text(L10n.directoryHeroSubtitle(items.count, totalBooks))
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .ekitapligimCard(radius: 14)
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
            .background(EKitapligimPalette.tealSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func load(reset: Bool) async {
        guard !isLoading || reset else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let page = reset ? 1 : currentPage + 1
        do {
            let result = try await container.directories.items(
                kind: kind,
                page: page,
                query: query.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            items = reset ? result.items : items + result.items.filter { newItem in
                !items.contains(where: { $0.id == newItem.id })
            }
            currentPage = result.currentPage
            lastPage = result.lastPage
        } catch {
            if reset { errorMessage = L10n.directoryLoadFailed }
        }
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
    let title: String
    let value: String
    var systemImage: String = "books.vertical.fill"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.teal)
                .frame(width: 30, height: 30)
                .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline.weight(.heavy)).foregroundStyle(EKitapligimPalette.ink)
                Text(title).font(.caption2).foregroundStyle(EKitapligimPalette.muted)
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

            HStack(spacing: 14) {
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
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(accent)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.ink)
                        .lineLimit(2)
                    Text(L10n.directoryBookCount(item.bookCount))
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
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
    let kind: DirectoryKind
    let item: DirectoryItemDTO

    @State private var books: [BookDTO] = []
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 16)]

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
        VStack(alignment: .leading, spacing: 8) {
            Text(kind == .author ? L10n.directoryAuthorArchive : L10n.directoryPublisherArchive)
                .font(.caption.weight(.heavy))
                .foregroundStyle(kind == .author ? EKitapligimPalette.teal : EKitapligimPalette.amber)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((kind == .author ? EKitapligimPalette.tealSoft : EKitapligimPalette.amberSoft), in: Capsule())
            Text(item.name)
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text(L10n.directoryBookCount(books.count))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: kind == .author
                    ? [Color(hex: 0x0B343B), Color(hex: 0x0E5960)]
                    : [Color(hex: 0x6B4E00), Color(hex: 0xC8942E)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: (kind == .author ? EKitapligimPalette.teal : EKitapligimPalette.amber).opacity(0.22), radius: 14, y: 8)
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
        } catch {
            if reset { errorMessage = L10n.catalogLoadFailed }
        }
    }
}

@MainActor
private struct DirectoryBookGridCard: View {
    let book: BookDTO
    let kind: DirectoryKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EKitapligimRemoteCover(urlString: book.coverUrl)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: EKitapligimPalette.ink.opacity(0.08), radius: 8, y: 4)
            Text(book.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.ink)
                .lineLimit(2)
            Text(kind == .author ? book.publisher : book.author)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.muted)
                .lineLimit(1)
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
