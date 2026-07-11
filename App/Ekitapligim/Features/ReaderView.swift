import SwiftUI
import PDFKit
import UIKit
import EkitapligimCore

@MainActor
struct ReaderView: View {
    @EnvironmentObject private var container: AppContainer
    let book: BookDTO

    @State private var progress: ReadingProgress
    @State private var readerURL: URL?
    @State private var readerFileType = "pdf"
    @State private var epubProgressPercent: Double = 0
    @State private var epubPosition = 1
    @State private var requestedPage: Int?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showsBookmarks = false
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
        .task {
            refreshBookmarks()
            await loadReaderSession()
        }
        .onDisappear { saveProgress() }
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
            onShowBookmarks: { showsBookmarks = true }
        )
    }

    @ViewBuilder
    private var readerContent: some View {
        if isLoading {
            ProgressView(L10n.readerPreparing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView(L10n.readerUnavailable, systemImage: "lock.shield", description: Text(errorMessage))
        } else if let url = readerURL, readerFileType == "epub" {
            EPUBReaderView(sourceURL: url, progressPercent: $epubProgressPercent, position: $epubPosition)
        } else if let url = readerURL {
            PDFReader(url: url, progress: $progress, requestedPage: $requestedPage)
        } else {
            ContentUnavailableView(L10n.readerUnavailable, systemImage: "lock.shield", description: Text(L10n.readerSecureLinkMissing))
        }
    }

    private var isCurrentPageBookmarked: Bool {
        guard readerFileType != "epub" else { return false }
        bookmarks.contains { $0.page == progress.currentPage }
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
        guard let bookID else { return }
        let latestPage = readerFileType == "epub" ? epubPosition : progress.currentPage
        let latestPercent = displayedProgressPercent
        Task {
            try? await container.books.updateProgress(
                bookID: bookID,
                page: latestPage,
                percent: latestPercent
            )
        }
    }

    private func loadReaderSession() async {
        guard let bookID else {
            errorMessage = L10n.readerInvalidBookId
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }
        if let localFile = container.downloadManager.localFile(for: book.id) {
            readerFileType = localFile.fileType
            readerURL = localFile.url
            return
        }
        do {
            let session = try await container.books.createReaderSession(bookID: bookID, purpose: .read)
            guard let url = URL(string: session.sourceUrl), url.scheme == "https" else {
                errorMessage = L10n.readerAtsLinkMissing
                return
            }
            guard let fileType = try? DownloadFilePolicy.fileExtension(for: session.fileType) else {
                errorMessage = L10n.readerUnsupportedFormat
                return
            }
            readerFileType = fileType
            readerURL = url
        } catch {
            errorMessage = L10n.readerSessionFailed
        }
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
private struct PDFReader: UIViewRepresentable {
    let url: URL
    @Binding var progress: ReadingProgress
    @Binding var requestedPage: Int?

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress, requestedPage: $requestedPage)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        context.coordinator.observe(view)
        context.coordinator.updateProgress(from: view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
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

    @MainActor
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
