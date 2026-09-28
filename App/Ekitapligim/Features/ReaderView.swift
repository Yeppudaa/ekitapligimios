import SwiftUI
@preconcurrency import PDFKit
@preconcurrency import UIKit
import EkitapligimCore

@MainActor
struct ReaderView: View {
    @EnvironmentObject private var container: AppContainer
    let book: BookDTO
    var onPremium: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reader.paperTheme") private var paperThemeRaw = ReaderPaperTheme.sepia.rawValue
    @State private var showsControls = false
    @State private var loadingPhase: ReaderLoadingPhase = .authorizing
    @State private var reloadID = UUID()
    @State private var canRetryLoad = false

    @State private var progress: ReadingProgress
    @State private var readerURL: URL?
    @State private var preparedPDF: PreparedPDFDocument?
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
    @State private var showsPremiumActionForError = false
    @State private var showsPreviewLimitDialog = false
    @State private var previewPresentation = ReaderPreviewPresentation()
    @State private var pendingPremiumAfterLimitDismiss = false

    init(book: BookDTO, onPremium: (() -> Void)? = nil) {
        self.book = book
        self.onPremium = onPremium
        _progress = State(initialValue: ReadingProgress(currentPage: 1, totalPages: book.pageCount))
    }

    private var bookID: Int? { Int(book.id) }
    private var paperTheme: ReaderPaperTheme { ReaderPaperTheme(rawValue: paperThemeRaw) ?? .sepia }

    private var isPreviewMode: Bool { !container.isPremium }

    private var currentPreviewLimit: ReaderPreviewLimit {
        makePreviewLimit(page: activeReaderPage, totalPages: progress.totalPages)
    }

    private var accessiblePageLimit: Int { currentPreviewLimit.accessiblePageLimit }

    private var hasLockedContent: Bool { currentPreviewLimit.hasLockedContent }

    private var previewFinished: Bool { currentPreviewLimit.isOnLimitPage }

    private var activeReaderPage: Int {
        readerFileType == "epub" ? epubPosition : progress.currentPage
    }

