import SwiftUI
import EkitapligimCore

struct LibraryView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var items: [LibraryItemDTO] = []
    @State private var selectedShelf: LibraryShelf = .all
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(L10n.libraryLoading)
                } else if let errorMessage {
                    ContentUnavailableView(L10n.libraryUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if filteredItems.isEmpty {
                    ContentUnavailableView(L10n.libraryEmptyTitle, systemImage: "bookmark", description: Text(L10n.libraryEmptyDescription))
                } else {
                    List(filteredItems, id: \.bookId) { item in
                        NavigationLink {
                            BookDetailView(bookID: Int(item.bookId) ?? 0)
                        } label: {
                            LibraryItemRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle(L10n.libraryTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DownloadsView()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .accessibilityLabel(L10n.libraryDownloadsLabel)
                }
            }
            .safeAreaInset(edge: .top) {
                Picker(L10n.libraryShelfPicker, selection: $selectedShelf) {
                    ForEach(LibraryShelf.allCases) { shelf in
                        Text(shelf.title).tag(shelf)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .background(.bar)
            }
            .task { await load() }
        }
    }

    private var filteredItems: [LibraryItemDTO] {
        switch selectedShelf {
        case .all:
            return items
        case .reading:
            return items.filter { $0.shelfState.uppercased() == "OKUYORUM" || $0.progressPercent > 0 }
        case .finished:
            return items.filter { $0.shelfState.uppercased() == "OKUDUM" || $0.progressPercent >= 100 }
        case .favorites:
            return items.filter(\.isFavorite)
        case .downloads:
            return items.filter(\.isDownloaded)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await container.books.library().items
        } catch {
            errorMessage = L10n.libraryLoadFailed
        }
    }
}

private enum LibraryShelf: String, CaseIterable, Identifiable {
    case all
    case reading
    case finished
    case favorites
    case downloads

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
}

private struct LibraryItemRow: View {
    let item: LibraryItemDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title.isEmpty ? L10n.commonBookNumber(item.bookId) : item.title)
                .font(.headline)
            if !item.author.isEmpty {
                Text(item.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(item.progressPercent), total: 100)
                .accessibilityLabel(L10n.libraryReadingProgressLabel)
            HStack {
                Text(L10n.commonPercent(item.progressPercent))
                if item.isFavorite {
                    Label(L10n.libraryFavoriteBadge, systemImage: "star.fill")
                }
                if item.isDownloaded {
                    Label(L10n.libraryDownloadedBadge, systemImage: "arrow.down.circle.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
