import SwiftUI
import EkitapligimCore

@MainActor
struct LibraryView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var items: [LibraryItemDTO] = []
    @State private var selectedShelf: LibraryShelf = .all
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EKitapligimPageBackground()
                ScrollView {
                    LazyVStack(spacing: 14) {
                        headerCard
                        shelfPicker
                        content
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
                .refreshable { await load() }
            }
            .navigationTitle(L10n.libraryTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { DownloadsView() } label: {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    .accessibilityLabel(L10n.libraryDownloadsLabel)
                }
            }
            .tint(EKitapligimPalette.teal)
            .task { await load() }
        }
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
                Text(L10n.libraryTitle)
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

    private var shelfPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LibraryShelf.allCases) { shelf in
                    Button {
                        selectedShelf = shelf
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: shelf.icon)
                                .accessibilityLabel(shelf.title)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(shelf.title).font(.caption.weight(.bold))
                                Text(shelfCount(shelf), format: .number).font(.caption2)
                            }
                        }
                        .foregroundStyle(selectedShelf == shelf ? EKitapligimPalette.tealDark : EKitapligimPalette.muted)
                        .padding(.horizontal, 13)
                        .frame(height: 58)
                        .background(selectedShelf == shelf ? EKitapligimPalette.tealSoft : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedShelf == shelf ? EKitapligimPalette.teal : EKitapligimPalette.border, lineWidth: selectedShelf == shelf ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(shelf.title)
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

    private var filteredItems: [LibraryItemDTO] { filteredItems(for: selectedShelf) }

    private func filteredItems(for shelf: LibraryShelf) -> [LibraryItemDTO] {
        switch shelf {
        case .all: items
        case .reading: items.filter { $0.shelfState.uppercased() == "OKUYORUM" || ($0.progressPercent > 0 && $0.progressPercent < 100) }
        case .finished: items.filter { $0.shelfState.uppercased() == "OKUDUM" || $0.progressPercent >= 100 }
        case .favorites: items.filter(\.isFavorite)
        case .downloads: items.filter(\.isDownloaded)
        }
    }

    private func shelfCount(_ shelf: LibraryShelf) -> Int { filteredItems(for: shelf).count }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { items = try await container.books.library().items }
        catch { errorMessage = L10n.libraryLoadFailed }
    }
}

private enum LibraryShelf: String, CaseIterable, Identifiable {
    case all, reading, finished, favorites, downloads
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: L10n.libraryShelfAll
        case .reading: L10n.libraryShelfReading
        case .finished: L10n.libraryShelfFinished
        case .favorites: L10n.libraryShelfFavorites
        case .downloads: L10n.libraryShelfDownloads
        }
    }
    var icon: String {
        switch self {
        case .all: "books.vertical"
        case .reading: "book.pages"
        case .finished: "checkmark.circle"
        case .favorites: "heart"
        case .downloads: "arrow.down.circle"
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
