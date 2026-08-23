import SwiftUI
import EkitapligimCore

/// Android `library/{tab}` indeksleriyle aynı: 0 Okuyorum, 1 Okuyacağım, 2 Okudum, 3 Favoriler, 4 İndirmeler.
enum LibraryTab: Int, CaseIterable, Identifiable, Hashable {
    case reading = 0
    case wantToRead = 1
    case finished = 2
    case favorites = 3
    case downloads = 4

    var id: Int { rawValue }

    init(index: Int) {
        self = LibraryTab(rawValue: index) ?? .reading
    }

    var title: String {
        switch self {
        case .reading: L10n.libraryTabReading
        case .wantToRead: L10n.libraryTabWantToRead
        case .finished: L10n.libraryTabFinished
        case .favorites: L10n.libraryTabFavorites
        case .downloads: L10n.libraryTabDownloads
        }
    }

    var icon: String {
        switch self {
        case .reading: "book.pages.fill"
        case .wantToRead: "clock.fill"
        case .finished: "checkmark.seal.fill"
        case .favorites: "heart.fill"
        case .downloads: "arrow.down.circle.fill"
        }
    }
}

@MainActor
struct LibraryView: View {
    @EnvironmentObject private var container: AppContainer

    private let initialTab: LibraryTab
    @State private var selectedTab: LibraryTab
    @State private var items: [LibraryItemDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(initialTab: LibraryTab = .reading) {
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    headerCard
                    tabPicker
                    content
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .refreshable { await load() }
        }
        .navigationTitle(L10n.libraryHeaderTitle)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.title2)
                .foregroundStyle(EKitapligimPalette.teal)
                .frame(width: 48, height: 48)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(EKitapligimPalette.border) }
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.libraryHeaderTitle)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.ink)
                Text(L10n.libraryHeaderSubtitle)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            Spacer()
            VStack(spacing: 1) {
                Text(items.count, format: .number)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.tealDark)
                Text(L10n.libraryBookCountLabel)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 244 / 255, green: 249 / 255, blue: 1), Color(red: 236 / 255, green: 248 / 255, blue: 245 / 255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(EKitapligimPalette.border) }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LibraryTab.allCases) { tab in
                    Button { selectedTab = tab } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .accessibilityLabel(tab.title)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.title).font(.caption.weight(.bold))
                                Text(tabCount(tab), format: .number).font(.caption2)
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? EKitapligimPalette.tealDark : EKitapligimPalette.muted)
                        .padding(.horizontal, 13)
                        .frame(height: 58)
                        .background(selectedTab == tab ? EKitapligimPalette.tealSoft : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedTab == tab ? EKitapligimPalette.teal : EKitapligimPalette.border, lineWidth: selectedTab == tab ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                }
            }
        }
        .accessibilityLabel(L10n.libraryShelfPicker)
    }

    @ViewBuilder private var content: some View {
        if isLoading {
            ProgressView(L10n.libraryLoading).tint(EKitapligimPalette.teal).padding(.top, 60)
        } else if let errorMessage {
            ContentUnavailableView(L10n.libraryUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                .padding(.top, 40)
        } else if filteredItems.isEmpty {
            ContentUnavailableView(L10n.libraryEmptyTitle, systemImage: "bookmark", description: Text(L10n.libraryEmptyDescription))
                .padding(.top, 40)
        } else {
            ForEach(filteredItems, id: \.bookId) { item in
                NavigationLink { BookDetailView(bookID: Int(item.bookId) ?? 0) } label: {
                    LibraryBookCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredItems: [LibraryItemDTO] { items(for: selectedTab) }

    private func items(for tab: LibraryTab) -> [LibraryItemDTO] {
        switch tab {
        case .reading:
            items.filter {
                let shelf = $0.shelfState.uppercased()
                return shelf == "OKUYORUM" || shelf == "READING" || ($0.progressPercent > 0 && $0.progressPercent < 100)
            }
        case .wantToRead:
            items.filter {
                let shelf = $0.shelfState.uppercased()
                return shelf == "OKUYACAGIM" || shelf == "WANT_TO_READ"
            }
        case .finished:
            items.filter {
                let shelf = $0.shelfState.uppercased()
                return shelf == "OKUDUM" || shelf == "READ" || $0.progressPercent >= 100
            }
        case .favorites:
            items.filter(\.isFavorite)
        case .downloads:
            items.filter(\.isDownloaded)
        }
    }

    private func tabCount(_ tab: LibraryTab) -> Int { items(for: tab).count }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard container.isSignedIn else {
            items = []
            return
        }
        do {
            items = try await container.books.library().items
        } catch {
            errorMessage = L10n.libraryLoadFailed
        }
    }
}

private struct LibraryBookCard: View {
    let item: LibraryItemDTO

    var body: some View {
        HStack(spacing: 16) {
            EKitapligimRemoteCover(urlString: item.coverUrl)
                .frame(width: 76, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title.isEmpty ? L10n.commonBookNumber(item.bookId) : item.title)
                    .font(.headline)
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(2)
                if !item.author.isEmpty {
                    Text(item.author).font(.subheadline).foregroundStyle(EKitapligimPalette.muted).lineLimit(1)
                }
                Spacer(minLength: 3)
                HStack {
                    Text(L10n.commonPercent(item.progressPercent)).font(.caption.weight(.bold))
                    Spacer()
                    if item.isFavorite { Image(systemName: "heart.fill").foregroundStyle(EKitapligimPalette.amber) }
                    if item.isDownloaded { Image(systemName: "arrow.down.circle.fill").foregroundStyle(EKitapligimPalette.teal) }
                }
                ProgressView(value: Double(item.progressPercent), total: 100)
                    .tint(EKitapligimPalette.teal)
                    .accessibilityLabel(L10n.libraryReadingProgressLabel)
            }
            Image(systemName: "chevron.right").foregroundStyle(EKitapligimPalette.teal)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }
}
