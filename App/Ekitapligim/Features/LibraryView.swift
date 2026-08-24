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
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var items: [LibraryItemDTO] { container.libraryItems }

    init(initialTab: LibraryTab = .reading) {
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            Color(hex: 0xF6FAFA).ignoresSafeArea()
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
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: 0x16756F))
                    .frame(width: 48, height: 48)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xDDE8E8)) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.libraryHeaderTitle)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color(hex: 0x18343A))
                    Text(L10n.libraryHeaderSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x6C7C80))
                }
                Spacer()
                VStack(spacing: 1) {
                    Text(items.count, format: .number)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color(hex: 0x16756F))
                    Text(L10n.libraryBookCountLabel)
                        .font(.caption2)
                        .foregroundStyle(Color(hex: 0x6C7C80))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: 0xDDE8E8), lineWidth: 1)
                }
            }

            selectedShelfSummary
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xF4F9FF), Color(hex: 0xECF8F5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0xDDE8E8)) }
    }

    private var selectedShelfSummary: some View {
        HStack(spacing: 7) {
            Text(L10n.librarySelectedShelfLabel)
                .font(.caption)
                .foregroundStyle(Color(hex: 0x6C7C80))
            Spacer(minLength: 0)
            Text(L10n.librarySelectedShelfBooks(filteredItems.count))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: 0x18343A))
            Text(EKitapligimFormat.count(filteredItems.count))
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color(hex: 0x16756F))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: 0xEAF6F4), in: Capsule())
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LibraryTab.allCases) { tab in
                    Button { selectedTab = tab } label: {
                        let selected = selectedTab == tab
                        HStack(spacing: 9) {
                            Image(systemName: tab.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(selected ? .white : Color(hex: 0x16756F))
                                .frame(width: 36, height: 36)
                                .background(
                                    selected ? Color(hex: 0x16756F) : Color(hex: 0xEAF6F4),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                )
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(hex: 0x18343A))
                                Text(L10n.libraryTabBookCount(tabCount(tab)))
                                    .font(.caption2)
                                    .foregroundStyle(selected ? Color(hex: 0x16756F) : Color(hex: 0x6C7C80))
                            }
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 64)
                        .background(selected ? Color(hex: 0xF0FAF8) : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected ? Color(hex: 0x16756F) : Color(hex: 0xDDE8E8), lineWidth: selected ? 2 : 1)
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
            ProgressView(L10n.libraryLoading).tint(Color(hex: 0x16756F)).padding(.top, 60)
        } else if let errorMessage {
            ContentUnavailableView(L10n.libraryUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                .padding(.top, 40)
        } else if filteredItems.isEmpty {
            libraryEmptyState
                .padding(.top, 24)
        } else {
            ForEach(filteredItems, id: \.bookId) { item in
                NavigationLink { BookDetailDestination(bookIDString: item.bookId) } label: {
                    LibraryBookCard(
                        item: item,
                        metaText: cardMetaText(for: item),
                        onRemoveDownload: selectedTab == .downloads ? { Task { await removeDownload(item) } } : nil
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.libraryOpenBookDetail)
            }
        }
    }

    private var filteredItems: [LibraryItemDTO] { items(for: selectedTab) }

    private var libraryEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab.icon)
                .font(.title2)
                .foregroundStyle(Color(hex: 0x16756F))
                .frame(width: 62, height: 62)
                .background(Color(hex: 0xEAF6F4), in: Circle())
            Text(L10n.libraryEmptyTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(hex: 0x18343A))
            Text(L10n.libraryEmptyDescription)
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0x6C7C80))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xDDE8E8))
        }
    }

    private func items(for tab: LibraryTab) -> [LibraryItemDTO] {
        switch tab {
        case .reading:
            items.filter(\.isOnReadingShelf)
        case .wantToRead:
            items.filter(\.isOnWantToReadShelf)
        case .finished:
            items.filter(\.isOnFinishedShelf)
        case .favorites:
            items.filter(\.isFavoriteItem)
        case .downloads:
            items.filter(isDownloaded)
        }
    }

    private func tabCount(_ tab: LibraryTab) -> Int { items(for: tab).count }

    private func isDownloaded(_ item: LibraryItemDTO) -> Bool {
        if item.isDownloaded { return true }
        return isLocallyDownloaded(item)
    }

    private func isLocallyDownloaded(_ item: LibraryItemDTO) -> Bool {
        let bookID = item.bookId
        if case .downloaded = container.downloadManager.states[bookID] { return true }
        return container.downloadManager.localFile(for: bookID) != nil
    }

    private func downloadSubtitle(for item: LibraryItemDTO) -> String? {
        guard selectedTab == .downloads else { return nil }
        if isLocallyDownloaded(item) { return L10n.libraryDownloadOfflineReady }
        if item.isDownloaded { return L10n.libraryDownloadServerHistory }
        return nil
    }

    private func cardMetaText(for item: LibraryItemDTO) -> String {
        if let downloadSubtitle = downloadSubtitle(for: item) {
            return downloadSubtitle
        }
        return item.libraryMetaText(treatingAsDownloaded: isDownloaded(item))
    }

    private func removeDownload(_ item: LibraryItemDTO) async {
        let bookID = item.bookId
        if let local = container.downloadManager.localFile(for: bookID) {
            await container.downloadManager.remove(bookID: bookID, fileExtension: local.fileType)
        } else if case .downloaded(let fileName) = container.downloadManager.states[bookID] {
            await container.downloadManager.remove(
                bookID: bookID,
                fileExtension: URL(fileURLWithPath: fileName).pathExtension
            )
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard container.isSignedIn else { return }
        if !(await container.refreshLibrary()) {
            errorMessage = L10n.libraryLoadFailed
        }
    }
}

