import SwiftUI
@preconcurrency import PDFKit
@preconcurrency import UIKit
import EkitapligimCore

@MainActor
struct ReaderView: View {
    @EnvironmentObject private var container: AppContainer
    let book: BookDTO

    @State private var progress: ReadingProgress
    @State private var readerURL: URL?
    @State private var temporaryReaderURL: URL?
    @State private var readerFileType = "pdf"
    @State private var epubProgressPercent: Double = 0
    @State private var epubPosition = 1
    @State private var requestedPage: Int?
    @State private var isLoading = true
    @State private var errorTitle = L10n.readerUnavailable
    @State private var errorMessage: String?
    @State private var showsBookmarks = false
    @State private var showsPagePicker = false
    @State private var showsReaderSettings = false
    @State private var pdfLayout: PDFReadingLayout = .continuous
    @State private var bookmarks: [ReaderBookmark] = []
    @State private var initialPosition: ReaderPositionDTO?
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadGeneration = UUID()
    @State private var hasScheduledShelfPromotion = false

    init(book: BookDTO) {
        self.book = book
        _progress = State(initialValue: ReadingProgress(currentPage: 1, totalPages: book.pageCount))
    }

    private var bookID: Int? { Int(book.id) }

    var body: some View {
        VStack(spacing: 0) {
            readerToolbar
            Divider()
            readerContent
        }
        .background(EKitapligimPalette.page)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsBookmarks) {
            ReaderBookmarksView(
                bookmarks: bookmarks,
                onSelect: { bookmark in
                    requestedPage = bookmark.page
                    showsBookmarks = false
                },
                onDelete: removeBookmarks
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsPagePicker) {
            if let readerURL, readerFileType == "pdf" {
                PDFPagePickerView(
                    url: readerURL,
                    selectedPage: progress.currentPage,
                    onSelect: { page in
                        requestedPage = page
                        showsPagePicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showsReaderSettings) {
            ReaderSettingsView(layout: $pdfLayout, fileType: readerFileType)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            refreshBookmarks()
            await loadReaderSession()
        }
        .preference(key: AILauncherHiddenKey.self, value: true)
        .onDisappear {
            loadGeneration = UUID()
            flushProgress()
            container.readerContentLoader.removePreparedFile(at: temporaryReaderURL)
            temporaryReaderURL = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { flushProgress() }
        }
    }

    @ViewBuilder
    private var readerToolbar: some View {
        ReaderToolbar(
            title: book.title,
            progressPercent: displayedProgressPercent,
            detail: readerFileType == "epub" ? L10n.readerEPUBFormat : L10n.readerPage(progress.currentPage, progress.totalPages),
            author: book.author,
            isBookmarked: isCurrentPageBookmarked,
            bookmarkCount: bookmarks.count,
            supportsBookmarks: readerFileType != "epub",
            syncState: syncState,
            onToggleBookmark: toggleCurrentBookmark,
            onShowBookmarks: { showsBookmarks = true },
            onShowPages: { showsPagePicker = true },
            onShowSettings: { showsReaderSettings = true }
        )
    }

    @ViewBuilder
    private var readerContent: some View {
        if isLoading {
            ProgressView(L10n.readerPreparing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView(errorTitle, systemImage: "lock.shield", description: Text(errorMessage))
        } else if let url = readerURL, readerFileType == "epub" {
            EPUBReaderView(sourceURL: url, progressPercent: $epubProgressPercent, position: $epubPosition,
                initialPosition: initialPosition, onPositionChange: recordPosition, onFlush: {
                    if let bookID { await container.readerProgressSync.flush(bookID: bookID) }
                }, onCaptureFailure: {
                    if let bookID { container.readerProgressSync.captureFailed(bookID: bookID) }
                })
        } else if let url = readerURL {
            VStack(spacing: 0) {
                PDFReader(
                    url: url,
                    progress: $progress,
                    requestedPage: $requestedPage,
                    layout: pdfLayout,
                    initialPage: initialPosition?.page ?? 1,
                    onPageChange: { value in
                        recordPosition(ReaderPositionDTO(positionType: "pdf", positionValue: String(value.currentPage), progressPercent: value.percent))
                    }
                )
                Divider()
                PDFReaderControls(
                    progress: progress,
                    layout: $pdfLayout,
                    onRequestPage: { requestedPage = $0 }
                )
            }
        } else {
            ContentUnavailableView(L10n.readerUnavailable, systemImage: "lock.shield", description: Text(L10n.readerSecureLinkMissing))
        }
    }

    private var isCurrentPageBookmarked: Bool {
        guard readerFileType != "epub" else { return false }
        return bookmarks.contains { $0.page == progress.currentPage }
    }

    private var displayedProgressPercent: Double {
        readerFileType == "epub" ? epubProgressPercent : progress.percent
    }

    private func toggleCurrentBookmark() {
        guard let bookID else { return }
        container.readerBookmarks.toggle(bookID: bookID, page: progress.currentPage)
        refreshBookmarks()
    }

    private func removeBookmarks(at offsets: IndexSet) {
        guard let bookID else { return }
        let pages = offsets.compactMap { bookmarks.indices.contains($0) ? bookmarks[$0].page : nil }
        for page in pages {
            container.readerBookmarks.remove(bookID: bookID, page: page)
        }
        refreshBookmarks()
    }

    private func refreshBookmarks() {
        guard let bookID else { return }
        bookmarks = container.readerBookmarks.bookmarks(for: bookID)
    }

    private var syncState: ReaderProgressSyncState {
        guard let bookID else { return .idle }
        return container.readerSyncStates[bookID] ?? .idle
    }

    private func recordPosition(_ position: ReaderPositionDTO) {
        guard let bookID else { return }
        container.readerProgressSync.record(bookID: bookID, position: position)
    }

    private func flushProgress() {
        guard let bookID else { return }
        Task { await container.readerProgressSync.flush(bookID: bookID) }
    }

    private func scheduleShelfPromotion() {
        guard !hasScheduledShelfPromotion, case .signedIn(let session) = container.authState else { return }
        hasScheduledShelfPromotion = true
        let username = session.username
        let write = container.readerWrites.enqueue {
            await promoteReadingShelfIfNeeded(username: username)
        }
        // Refresh may flush pending progress through readerWrites; never await it inside that queue.
        Task {
            await write.value
            guard case .signedIn(let current) = container.authState, current.username == username else { return }
            await container.refreshLibrary()
        }
    }

    private func promoteReadingShelfIfNeeded(username: String) async {
        guard case .signedIn(let session) = container.authState, session.username == username, let bookID else { return }
        let libraryItem = container.libraryItems.first(where: { $0.bookId == book.id })
        let normalizedShelf = libraryItem?.normalizedShelfState ?? ""
        guard normalizedShelf.isEmpty || normalizedShelf == "NONE" else { return }
        let progress = libraryItem?.readingProgressForShelfUpdate ?? (percent: 0, page: 0)
        try? await container.books.updateLibraryItem(
            bookID: bookID,
            shelfState: "OKUYORUM",
            progressPercent: progress.percent,
            lastReadPage: progress.page
        )
    }

    private func loadReaderSession() async {
        guard let bookID else {
            errorTitle = L10n.readerUnavailable
            errorMessage = L10n.readerInvalidBookId
            isLoading = false
            return
        }

        isLoading = true
        let generation = UUID()
        loadGeneration = generation
        errorTitle = L10n.readerUnavailable
        errorMessage = nil
        defer { if loadGeneration == generation { isLoading = false } }
        do {
            let access = try await container.books.readerAccess(bookID: bookID)
            guard !Task.isCancelled, loadGeneration == generation else { return }
            guard access.canReadOnline else {
                errorTitle = readerDenialTitle(from: access)
                errorMessage = readerDenialMessage(from: access)
                return
            }

            // The server creates/counts the read session atomically. This must happen even
            // when an offline copy exists so daily read limits cannot be bypassed.
            let session = try await container.books.createReaderSession(bookID: bookID, purpose: .read)
            guard !Task.isCancelled, loadGeneration == generation else { return }
            let fileType = DownloadFilePolicy.resolvedFileExtension(for: session.fileType)
            initialPosition = try await container.prepareReaderProgress(book: book)
            guard !Task.isCancelled, loadGeneration == generation else { return }

            if let localFile = container.downloadManager.localFile(for: book.id) {
                try validateInitialPosition(fileType: localFile.fileType)
                readerFileType = localFile.fileType
                readerURL = localFile.url
                scheduleShelfPromotion()
                return
            }
            guard let url = ReaderSourcePolicy.nativeContentURL(
                session: session,
                bookID: bookID,
                apiBaseURL: container.config.apiBaseURL
            ) else {
                errorMessage = L10n.readerAtsLinkMissing
                return
            }
            let localURL = try await container.readerContentLoader.prepare(
                bookID: book.id,
                sourceURL: url,
                fileType: fileType
            )
            guard !Task.isCancelled, loadGeneration == generation else {
                container.readerContentLoader.removePreparedFile(at: localURL)
                return
            }
            let resolvedType = DownloadFilePolicy.sniffedFileExtension(at: localURL) ?? fileType
            do { try validateInitialPosition(fileType: resolvedType) }
            catch { container.readerContentLoader.removePreparedFile(at: localURL); throw error }
            readerFileType = resolvedType
            temporaryReaderURL = localURL
            readerURL = localURL
            scheduleShelfPromotion()
        } catch let transferError as BookFileTransferError {
            guard !Task.isCancelled, loadGeneration == generation else { return }
            errorMessage = transferError.readerMessage
        } catch {
            guard !Task.isCancelled, loadGeneration == generation else { return }
            errorMessage = (error as? APIClientError)?.serverMessage ?? L10n.readerSessionFailed
        }
    }

    private func validateInitialPosition(fileType: String) throws {
        if let initialPosition, !initialPosition.isValid || initialPosition.positionType != fileType {
            throw EPUBPositionError.invalidCFI
        }
    }

    private func readerDenialTitle(from access: ReaderAccessDTO) -> String {
        let code = access.denialCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        if code == "DAILY_READ_LIMIT" {
            return L10n.quotaReadTitle
        }
        if let quota = access.dailyRead, !quota.isAllowed, quota.limit > 0 {
            return L10n.quotaReadTitle
        }
        switch code {
        case "PREMIUM_REQUIRED", "SUBSCRIPTION_REQUIRED", "PREMIUM_ONLY":
            return L10n.premiumTitle
        default:
            return L10n.readerAccessDenied
        }
    }

    private func readerDenialMessage(from access: ReaderAccessDTO) -> String {
        if let message = access.denialMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            return message
        }
        if let quota = access.dailyRead, !quota.isAllowed, quota.limit > 0 {
            return L10n.quotaReadSubtitle(used: quota.used, limit: quota.limit)
        }
        return L10n.readerSessionFailed
    }


}

private extension ReaderProgressSyncState {
    var label: String {
        switch self {
        case .idle: L10n.readerSyncReady
        case .syncing: L10n.readerSyncSaving
        case .synced: L10n.readerSyncSaved
        case .failed: L10n.readerSyncPending
        }
    }

    var color: Color {
        switch self {
        case .failed: EKitapligimPalette.amber
        case .syncing: EKitapligimPalette.teal
        default: EKitapligimPalette.success
        }
    }
}

@MainActor
private struct ReaderToolbar: View {
    let title: String
    let progressPercent: Double
    let detail: String
    let author: String
    let isBookmarked: Bool
    let bookmarkCount: Int
    let supportsBookmarks: Bool
    let syncState: ReaderProgressSyncState
    let onToggleBookmark: () -> Void
    let onShowBookmarks: () -> Void
    let onShowPages: () -> Void
    let onShowSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(author.isEmpty ? L10n.menuBrandTitle : author)
                            .lineLimit(1)
                        Text("•")
                        Text(detail)
                            .font(.caption.monospacedDigit())
                    }
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle()
                        .stroke(EKitapligimPalette.tealSoft, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(max(progressPercent / 100, 0), 1))
                        .stroke(EKitapligimPalette.teal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("%\(Int(progressPercent.rounded()))")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(EKitapligimPalette.tealDark)
                }
                .frame(width: 42, height: 42)
            }
            HStack(spacing: 8) {
                Image(systemName: syncState == .syncing ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill")
                    .symbolEffect(.pulse, options: .repeating, isActive: syncState == .syncing)
                Text(syncState.label)
                Spacer()
                Text(L10n.commonPercent(Int(progressPercent)))
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(syncState.color)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if supportsBookmarks {
                        ReaderActionButton(
                            title: isBookmarked ? L10n.readerRemoveBookmark : L10n.readerAddBookmark,
                            systemImage: isBookmarked ? "bookmark.fill" : "bookmark",
                            action: onToggleBookmark
                        )
                        ReaderActionButton(
                            title: bookmarkCount > 0 ? "\(L10n.readerBookmarks) (\(bookmarkCount))" : L10n.readerBookmarks,
                            systemImage: "list.bullet"
                        ) {
                            onShowBookmarks()
                        }
                    }
                    if supportsBookmarks {
                        ReaderActionButton(title: L10n.readerPages, systemImage: "square.grid.2x2") {
                            onShowPages()
                        }
                    }
                    ReaderActionButton(title: L10n.readerSettings, systemImage: "slider.horizontal.3") {
                        onShowSettings()
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

@MainActor
private struct ReaderActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(EKitapligimPalette.surfaceAlt, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

enum PDFReadingLayout: Hashable {
    case continuous
    case paged
}

private struct PDFReaderControls: View {
    let progress: ReadingProgress
    @Binding var layout: PDFReadingLayout
    let onRequestPage: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button {
                    onRequestPage(max(1, progress.currentPage - 1))
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(progress.currentPage <= 1)
                .accessibilityLabel(L10n.readerPreviousPage)

                Slider(
                    value: Binding(
                        get: { Double(progress.currentPage) },
                        set: { onRequestPage(Int($0.rounded())) }
                    ),
                    in: 1...Double(max(1, progress.totalPages)),
                    step: 1
                )
                .tint(EKitapligimPalette.teal)
                .accessibilityLabel(L10n.readerPageSlider)
                .accessibilityValue(L10n.readerPage(progress.currentPage, progress.totalPages))

                Button {
                    onRequestPage(min(progress.totalPages, progress.currentPage + 1))
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(progress.currentPage >= progress.totalPages)
                .accessibilityLabel(L10n.readerNextPage)
            }

            HStack {
                Text(L10n.readerPage(progress.currentPage, progress.totalPages))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.muted)
                Spacer()
                Menu {
                    Button {
                        layout = .continuous
                    } label: {
                        Label(L10n.readerContinuousLayout, systemImage: "arrow.down.doc")
                    }
                    Button {
                        layout = .paged
                    } label: {
                        Label(L10n.readerPagedLayout, systemImage: "rectangle.portrait.on.rectangle.portrait")
                    }
                } label: {
                    Label(L10n.readerLayout, systemImage: layout == .continuous ? "arrow.down.doc" : "rectangle.portrait.on.rectangle.portrait")
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

@MainActor
private struct ReaderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var layout: PDFReadingLayout
    let fileType: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.readerLayout, selection: $layout) {
                        Text(L10n.readerContinuousLayout).tag(PDFReadingLayout.continuous)
                        Text(L10n.readerPagedLayout).tag(PDFReadingLayout.paged)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Label(L10n.readerSettingsAppearance, systemImage: "rectangle.3.group")
                } footer: {
                    Text(fileType == "epub" ? L10n.readerSettingsEPUBNote : L10n.readerSettingsPDFNote)
                }
                Section {
                    LabeledContent(L10n.readerSettingsFormat, value: fileType.uppercased())
                    LabeledContent(L10n.readerSettingsSecureConnection, value: L10n.readerSettingsActive)
                } header: {
                    Label(L10n.readerSettingsBookInfo, systemImage: "info.circle")
                }
            }
            .scrollContentBackground(.hidden)
            .background(EKitapligimPalette.pageGradient)
            .navigationTitle(L10n.readerSettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
        }
    }
}

@MainActor
private struct PDFPagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PDFPagePickerModel()
    let url: URL
    let selectedPage: Int
    let onSelect: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if let pageCount = model.pageCount, let service = model.service {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(0..<pageCount, id: \.self) { index in
                                    Button {
                                        onSelect(index + 1)
                                    } label: {
                                        VStack(spacing: 6) {
                                            PDFThumbnailCell(service: service, index: index)
                                            Text(L10n.readerPageNumber(index + 1))
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(index + 1 == selectedPage ? Color.accentColor : Color.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .id(index + 1)
                                }
                            }
                            .padding()
                        }
                        .onAppear { proxy.scrollTo(selectedPage, anchor: .center) }
                    }
                } else if model.failed {
                    ContentUnavailableView(L10n.readerUnavailable, systemImage: "doc.questionmark")
                } else {
                    ProgressView(L10n.readerPreparing)
                }
            }
            .task(id: url) { await model.load(url: url) }
            .onDisappear { model.cancel() }
            .navigationTitle(L10n.readerPages)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
        }
    }
}

private struct PDFThumbnailCell: View {
    let service: any PDFThumbnailProviding
    let index: Int
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        .accessibilityHidden(true)
        .task(id: index) {
            let result = try? await service.thumbnail(at: index)
            guard !Task.isCancelled else { return }
            image = result
        }
        .onDisappear { image = nil }
    }
}