    var body: some View {
        ZStack {
            paperTheme.paper.ignoresSafeArea()
            readerContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsControls {
                VStack {
                    readerToolbar
                    Spacer(minLength: 0)
                    if readerURL != nil, !isLoading, errorMessage == nil {
                        if readerFileType == "pdf" {
                            ReaderPageControls(progress: progress, accessiblePageLimit: accessiblePageLimit,
                                hasLockedContent: hasLockedContent, detail: readerToolbarDetail,
                                syncLabel: syncState.label, syncFailed: syncState == .failed,
                                theme: paperTheme, onRequestPage: requestPage)
                        } else {
                            ReaderEPUBProgress(percent: epubProgressPercent, detail: readerToolbarDetail,
                                syncLabel: syncState.label, syncFailed: syncState == .failed, theme: paperTheme)
                        }
                    }
                }
            } else {
                VStack {
                    HStack {
                        ReaderIconButton(icon: "chevron.left", label: L10n.commonClose, theme: paperTheme) { dismiss() }
                            .background(paperTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityIdentifier("reader.close")
                        Spacer()
                        ReaderIconButton(icon: "slider.horizontal.3", label: ReaderL10n.text("showControls"), theme: paperTheme) { toggleControls() }
                            .background(paperTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityIdentifier("reader.showControls")
                    }.padding(.horizontal, 12).padding(.top, 6)
                    Spacer()
                    if readerURL != nil, !isLoading, errorMessage == nil {
                        Text(readerToolbarDetail)
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundStyle(paperTheme.ink.opacity(0.65))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(paperTheme.paper.opacity(0.92), in: Capsule())
                            .padding(.bottom, 6)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("reader.focusProgress")
                    }
                }
            }
        }
        .background(paperTheme.paper)
        .preferredColorScheme(paperTheme.colorScheme)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(!showsControls)
        .persistentSystemOverlays(showsControls ? .automatic : .hidden)
        .accessibilityIdentifier("reader.fullscreen")
        .sheet(isPresented: $showsBookmarks) {
            ReaderBookmarksView(
                bookmarks: bookmarks,
                onSelect: { bookmark in
                    requestPage(bookmark.page)
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
                    maxSelectablePage: hasLockedContent ? accessiblePageLimit : nil,
                    onSelect: { page in
                        requestPage(page)
                        showsPagePicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showsReaderSettings) {
            ReaderSettingsView(layout: $pdfLayout, paperTheme: $paperThemeRaw, fileType: readerFileType)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task(id: reloadID) {
            guard readerURL == nil else { return }
            refreshBookmarks()
            await loadReaderSession()
        }
        .preference(key: AILauncherHiddenKey.self, value: true)
        .onDisappear {
            flushProgress()
            // Sheets can also cover the reader in compact-height layouts. Keep its backing file
            // alive while any reader-owned presentation is open (PDFKit reads pages lazily).
            if !showsPreviewLimitDialog && !showsPagePicker && !showsBookmarks && !showsReaderSettings {
                loadGeneration = UUID()
                scheduleTemporaryFileRemoval()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { flushProgress() }
        }
        .onChange(of: epubPosition) { _, position in
            handleEPUBPositionChange(position)
        }
        .onChange(of: showsPreviewLimitDialog) { _, showing in
            if showing {
                previewPresentation.isLimitVisible = true
                return
            }
            previewPresentation.dismissLimit()
            if pendingPremiumAfterLimitDismiss {
                pendingPremiumAfterLimitDismiss = false
                openPremium()
            }
        }
        .fullScreenCover(isPresented: $showsPreviewLimitDialog) {
            ReaderPreviewLimitOverlay(
                pageCount: accessiblePageLimit,
                onUpgrade: requestPremiumPresentation,
                onDismiss: {
                    showsPreviewLimitDialog = false
                }
            )
        }
    }

    @ViewBuilder
    private var readerToolbar: some View {
        ReaderChrome(
            title: book.title, detail: readerFileType.uppercased() + " · " + readerToolbarDetail, theme: paperTheme,
            isBookmarked: isCurrentPageBookmarked,
            supportsPDF: readerFileType == "pdf", enabled: readerURL != nil && !isLoading && errorMessage == nil,
            close: { dismiss() }, focus: toggleControls, changeTheme: cyclePaperTheme,
            bookmark: toggleCurrentBookmark, bookmarks: { showsBookmarks = true },
            pages: { showsPagePicker = true }, settings: { showsReaderSettings = true }
        )
    }

    private func toggleControls() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsControls.toggle() }
    }

    private func cyclePaperTheme() {
        let next: ReaderPaperTheme = paperTheme == .sepia ? .night : (paperTheme == .night ? .white : .sepia)
        paperThemeRaw = next.rawValue
    }

    @ViewBuilder
    private var readerContent: some View {
        if isLoading {
            ReaderLoadingView(title: book.title, author: book.author, phase: loadingPhase, theme: paperTheme)
        } else if let errorMessage {
            ContentUnavailableView {
                Label(errorTitle, systemImage: canRetryLoad ? "doc.badge.arrow.up" : "lock.shield")
            } description: {
                Text(errorMessage)
            } actions: {
                if canRetryLoad {
                    Button(ReaderL10n.text("retry")) { reloadID = UUID() }
                        .buttonStyle(.borderedProminent).tint(paperTheme.accent)
                        .accessibilityIdentifier("reader.retry")
                }
                if showsPremiumActionForError {
                    Button(L10n.quotaPremiumAction) { openPremium() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("reader.quota.premium")
                }
            }
        } else if let url = readerURL, readerFileType == "epub" {
            EPUBReaderView(sourceURL: url, progressPercent: $epubProgressPercent, position: $epubPosition,
                initialPosition: initialPosition, paperTheme: paperTheme, onPositionChange: recordPosition, onFlush: {
                    if let bookID { await container.readerProgressSync.flush(bookID: bookID) }
                }, onCaptureFailure: {
                    if let bookID { container.readerProgressSync.captureFailed(bookID: bookID) }
                }, onRestored: {
                    previewPresentation.markRestored()
                    applyPreviewDecision(makePreviewLimit(page: epubPosition))
                })
        } else if let url = readerURL, let preparedPDF {
                PDFReader(
                    url: url,
                    document: preparedPDF.document,
                    progress: $progress,
                    requestedPage: $requestedPage,
                    layout: pdfLayout,
                    initialPage: clampedInitialPage,
                    maxAccessiblePage: hasLockedContent ? accessiblePageLimit : nil,
                    onPageChange: { value in
                        handlePDFPageChange(value.currentPage, totalPages: value.totalPages)
                        let limit = makePreviewLimit(page: value.currentPage, totalPages: value.totalPages)
                        guard !limit.blocks(value.currentPage) else { return }
                        recordPosition(ReaderPositionDTO(positionType: "pdf", positionValue: String(value.currentPage), progressPercent: value.percent))
                    },
                    onRestored: {
                        previewPresentation.markRestored()
                        applyPreviewDecision(makePreviewLimit(page: progress.currentPage))
                    },
                    onToggleControls: toggleControls
                )
                .modifier(ReaderPDFPaper(theme: paperTheme))
                .ignoresSafeArea(.container)
        } else if readerURL != nil {
            ProgressView(L10n.readerPreparing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(L10n.readerUnavailable, systemImage: "lock.shield", description: Text(L10n.readerSecureLinkMissing))
        }
    }

    private var isCurrentPageBookmarked: Bool {
        guard readerFileType != "epub" else { return false }
        return bookmarks.contains { $0.page == progress.currentPage }
    }

    private var readerToolbarDetail: String {
        if readerFileType == "epub" {
            if isPreviewMode, hasLockedContent {
                return L10n.readerPreviewLimitActive(limit: accessiblePageLimit) + " • " + L10n.readerPage(epubPosition, accessiblePageLimit)
            }
            return L10n.commonPercent(Int(epubProgressPercent))
        }
        if isPreviewMode, hasLockedContent {
            if previewFinished {
                return L10n.readerPage(progress.currentPage, progress.totalPages) + " • " + L10n.readerPreviewLimitContinuePremium
            }
            return L10n.readerPage(progress.currentPage, progress.totalPages) + " • " + ReaderL10n.text("preview")
        }
        return L10n.readerPage(progress.currentPage, progress.totalPages)
    }

    private var clampedInitialPage: Int {
        let requested = initialPosition?.page ?? 1
        return makePreviewLimit(page: requested, totalPages: max(progress.totalPages, book.pageCount)).clamped(requested)
    }

    private func makePreviewLimit(page: Int, totalPages: Int? = nil) -> ReaderPreviewLimit {
        ReaderPreviewLimit(
            isPreviewMode: isPreviewMode,
            currentPage: page,
            documentPageCount: totalPages ?? progress.totalPages,
            catalogPageCount: book.pageCount
        )
    }

    private func handlePDFPageChange(_ page: Int, totalPages: Int? = nil) {
        applyPreviewDecision(makePreviewLimit(page: page, totalPages: totalPages))
    }

    private func handleEPUBPositionChange(_ position: Int) {
        applyPreviewDecision(makePreviewLimit(page: position))
    }

    private func requestPage(_ target: Int) {
        applyPreviewDecision(makePreviewLimit(page: target))
    }

    private func applyPreviewDecision(_ limit: ReaderPreviewLimit) {
        let decision = previewPresentation.handle(limit)
        if decision.page != activeReaderPage || limit.blocks(limit.currentPage) {
            applyReaderPage(decision.page)
        }
        switch decision.event {
        case .none, .clampOnly:
            break
        case .presentLimit:
            ReaderDeferredTeardown.enqueue {
                showsPreviewLimitDialog = true
            }
        case .openPremium:
            requestPremiumPresentation()
        }
    }

    private func applyReaderPage(_ page: Int) {
        if readerFileType == "epub" {
            epubPosition = page
        }
        requestedPage = page
    }

    private func requestPremiumPresentation() {
        if showsPreviewLimitDialog {
            pendingPremiumAfterLimitDismiss = true
            showsPreviewLimitDialog = false
            return
        }
        openPremium()
    }

    private func scheduleTemporaryFileRemoval() {
        let url = temporaryReaderURL
        let loader = container.readerContentLoader
        temporaryReaderURL = nil
        ReaderDeferredTeardown.enqueue {
            loader.removePreparedFile(at: url)
        }
    }

    private func openPremium() {
        if let onPremium { onPremium() }
        else { container.open(route: .premium) }
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
        loadingPhase = .authorizing
        canRetryLoad = false
        let generation = UUID()
        loadGeneration = generation
        errorTitle = L10n.readerUnavailable
        errorMessage = nil
        showsPremiumActionForError = false
        previewPresentation = ReaderPreviewPresentation()
        showsPreviewLimitDialog = false
        pendingPremiumAfterLimitDismiss = false
        preparedPDF = nil
        defer { if loadGeneration == generation { isLoading = false } }
        do {
            let access = try await container.books.readerAccess(bookID: bookID)
            guard !Task.isCancelled, loadGeneration == generation else { return }
            guard access.canReadOnline else {
                errorTitle = readerDenialTitle(from: access)
                errorMessage = readerDenialMessage(from: access)
                showsPremiumActionForError = access.isDailyReadLimitDenied
                return
            }

            // The server creates/counts the read session atomically. This must happen even
            // when an offline copy exists so daily read limits cannot be bypassed.
            let session = try await container.books.createReaderSession(bookID: bookID, purpose: .read)
            guard !Task.isCancelled, loadGeneration == generation else { return }
            let fileType = DownloadFilePolicy.resolvedFileExtension(for: session.fileType)
            loadingPhase = .restoring
            initialPosition = try await container.prepareReaderProgress(book: book)
            guard !Task.isCancelled, loadGeneration == generation else { return }

            if let localFile = container.downloadManager.localFile(for: book.id) {
                try validateInitialPosition(fileType: localFile.fileType)
                let document = try await preparePDFIfNeeded(at: localFile.url, fileType: localFile.fileType)
                guard !Task.isCancelled, loadGeneration == generation else { return }
                readerFileType = localFile.fileType
                preparedPDF = document
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
                canRetryLoad = true
                return
            }
            let localURL = try await container.readerContentLoader.prepare(
                bookID: book.id,
                sourceURL: url,
                fileType: fileType,
                onProgress: { phase in
                    guard loadGeneration == generation, isLoading else { return }
                    loadingPhase = phase
                }
            )
            guard !Task.isCancelled, loadGeneration == generation else {
                container.readerContentLoader.removePreparedFile(at: localURL)
                return
            }
            let resolvedType = DownloadFilePolicy.sniffedFileExtension(at: localURL) ?? fileType
            do { try validateInitialPosition(fileType: resolvedType) }
            catch { container.readerContentLoader.removePreparedFile(at: localURL); throw error }
            let document: PreparedPDFDocument?
            do { document = try await preparePDFIfNeeded(at: localURL, fileType: resolvedType) }
            catch { container.readerContentLoader.removePreparedFile(at: localURL); throw error }
            guard !Task.isCancelled, loadGeneration == generation else {
                container.readerContentLoader.removePreparedFile(at: localURL)
                return
            }
            readerFileType = resolvedType
            preparedPDF = document
            temporaryReaderURL = localURL
            readerURL = localURL
            scheduleShelfPromotion()
        } catch let transferError as BookFileTransferError {
            guard !Task.isCancelled, loadGeneration == generation else { return }
            errorMessage = transferError.readerMessage
            canRetryLoad = true
        } catch {
            guard !Task.isCancelled, loadGeneration == generation else { return }
            errorMessage = (error as? APIClientError)?.serverMessage ?? L10n.readerSessionFailed
            canRetryLoad = true
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut: errorMessage = ReaderL10n.text("error.timeout")
                case .notConnectedToInternet, .networkConnectionLost: errorMessage = ReaderL10n.text("error.connection")
                default: break
                }
            }
        }
    }

    private func validateInitialPosition(fileType: String) throws {
        if let initialPosition, !initialPosition.isValid || initialPosition.positionType != fileType {
            throw EPUBPositionError.invalidCFI
        }
    }

    private func preparePDFIfNeeded(at url: URL, fileType: String) async throws -> PreparedPDFDocument? {
        loadingPhase = .opening
        guard fileType == "pdf" else { return nil }
        return try await PreparedPDFDocument.load(from: url)
    }

    private func readerDenialTitle(from access: ReaderAccessDTO) -> String {
        if access.isDailyReadLimitDenied {
            return L10n.quotaReadTitle
        }
        let code = access.denialCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        switch code {
        case "PREMIUM_REQUIRED", "SUBSCRIPTION_REQUIRED", "PREMIUM_ONLY":
            return L10n.premiumTitle
        default:
            return L10n.readerAccessDenied
        }
    }

    private func readerDenialMessage(from access: ReaderAccessDTO) -> String {
        if access.isDailyReadLimitDenied {
            return L10n.quotaReadLimitReached
        }
        if let message = access.denialMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            return message
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

private struct ReaderPreviewLimitOverlay: View {
    let pageCount: Int
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(EKitapligimPalette.quotaPremiumGradient)
                    .clipShape(Circle())
                Text(L10n.readerPreviewLimitTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .multilineTextAlignment(.center)
                Text(L10n.readerPreviewLimitMessage(pages: pageCount))
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .multilineTextAlignment(.center)
                Button(action: onUpgrade) {
                    Text(L10n.readerPreviewLimitUpgrade)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(EKitapligimPalette.teal)
                .accessibilityIdentifier("reader.previewLimit.premium")
                Button(L10n.readerPreviewLimitDismiss, action: onDismiss)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.muted)
                    .accessibilityIdentifier("reader.previewLimit.dismiss")
            }
            .padding(24)
            .background(EKitapligimPalette.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EKitapligimPalette.page)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.previewLimit.overlay")
    }
}

enum PDFReadingLayout: Hashable {
    case continuous
    case paged
}

@MainActor
private struct ReaderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var layout: PDFReadingLayout
    @Binding var paperTheme: String
    let fileType: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ReaderThemePicker(selection: $paperTheme)
                } header: {
                    Label(ReaderL10n.text("paper"), systemImage: "circle.lefthalf.filled")
                } footer: {
                    Text(ReaderL10n.text("paper.note"))
                }
                if fileType == "pdf" {
                    Section {
                        Picker(L10n.readerLayout, selection: $layout) {
                            Text(L10n.readerContinuousLayout).tag(PDFReadingLayout.continuous)
                            Text(L10n.readerPagedLayout).tag(PDFReadingLayout.paged)
                        }
                        .pickerStyle(.inline)
                    } header: {
                        Label(L10n.readerSettingsAppearance, systemImage: "rectangle.3.group")
                    } footer: {
                        Text(L10n.readerSettingsPDFNote)
                    }
                }
                Section {
                    LabeledContent(L10n.readerSettingsFormat, value: fileType.uppercased())
                    LabeledContent(L10n.readerSettingsSecureConnection, value: L10n.readerSettingsActive)
                } header: {
                    Label(L10n.readerSettingsBookInfo, systemImage: "info.circle")
                }
            }
            .scrollContentBackground(.hidden)
            .background((ReaderPaperTheme(rawValue: paperTheme) ?? .sepia).paper)
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
    var maxSelectablePage: Int?
    let onSelect: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 16)]

    private var visiblePageCount: Int {
        guard let pageCount = model.pageCount else { return 0 }
        if let maxSelectablePage {
            return min(pageCount, maxSelectablePage)
        }
        return pageCount
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.pageCount != nil, let service = model.service {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(0..<visiblePageCount, id: \.self) { index in
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
    let document: PDFDocument
    @Binding var progress: ReadingProgress
    @Binding var requestedPage: Int?
    let layout: PDFReadingLayout
    var initialPage: Int = 1
    var maxAccessiblePage: Int? = nil
    var onPageChange: (ReadingProgress) -> Void = { _ in }
    var onRestored: () -> Void = {}
    var onToggleControls: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            progress: $progress,
            requestedPage: $requestedPage,
            initialPage: initialPage,
            maxAccessiblePage: maxAccessiblePage,
            onPageChange: onPageChange,
            onRestored: onRestored
        )
    }

    func makeUIView(context: Context) -> PDFView {
        let view = ResumePDFView()
        view.backgroundColor = .white
        context.coordinator.maxAccessiblePage = maxAccessiblePage
        context.coordinator.configure(view, url: url, layout: layout, makeDocument: { _ in document })
        context.coordinator.observe(view)
        context.coordinator.installControlGesture(on: view, action: onToggleControls)
        context.coordinator.updateProgress(from: view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.maxAccessiblePage = maxAccessiblePage
        context.coordinator.onPageChange = onPageChange
        context.coordinator.onRestored = onRestored
        context.coordinator.onToggleControls = onToggleControls
        context.coordinator.configure(uiView, url: url, layout: layout, makeDocument: { _ in document })
        guard context.coordinator.isRestored, let requestedPage,
              let pdfDocument = uiView.document else { return }
        let target = context.coordinator.clampedPage(requestedPage, documentPageCount: pdfDocument.pageCount)
        guard let page = pdfDocument.page(at: target - 1) else { return }
        if uiView.currentPage !== page { uiView.go(to: page) }
        context.coordinator.clearRequestedPage(expected: requestedPage)
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        coordinator.stopObserving()
        uiView.document = nil
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private var loadedURL: URL?
        private var appliedLayout: PDFReadingLayout?
        private var progress: Binding<ReadingProgress>
        private var requestedPage: Binding<Int?>
        private weak var view: PDFView?
        private var pageObserver: NSObjectProtocol?
        private(set) var isRestored = false
        private let initialPage: Int
        var onPageChange: (ReadingProgress) -> Void
        var onRestored: () -> Void
        private var lastPage: Int?
        private var restorationGeneration = UUID()
        private var restorationScheduled = false
        var maxAccessiblePage: Int?
        var onToggleControls: () -> Void = {}
        private var controlGesture: UITapGestureRecognizer?

        init(
            progress: Binding<ReadingProgress>,
            requestedPage: Binding<Int?>,
            initialPage: Int = 1,
            maxAccessiblePage: Int? = nil,
            onPageChange: @escaping (ReadingProgress) -> Void = { _ in },
            onRestored: @escaping () -> Void = {}
        ) {
            self.progress = progress
            self.requestedPage = requestedPage
            self.initialPage = initialPage
            self.maxAccessiblePage = maxAccessiblePage
            self.onPageChange = onPageChange
            self.onRestored = onRestored
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
            let target = clampedPage(initialPage, documentPageCount: document.pageCount)
            let generation = restorationGeneration
            restorationScheduled = true
            Task { @MainActor [weak self, weak view] in
                guard let self, let view, self.restorationGeneration == generation,
                      view.document === document else { return }
                guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else {
                    self.restorationScheduled = false
                    return
                }
                view.layoutIfNeeded()
                if let page = document.page(at: target - 1) { view.go(to: page) }
                Task { @MainActor [weak self, weak view] in
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
                    let restored = self.onRestored
                    ReaderDeferredTeardown.enqueue {
                        restored()
                    }
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
                Task { @MainActor in
                    guard let self, let view = self.view else { return }
                    self.updateProgress(from: view)
                }
            }
        }

        func installControlGesture(on view: PDFView, action: @escaping () -> Void) {
            onToggleControls = action
            let gesture = UITapGestureRecognizer(target: self, action: #selector(toggleControls(_:)))
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            view.addGestureRecognizer(gesture)
            controlGesture = gesture
        }

        @objc private func toggleControls(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, view?.currentSelection == nil else { return }
            onToggleControls()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view, view.currentSelection == nil, !(touch.view is UIControl) else { return false }
            let point = touch.location(in: view)
            if let page = view.page(for: point, nearest: false), page.annotation(at: view.convert(point, to: page)) != nil { return false }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            (otherGestureRecognizer as? UITapGestureRecognizer).map { $0.numberOfTapsRequired > 1 } ?? false
        }

        func updateProgress(from view: PDFView) {
            guard isRestored, let document = view.document, document.pageCount > 0,
                  let currentPage = view.currentPage else { return }
            let pageIndex = document.index(for: currentPage)
            guard pageIndex >= 0, pageIndex < document.pageCount else { return }
            let rawPage = pageIndex + 1
            let limitedPage = clampedPage(rawPage, documentPageCount: document.pageCount)
            if limitedPage < rawPage {
                let targetIndex = limitedPage - 1
                Task { @MainActor [weak self] in
                    guard let self, let view = self.view, let document = view.document,
                          let page = document.page(at: targetIndex),
                          view.currentPage !== page else { return }
                    view.go(to: page)
                }
            }
            let next = ReadingProgress(currentPage: limitedPage, totalPages: document.pageCount)
            if lastPage != next.currentPage {
                lastPage = next.currentPage
                onPageChange(next)
            }
            if progress.wrappedValue != next { progress.wrappedValue = next }
        }

        func clampedPage(_ page: Int, documentPageCount: Int) -> Int {
            let documentLimit = max(documentPageCount, 1)
            let previewCap = maxAccessiblePage.map { min(max($0, 1), documentLimit) } ?? documentLimit
            return min(max(1, page), previewCap)
        }

        func clearRequestedPage(expected: Int) {
            Task { @MainActor [weak self] in
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
            if let controlGesture { view?.removeGestureRecognizer(controlGesture) }
            controlGesture = nil
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
    @Environment(\.dismiss) private var dismiss
    let bookID: Int
    var onPremium: (() -> Void)? = nil

    @State private var book: BookDTO?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ReaderLoadingView(title: L10n.bookDetailLoading, author: "", phase: .authorizing, theme: .sepia)
            } else if let book {
                ReaderView(book: book, onPremium: onPremium)
            } else {
                EKErrorState(title: L10n.bookDetailOpenFailed, message: errorMessage ?? L10n.bookDetailLoadFailed) {
                    Task { await load() }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if book == nil {
                ReaderIconButton(icon: "chevron.left", label: L10n.commonClose, theme: .sepia) { dismiss() }
                    .padding(12)
            }
        }
        .task(id: bookID) {
            guard book?.id != String(bookID) else { return }
            await load()
        }
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
