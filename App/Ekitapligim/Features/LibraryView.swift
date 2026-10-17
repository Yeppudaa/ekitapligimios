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

    @State private var selectedTab: LibraryTab
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingLogin = false
    @State private var hasAppliedInitialShelf = false

    private var items: [LibraryItemDTO] { container.libraryItems }

    init(initialTab: LibraryTab = .reading) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        EKitapligimScreen {
            if container.isSignedIn {
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
            } else {
                guestPrompt
            }
        }
        .navigationTitle(L10n.libraryHeaderTitle)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingLogin) { LoginView() }
        .task { await load() }
        // Keep the requested shelf and local selection when a book detail is popped.
        // Explicit external library routes can still change an already mounted view.
        .onAppear {
            guard !hasAppliedInitialShelf else { return }
            hasAppliedInitialShelf = true
            container.libraryShelfTab = selectedTab.rawValue
        }
        .onChange(of: container.libraryShelfTab) { _, tab in
            selectedTab = LibraryTab(index: tab)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(HomeRefreshL10n.text("library.eyebrow"))
                .font(.caption2.weight(.bold)).tracking(1.5)
                .foregroundStyle(EKitapligimPalette.tealDark)
                .fixedSize(horizontal: false, vertical: true)
            Text(HomeRefreshL10n.text("library.title"))
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(EKitapligimPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(HomeRefreshL10n.text("library.subtitle"))
                .font(.subheadline).foregroundStyle(EKitapligimPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            selectedShelfSummary
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { geometry in
                Image("home_section_daily_selection").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    .overlay {
                        LinearGradient(colors: [Color(hex: 0xFCF6EA), Color(hex: 0xFCF6EA).opacity(0.93), Color(hex: 0xFCF6EA).opacity(0.46)], startPoint: .leading, endPoint: .trailing)
                    }
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color(hex: 0xE7DECD)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([
            HomeRefreshL10n.text("library.eyebrow"),
            HomeRefreshL10n.text("library.title"),
            HomeRefreshL10n.text("library.subtitle"),
            HomeRefreshL10n.booksWithYou(items.count),
            "\(selectedTab.title) · \(L10n.libraryTabBookCount(filteredItems.count))"
        ].joined(separator: ". "))
        .accessibilityIdentifier("library.scenicHero")
        .contentShape(.accessibility, RoundedRectangle(cornerRadius: 24))
    }

    private var guestPrompt: some View {
        VStack(spacing: 18) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(EKitapligimPalette.profileTeal)
                .frame(width: 88, height: 88)
                .background(EKitapligimPalette.profileTealSoft, in: Circle())
            Text(L10n.libraryGuestTitle)
                .font(.title3.weight(.heavy))
                .foregroundStyle(EKitapligimPalette.profileInk)
            Text(L10n.libraryGuestSubtitle)
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.profileMuted)
                .multilineTextAlignment(.center)
            Button {
                showingLogin = true
            } label: {
                Text(L10n.commonLogin)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(EKitapligimPalette.teal, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectedShelfSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(HomeRefreshL10n.booksWithYou(items.count), systemImage: "book.pages.fill")
                .font(.subheadline.weight(.bold)).foregroundStyle(EKitapligimPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(selectedTab.title) · \(L10n.libraryTabBookCount(filteredItems.count))")
                .font(.caption).foregroundStyle(EKitapligimPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xE7DECD)) }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LibraryTab.allCases) { tab in
                    let selected = selectedTab == tab
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                            container.libraryShelfTab = tab.rawValue
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: tab.icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selected ? .white : EKitapligimPalette.profileTeal)
                                .frame(width: 34, height: 34)
                                .background(
                                    selected ? EKitapligimPalette.profileTealDeep : EKitapligimPalette.profileTealSoft,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(selected ? .white : EKitapligimPalette.profileInk)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(L10n.libraryTabBookCount(tabCount(tab)))
                                    .font(.caption2)
                                    .foregroundStyle(selected ? .white.opacity(0.8) : EKitapligimPalette.profileMuted)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minHeight: 60)
                        .background(selected ? EKitapligimPalette.profileTealDeep : EKitapligimPalette.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    selected ? EKitapligimPalette.profileTealDeep : EKitapligimPalette.profileBorder,
                                    lineWidth: selected ? 1.5 : 1
                                )
                        }
                        .shadow(
                            color: selected ? EKitapligimPalette.profileTeal.opacity(0.18) : .clear,
                            radius: 8,
                            y: 3
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityIdentifier("library.shelf.\(tab.rawValue)")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
        .accessibilityLabel(L10n.libraryShelfPicker)
        .accessibilityIdentifier("library.shelves")
    }

    @ViewBuilder private var content: some View {
        if isLoading {
            ProgressView(L10n.libraryLoading)
                .tint(EKitapligimPalette.profileTeal)
                .padding(.top, 60)
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
                .accessibilityIdentifier("library.book.\(item.bookId)")
            }
        }
    }

    private var filteredItems: [LibraryItemDTO] { items(for: selectedTab) }

    private var libraryEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab.icon)
                .font(.title2)
                .foregroundStyle(EKitapligimPalette.profileTeal)
                .frame(width: 62, height: 62)
                .background(EKitapligimPalette.profileTealSoft, in: Circle())
            Text(L10n.libraryEmptyTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(EKitapligimPalette.profileInk)
            Text(L10n.libraryEmptyDescription)
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.profileMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .ekitapligimCard(radius: 18)
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

private struct LibraryHeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08))
        }
    }
}

private struct LibraryReadingProgressBar: View {
    let progress: Int

    private var clampedProgress: Int { min(max(progress, 0), 100) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(EKitapligimPalette.profileBorder.opacity(0.6))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [EKitapligimPalette.profileTeal, EKitapligimPalette.profileSuccess],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(clampedProgress) / 100)
            }
        }
        .frame(height: 6)
    }
}

private struct LibraryBookCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        layout {
            EKitapligimRemoteCover(urlString: item.coverUrl, title: item.title, author: item.author, accessibilityTitle: item.title)
                .frame(width: 76, height: 112)
                .background(EKitapligimPalette.profileTealSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: EKitapligimPalette.ink.opacity(0.14), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title.isEmpty ? L10n.commonBookNumber(item.bookId) : item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.author.isEmpty ? L10n.libraryAuthorMissing : item.author)
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)

                if !metaText.isEmpty {
                    EKPill(
                        title: metaText,
                        systemImage: metaIcon,
                        foreground: EKitapligimPalette.profileTealDeep,
                        background: EKitapligimPalette.profileTealSoft
                    )
                    .padding(.top, 4)
                }

                HStack(spacing: 10) {
                    LibraryReadingProgressBar(progress: item.displayProgressPercent)
                        .accessibilityLabel(L10n.libraryReadingProgressLabel)
                    Text("%\(item.displayProgressPercent)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.profileTealDeep)
                        .monospacedDigit()
                }
                .padding(.top, 6)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.profileTeal)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 18)
        .contextMenu {
            if let onRemoveDownload {
                Button(role: .destructive, action: onRemoveDownload) {
                    Label(L10n.commonRemove, systemImage: "trash")
                }
            }
        }
    }
}