private struct LibraryReadingProgressBar: View {
    let progress: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0xE3EEEE))
                Capsule()
                    .fill(Color(hex: 0x16756F))
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 100)) / 100)
            }
        }
        .frame(height: 7)
    }
}

private struct LibraryBookCard: View {
    let item: LibraryItemDTO
    let metaText: String
    var onRemoveDownload: (() -> Void)?

    private var metaIcon: String {
        switch metaText {
        case L10n.libraryMetaDownloaded, L10n.libraryDownloadOfflineReady, L10n.libraryDownloadServerHistory:
            "icloud.and.arrow.down"
        default:
            "book.fill"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            EKitapligimRemoteCover(urlString: item.coverUrl, accessibilityTitle: item.title)
                .frame(width: 76, height: 112)
                .background(Color(hex: 0xEDF4F4))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title.isEmpty ? L10n.commonBookNumber(item.bookId) : item.title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color(hex: 0x18343A))
                    .lineLimit(2)
                Text(item.author.isEmpty ? L10n.libraryAuthorMissing : item.author)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x6C7C80))
                    .lineLimit(1)

                if !metaText.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: metaIcon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: 0x16756F))
                        Text(metaText)
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: 0x6C7C80))
                            .lineLimit(1)
                    }
                    .padding(.top, 7)
                }

                HStack(spacing: 10) {
                    LibraryReadingProgressBar(progress: item.displayProgressPercent)
                        .accessibilityLabel(L10n.libraryReadingProgressLabel)
                    Text("%\(item.displayProgressPercent)")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Color(hex: 0x16756F))
                        .monospacedDigit()
                }
                .padding(.top, 7)
            }

            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(hex: 0x18343A))
                .frame(width: 44, height: 44)
                .background(Color(hex: 0xEAF6F4), in: Circle())
                .overlay { Circle().stroke(Color(hex: 0xDDE8E8), lineWidth: 1) }
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xDDE8E8), lineWidth: 1)
        }
        .contextMenu {
            if let onRemoveDownload {
                Button(role: .destructive, action: onRemoveDownload) {
                    Label(L10n.commonRemove, systemImage: "trash")
                }
            }
        }
    }
}
