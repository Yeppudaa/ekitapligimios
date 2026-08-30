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
    @State private var pdfLayout: PDFReadingLayout = .continuous
    @State private var bookmarks: [ReaderBookmark] = []

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
        .task {
            refreshBookmarks()
            await loadReaderSession()
        }
        .onDisappear {
            saveProgress()
            container.readerContentLoader.removePreparedFile(at: temporaryReaderURL)
            temporaryReaderURL = nil
        }
    }

    @ViewBuilder
    private var readerToolbar: some View {
        ReaderToolbar(
            title: book.title,
            progressPercent: displayedProgressPercent,
            detail: readerFileType == "epub" ? L10n.readerEPUBFormat : L10n.readerPage(progress.currentPage, progress.totalPages),
            isBookmarked: isCurrentPageBookmarked,
            bookmarkCount: bookmarks.count,
            supportsBookmarks: readerFileType != "epub",
            onToggleBookmark: toggleCurrentBookmark,
            onShowBookmarks: { showsBookmarks = true },
            onShowPages: { showsPagePicker = true }
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
            EPUBReaderView(sourceURL: url, progressPercent: $epubProgressPercent, position: $epubPosition)
        } else if let url = readerURL {
            VStack(spacing: 0) {
                PDFReader(
                    url: url,
                    progress: $progress,
                    requestedPage: $requestedPage,
                    layout: pdfLayout
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

    private func saveProgress() {
        guard let bookID, readerURL != nil else { return }
        let latestPage = readerFileType == "epub" ? epubPosition : progress.currentPage
        let latestPercent = displayedProgressPercent
        let percentInt = Int(latestPercent.rounded())
        Task {
            if (try? await container.books.updateProgress(
                bookID: bookID,
                page: latestPage,
                percent: latestPercent
            )) != nil {
                container.patchLibraryItem(book.id) { item in
                    item.updating(progressPercent: percentInt, lastReadPage: latestPage)
                }
            }
        }
    }

    private func promoteReadingShelfIfNeeded() async {
        guard case .signedIn = container.authState, let bookID else { return }
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
        await container.refreshLibrary()
    }

    private func loadReaderSession() async {
        guard let bookID else {
            errorTitle = L10n.readerUnavailable
            errorMessage = L10n.readerInvalidBookId
            isLoading = false
            return
        }

        isLoading = true
        errorTitle = L10n.readerUnavailable
        errorMessage = nil
        defer { isLoading = false }
        do {
            let access = try await container.books.readerAccess(bookID: bookID)
            guard access.canReadOnline else {
                errorTitle = readerDenialTitle(from: access)
                errorMessage = readerDenialMessage(from: access)
                return
            }

            // The server creates/counts the read session atomically. This must happen even
            // when an offline copy exists so daily read limits cannot be bypassed.
            let session = try await container.books.createReaderSession(bookID: bookID, purpose: .read)
            let fileType = DownloadFilePolicy.resolvedFileExtension(for: session.fileType)

            if let localFile = container.downloadManager.localFile(for: book.id) {
                readerFileType = localFile.fileType
                readerURL = localFile.url
                restorePDFPositionIfAvailable(fileType: localFile.fileType)
                await promoteReadingShelfIfNeeded()
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
            let resolvedType = DownloadFilePolicy.sniffedFileExtension(at: localURL) ?? fileType
            readerFileType = resolvedType
            temporaryReaderURL = localURL
            readerURL = localURL
            restorePDFPositionIfAvailable(fileType: resolvedType)
            await promoteReadingShelfIfNeeded()
        } catch let transferError as BookFileTransferError {
            errorMessage = transferError.readerMessage
        } catch {
            errorMessage = (error as? APIClientError)?.serverMessage ?? L10n.readerSessionFailed
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

    private func restorePDFPositionIfAvailable(fileType: String) {
        guard fileType == "pdf",
              let lastPage = container.libraryItems.first(where: { $0.bookId == book.id })?.lastReadPage,
              lastPage > 1 else { return }
        requestedPage = lastPage
    }
}

@MainActor
private struct ReaderToolbar: View {
    let title: String
    let progressPercent: Double
    let detail: String
    let isBookmarked: Bool
    let bookmarkCount: Int
    let supportsBookmarks: Bool
    let onToggleBookmark: () -> Void
    let onShowBookmarks: () -> Void
    let onShowPages: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(L10n.commonPercent(Int(progressPercent)))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            if supportsBookmarks {
                Button(action: onShowPages) {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel(L10n.readerPages)
                Button(action: onToggleBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isBookmarked ? L10n.readerRemoveBookmark : L10n.readerAddBookmark)
                Button(action: onShowBookmarks) {
                    Image(systemName: "list.bullet")
                        .overlay(alignment: .topTrailing) {
                            if bookmarkCount > 0 {
                                Text("\(bookmarkCount)")
                                    .font(.caption2.monospacedDigit())
                                    .padding(2)
                                    .background(.tint, in: Circle())
                                    .foregroundStyle(.white)
                                    .offset(x: 7, y: -7)
                            }
                        }
                }
                .accessibilityLabel(L10n.readerBookmarks)
            }
        }
        .padding()
    }
}

private enum PDFReadingLayout {
    case continuous
    case paged
}

private struct PDFReaderControls: View {
    let progress: ReadingProgress
    @Binding var layout: PDFReadingLayout
    let onRequestPage: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
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
            .accessibilityLabel(L10n.readerPageSlider)
            .accessibilityValue(L10n.readerPage(progress.currentPage, progress.totalPages))

            Button {
                onRequestPage(min(progress.totalPages, progress.currentPage + 1))
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(progress.currentPage >= progress.totalPages)
            .accessibilityLabel(L10n.readerNextPage)

            Menu {
                Button(L10n.readerContinuousLayout) { layout = .continuous }
                Button(L10n.readerPagedLayout) { layout = .paged }
            } label: {
                Image(systemName: layout == .continuous ? "arrow.down.doc" : "rectangle.portrait.on.rectangle.portrait")
            }
            .accessibilityLabel(L10n.readerLayout)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(.bar)
    }
}

@MainActor
private struct PDFPagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    let selectedPage: Int
    let onSelect: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if let document = PDFDocument(url: url) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(0..<document.pageCount, id: \.self) { index in
                                    Button {
                                        onSelect(index + 1)
                                    } label: {
                                        VStack(spacing: 6) {
                                            if let page = document.page(at: index) {
                                                Image(uiImage: page.thumbnail(of: CGSize(width: 160, height: 220), for: .cropBox))
                                                    .resizable()
                                                    .scaledToFit()
                                                    .background(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                                    .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                                            }
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
                } else {
                    ContentUnavailableView(L10n.readerUnavailable, systemImage: "doc.questionmark")
                }
            }
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

private struct PDFReader: UIViewRepresentable {
    let url: URL
    @Binding var progress: ReadingProgress
    @Binding var requestedPage: Int?
    let layout: PDFReadingLayout

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress, requestedPage: $requestedPage)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        applyLayout(to: view)
        view.document = PDFDocument(url: url)
        context.coordinator.observe(view)
        context.coordinator.updateProgress(from: view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        applyLayout(to: uiView)
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
            context.coordinator.updateProgress(from: uiView)
        }
        guard let requestedPage,
              let document = uiView.document,
              let page = document.page(at: requestedPage - 1) else { return }
        uiView.go(to: page)
        context.coordinator.clearRequestedPage()
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    private func applyLayout(to view: PDFView) {
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
    }

    final class Coordinator: NSObject {
        private var progress: Binding<ReadingProgress>
        private var requestedPage: Binding<Int?>
        private weak var view: PDFView?
        private var pageObserver: NSObjectProtocol?

        init(progress: Binding<ReadingProgress>, requestedPage: Binding<Int?>) {
            self.progress = progress
            self.requestedPage = requestedPage
        }

        func observe(_ view: PDFView) {
            self.view = view
            pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: view,
                queue: .main
            ) { [weak self] _ in
                guard let self, let view = self.view else { return }
                self.updateProgress(from: view)
            }
        }

        func updateProgress(from view: PDFView) {
            guard let document = view.document, document.pageCount > 0 else { return }
            let pageIndex = view.currentPage.map(document.index(for:)) ?? 0
            progress.wrappedValue = ReadingProgress(currentPage: pageIndex + 1, totalPages: document.pageCount)
        }

        func clearRequestedPage() {
            DispatchQueue.main.async { [weak self] in
                self?.requestedPage.wrappedValue = nil
            }
        }

        func stopObserving() {
            if let pageObserver {
                NotificationCenter.default.removeObserver(pageObserver)
            }
            pageObserver = nil
        }
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
