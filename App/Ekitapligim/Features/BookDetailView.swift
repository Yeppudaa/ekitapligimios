import SwiftUI
import EkitapligimCore

struct BookDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let bookID: Int

    @State private var book: BookDTO?
    @State private var access: ReaderAccessDTO?
    @State private var similarBooks: [BookDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var downloadStatusMessage: String?
    @State private var comments: [BookCommentDTO] = []
    @State private var commentsPage = 0
    @State private var commentsLastPage = 1
    @State private var commentText = ""
    @State private var commentRating = 5
    @State private var isSubmittingComment = false
    @State private var commentsError: String?
    @State private var selectedCommentForReport: BookCommentDTO?
    @State private var showingCommentLoginAlert = false
    private let contentSafety = ContentSafety()

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L10n.bookDetailLoading)
            } else if let errorMessage {
                ContentUnavailableView(L10n.bookDetailOpenFailed, systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if let book {
                List {
                    Section {
                        Text(book.title).font(.title2.bold())
                        Text(book.author).foregroundStyle(.secondary)
                        Text(book.description.isEmpty ? L10n.bookDetailMissingDescription : book.description)
                    }
                    Section {
                        NavigationLink {
                            ReaderView(book: book)
                        } label: {
                            Label(access?.canReadOnline == true ? L10n.bookDetailRead : L10n.bookDetailCheckReading, systemImage: "book")
                        }
                        Button {
                            Task { await download(book) }
                        } label: {
                            Label(L10n.bookDetailOfflineDownload, systemImage: "arrow.down.circle")
                        }
                        .disabled(access?.canDownload != true)
                        Button {
                            showingReport = true
                        } label: {
                            Label(L10n.bookDetailReportIssue, systemImage: "flag")
                        }
                    }
                    if let downloadStatusMessage {
                        Section {
                            Text(downloadStatusMessage)
                        }
                    }
                    if !similarBooks.isEmpty {
                        Section(L10n.bookDetailSimilarBooks) {
                            ForEach(similarBooks) { similar in
                                NavigationLink {
                                    BookDetailView(bookID: Int(similar.id) ?? 0)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(similar.title).font(.headline)
                                        Text(similar.author).font(.subheadline).foregroundStyle(.secondary)
                                        if !similar.category.isEmpty {
                                            Text(similar.category).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    Section(L10n.bookCommentsTitle) {
                        if isSignedIn {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        commentRating = value
                                    } label: {
                                        Image(systemName: value <= commentRating ? "star.fill" : "star")
                                            .foregroundStyle(.yellow)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(L10n.bookCommentsRating(value))
                                }
                            }
                            TextField(L10n.bookCommentsPlaceholder, text: $commentText, axis: .vertical)
                                .lineLimit(2...6)
                                .onChange(of: commentText) { _, value in commentText = String(value.prefix(10_000)) }
                            Button(L10n.bookCommentsSubmit) {
                                Task { await submitComment() }
                            }
                            .disabled(commentText.trimmed.isEmpty || isSubmittingComment)
                        } else {
                            Button(L10n.bookCommentsLoginToComment) {
                                showingCommentLoginAlert = true
                            }
                        }

                        if let commentsError {
                            Text(commentsError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if comments.isEmpty && commentsError == nil {
                            Text(L10n.bookCommentsEmpty)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(comments) { comment in
                            BookCommentRow(comment: comment) {
                                if isSignedIn {
                                    selectedCommentForReport = comment
                                } else {
                                    showingCommentLoginAlert = true
                                }
                            }
                        }

                        if commentsPage < commentsLastPage {
                            Button(L10n.commonLoadMore) { Task { await loadComments(reset: false) } }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.bookDetailTitle)
        .task { await load() }
        .sheet(isPresented: $showingReport) {
            ReportContentView(kind: .book(bookID: bookID))
        }
        .sheet(item: $selectedCommentForReport) { comment in
            if let postID = Int(comment.id) {
                ReportContentView(kind: .post(postID: postID))
            }
        }
        .alert(L10n.bookCommentsLoginRequiredTitle, isPresented: $showingCommentLoginAlert) {
            Button(L10n.bookRequestsGoToLogin) { container.selectedTab = .settings }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.bookCommentsLoginRequiredMessage)
        }
    }

    @State private var showingReport = false

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let detailResult = container.books.bookDetail(id: bookID)
            async let accessResult = container.books.readerAccess(bookID: bookID)
            let detail = try await detailResult
            book = detail.book
            similarBooks = detail.similarBooks.filter { Int($0.id) != bookID }
            access = try? await accessResult
            await loadComments(reset: true)
        } catch {
            errorMessage = L10n.bookDetailLoadFailed
        }
    }

    private func loadComments(reset: Bool) async {
        let page = reset ? 1 : commentsPage + 1
        commentsError = nil
        do {
            let result = try await container.books.comments(bookID: bookID, page: page)
            comments = reset ? result.comments : comments + result.comments.filter { item in
                !comments.contains(where: { $0.id == item.id })
            }
            commentsPage = result.currentPage
            commentsLastPage = result.lastPage
        } catch {
            commentsError = L10n.bookCommentsLoadFailed
        }
    }

    private func submitComment() async {
        let message = commentText.trimmed
        guard !message.isEmpty, !isSubmittingComment else { return }
        if case .rejected(let reason) = contentSafety.validateUserGeneratedText(message) {
            commentsError = reason.userMessage
            return
        }
        isSubmittingComment = true
        defer { isSubmittingComment = false }
        do {
            _ = try await container.books.createComment(bookID: bookID, message: message, rating: commentRating)
            commentText = ""
            await loadComments(reset: true)
        } catch {
            commentsError = L10n.bookCommentsSubmitFailed
        }
    }

    private func download(_ book: BookDTO) async {
        guard let bookID = Int(book.id) else {
            downloadStatusMessage = L10n.bookDetailInvalidId
            return
        }
        guard let currentAccess = try? await container.books.readerAccess(bookID: bookID),
              currentAccess.canDownload else {
            downloadStatusMessage = L10n.bookDetailSecureDownloadMissing
            return
        }
        access = currentAccess
        guard let session = try? await container.books.createReaderSession(bookID: bookID, purpose: .download),
              let url = URL(string: session.sourceUrl) else {
            downloadStatusMessage = L10n.bookDetailSecureDownloadMissing
            return
        }
        await container.downloadManager.download(
            bookID: book.id,
            sourceURL: url,
            expectedFileType: session.fileType
        )
        switch container.downloadManager.states[book.id] {
        case .downloaded:
            downloadStatusMessage = L10n.bookDetailDownloadReady
        case .failed(let message):
            downloadStatusMessage = message
        default:
            downloadStatusMessage = L10n.bookDetailDownloadStarted
        }
    }
}

private struct BookCommentRow: View {
    let comment: BookCommentDTO
    let report: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.username).font(.subheadline.weight(.semibold))
                Spacer()
                if comment.rating > 0 {
                    Label("\(comment.rating)", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(action: report) {
                    Image(systemName: "flag")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L10n.bookCommentsReport)
            }
            if !comment.message.isEmpty {
                Text(comment.message)
            }
            if comment.createdAt > 0 {
                Text(Date(timeIntervalSince1970: TimeInterval(comment.createdAt)), format: .dateTime.day().month().year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