@MainActor
private struct ReaderBookmarksView: View {
    @Environment(\.dismiss) private var dismiss
    let bookmarks: [ReaderBookmark]
    let onSelect: (ReaderBookmark) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        L10n.readerBookmarksEmpty,
                        systemImage: "bookmark",
                        description: Text(L10n.readerBookmarksEmptyDescription)
                    )
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            Button {
                                onSelect(bookmark)
                            } label: {
                                Label(L10n.readerPageNumber(bookmark.page), systemImage: "bookmark.fill")
                            }
                        }
                        .onDelete(perform: onDelete)
                    }
                }
            }
            .navigationTitle(L10n.readerBookmarks)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
        }
    }
}

@MainActor
struct PDFReader: UIViewRepresentable {
    let url: URL
    @Binding var progress: ReadingProgress
    @Binding var requestedPage: Int?
    let layout: PDFReadingLayout
    var initialPage: Int = 1
    var onPageChange: (ReadingProgress) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress, requestedPage: $requestedPage, initialPage: initialPage, onPageChange: onPageChange)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = ResumePDFView()
        context.coordinator.configure(view, url: url, layout: layout)
        context.coordinator.observe(view)
        context.coordinator.updateProgress(from: view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.configure(uiView, url: url, layout: layout)
        guard context.coordinator.isRestored, let requestedPage,
              let document = uiView.document,
              let page = document.page(at: min(max(requestedPage, 1), document.pageCount) - 1) else { return }
        if uiView.currentPage !== page { uiView.go(to: page) }
        context.coordinator.clearRequestedPage(expected: requestedPage)
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject {
        private var loadedURL: URL?
        private var appliedLayout: PDFReadingLayout?
        private var progress: Binding<ReadingProgress>
        private var requestedPage: Binding<Int?>
        private weak var view: PDFView?
        private var pageObserver: NSObjectProtocol?
        private(set) var isRestored = false
        private let initialPage: Int
        private let onPageChange: (ReadingProgress) -> Void
        private var lastPage: Int?
        private var restorationGeneration = UUID()
        private var restorationScheduled = false

        init(progress: Binding<ReadingProgress>, requestedPage: Binding<Int?>, initialPage: Int = 1, onPageChange: @escaping (ReadingProgress) -> Void = { _ in }) {
            self.progress = progress
            self.requestedPage = requestedPage
            self.initialPage = initialPage
            self.onPageChange = onPageChange
        }

        func configure(
            _ view: PDFView, url: URL, layout: PDFReadingLayout,
            makeDocument: (URL) -> PDFDocument? = { PDFDocument(url: $0) }
        ) {
            if let resumeView = view as? ResumePDFView {
                resumeView.onLayoutReady = { [weak self, weak view] in
                    guard let view else { return }
                    self?.restore(view)
                }
            }
            if appliedLayout != layout {
                switch layout {
                case .continuous:
                    view.displayMode = .singlePageContinuous
                    view.displayDirection = .vertical
                case .paged:
                    view.displayMode = .singlePage
                    view.displayDirection = .horizontal
                }
                view.displaysPageBreaks = true
                view.autoScales = true
                appliedLayout = layout
            }
            if loadedURL != url {
                isRestored = false
                restorationGeneration = UUID()
                restorationScheduled = false
                lastPage = nil
                view.document = makeDocument(url)
                loadedURL = url
            }
            restore(view)
        }

        private func restore(_ view: PDFView) {
            // SwiftUI creates this view before it has a window or usable bounds. A main-queue
            // delay alone does not mean PDFKit has laid out its scroll view yet.
            guard !isRestored, !restorationScheduled, view.window != nil,
                  view.bounds.width > 0, view.bounds.height > 0,
                  let document = view.document, document.pageCount > 0 else { return }
            let target = min(max(initialPage, 1), document.pageCount)
            let generation = restorationGeneration
            restorationScheduled = true
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view, self.restorationGeneration == generation,
                      view.document === document else { return }
                guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else {
                    self.restorationScheduled = false
                    return
                }
                view.layoutIfNeeded()
                if let page = document.page(at: target - 1) { view.go(to: page) }
                // Verify PDFKit's actual page after navigation/layout, not the requested number.
                // Initial page-change notifications remain suppressed until this succeeds.
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view, self.restorationGeneration == generation,
                          view.document === document else { return }
                    view.layoutIfNeeded()
                    self.restorationScheduled = false
                    guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0,
                          let currentPage = view.currentPage,
                          document.index(for: currentPage) == target - 1 else { return }
                    self.lastPage = target
                    self.isRestored = true
                    self.progress.wrappedValue = ReadingProgress(currentPage: target, totalPages: document.pageCount)
                }
            }
        }

        func observe(_ view: PDFView) {
            self.view = view
            pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: view,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let view = self.view else { return }
                    self.updateProgress(from: view)
                }
            }
        }

        func updateProgress(from view: PDFView) {
            guard isRestored, let document = view.document, document.pageCount > 0,
                  let currentPage = view.currentPage else { return }
            let pageIndex = document.index(for: currentPage)
            guard pageIndex >= 0, pageIndex < document.pageCount else { return }
            let next = ReadingProgress(currentPage: pageIndex + 1, totalPages: document.pageCount)
            if lastPage != next.currentPage {
                lastPage = next.currentPage
                onPageChange(next)
            }
            if progress.wrappedValue != next { progress.wrappedValue = next }
        }

        func clearRequestedPage(expected: Int) {
            DispatchQueue.main.async { [weak self] in
                guard self?.requestedPage.wrappedValue == expected else { return }
                self?.requestedPage.wrappedValue = nil
            }
        }

        func stopObserving() {
            restorationGeneration = UUID()
            restorationScheduled = false
            (view as? ResumePDFView)?.onLayoutReady = nil
            if let pageObserver {
                NotificationCenter.default.removeObserver(pageObserver)
            }
            pageObserver = nil
        }
    }
}

/// Exposes UIKit attachment/layout events without persisting any reading state in the view.
@MainActor
final class ResumePDFView: PDFView {
    var onLayoutReady: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if window != nil, bounds.width > 0, bounds.height > 0 { onLayoutReady?() }
    }
}

@MainActor
struct ReaderLoaderView: View {
    @EnvironmentObject private var container: AppContainer
    let bookID: Int

    @State private var book: BookDTO?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                EKLoadingState(message: L10n.bookDetailLoading)
            } else if let book {
                ReaderView(book: book)
            } else {
                EKErrorState(title: L10n.bookDetailOpenFailed, message: errorMessage ?? L10n.bookDetailLoadFailed) {
                    Task { await load() }
                }
            }
        }
        .task(id: bookID) { await load() }
        .preference(key: AILauncherHiddenKey.self, value: true)
    }

    private func load() async {
        guard bookID > 0 else {
            isLoading = false
            errorMessage = L10n.bookDetailInvalidId
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            book = try await container.books.book(id: bookID)
        } catch {
            book = nil
            errorMessage = L10n.bookDetailLoadFailed
        }
    }
}
