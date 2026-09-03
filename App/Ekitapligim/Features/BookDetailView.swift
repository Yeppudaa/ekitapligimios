import SwiftUI
import EkitapligimCore

/// Validates navigation targets before opening book detail.
@MainActor
struct BookDetailDestination: View {
    let bookIDString: String

    var body: some View {
        if let id = Int(bookIDString), id > 0 {
            BookDetailView(bookID: id)
        } else {
            EKitapligimScreen {
                EKEmptyState(
                    title: L10n.bookDetailOpenFailed,
                    message: L10n.bookDetailInvalidId,
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
    }
}

@MainActor
struct BookDetailView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    let bookID: Int

    @State private var book: BookDTO?
    @State private var access: ReaderAccessDTO?
    @State private var similarBooks: [BookDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var downloadStatusMessage: String?
    @State private var shelfStatusMessage: String?
    @State private var currentShelfState = ""
    @State private var isFavorite = false
    @State private var isUpdatingShelf = false
    @State private var comments: [BookCommentDTO] = []
    @State private var commentsPage = 0
    @State private var commentsLastPage = 1
    @State private var commentText = ""
    @FocusState private var isCommentFocused: Bool
    @State private var commentRating = 5
    @State private var isSubmittingComment = false
    @State private var commentsError: String?
    @State private var showingCommentLoginAlert = false
    @State private var showingReaderLoginAlert = false
    @State private var showingReport = false
    @State private var selectedIssueType = "copyright"
    @State private var issueFeedback: String?
    @State private var isSynopsisExpanded = false
    @State private var heroCardWidth: CGFloat = 360
    private let contentSafety = ContentSafety()

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }

    var body: some View {
        EKitapligimScreen {
            Group {
                if bookID <= 0 {
                    EKEmptyState(
                        title: L10n.bookDetailOpenFailed,
                        message: L10n.bookDetailInvalidId,
                        systemImage: "exclamationmark.triangle"
                    )
                } else if isLoading {
                    EKLoadingState(message: L10n.bookDetailLoading)
                } else if let errorMessage {
                    EKErrorState(title: L10n.bookDetailOpenFailed, message: errorMessage) {
                        Task { await load() }
                    }
                } else if let book {
                    detailContent(book)
                } else {
                    EKErrorState(title: L10n.bookDetailOpenFailed, message: L10n.bookDetailLoadFailed) {
                        Task { await load() }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xFFFCF4), Color(hex: 0xFBF7EF), Color(hex: 0xF8FBFA), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            androidBookTopBar
        }
        .task(id: bookID) { await load() }
        .sheet(isPresented: $showingReport) {
            ReportContentView(kind: .book(bookID: bookID), initialType: selectedIssueType) { success in
                if success {
                    issueFeedback = L10n.bookDetailIssueSubmitted(issueShortLabel(selectedIssueType))
                } else {
                    issueFeedback = L10n.bookDetailIssueSubmitFailed
                }
            }
        }
        .alert(L10n.bookCommentsLoginRequiredTitle, isPresented: $showingCommentLoginAlert) {
            Button(L10n.bookRequestsGoToLogin) { container.selectedTab = .profile }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.bookCommentsLoginRequiredMessage)
        }
        .alert(L10n.bookCommentsLoginRequiredTitle, isPresented: $showingReaderLoginAlert) {
            Button(L10n.bookRequestsGoToLogin) { container.selectedTab = .profile }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.bookDetailLoginRequiredMessage)
        }
        .onChange(of: container.libraryItems) { _, _ in
            syncShelfFromLibrary()
        }
    }

    private func detailContent(_ book: BookDTO) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                heroSection(book)
                actionsSection(book)
                statusBanners
                infoCard(book)
                synopsisCard(book)
                reportSection
                similarSection
                commentsCard
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }

    private var isCompactHero: Bool { heroCardWidth < 380 }
    private var isStackedHero: Bool { heroCardWidth < 260 }

    /// Android `BookDetailScreen` similar-card widths: 106 / 116 / 128.
    private var similarCardWidth: CGFloat {
        if heroCardWidth < 380 { return 106 }
        if heroCardWidth < 700 { return 116 }
        return 128
    }

    private func heroSection(_ book: BookDTO) -> some View {
        Group {
            if isStackedHero {
                VStack(spacing: 18) {
                    heroCover(book, compact: true)
                    heroInfo(book, centered: true)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: isCompactHero ? 14 : 22) {
                    heroCover(book, compact: isCompactHero)
                    heroInfo(book, centered: false)
                        .padding(.top, 30)
                }
            }
        }
        .padding(16)
        .ekitapligimCard()
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: BookDetailHeroWidthKey.self, value: geo.size.width)
            }
        }
        .onPreferenceChange(BookDetailHeroWidthKey.self) { heroCardWidth = $0 }
    }

    private func heroCover(_ book: BookDTO, compact: Bool) -> some View {
        EKitapligimRemoteCover(urlString: book.coverUrl)
            .frame(width: compact ? 112 : 170, height: compact ? 166 : 250)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func heroInfo(_ book: BookDTO, centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 8) {
            Text(book.title)
                .font(.system(.title3, design: .serif).weight(.heavy))
                .foregroundStyle(Color(hex: 0x0D3037))
                .multilineTextAlignment(centered ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
            heroMetaLine(
                "pencil.and.outline",
                book.author.isEmpty ? L10n.bookDetailUnspecified : book.author,
                Color(hex: 0xB17C2A)
            )
            heroMetaLine(
                "building.columns.fill",
                book.publisher.isEmpty ? L10n.bookDetailUnspecified : book.publisher,
                Color(hex: 0x7D8A8F)
            )
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hex: 0xD08A27))
                    .frame(width: 27, height: 27)
                Text(String(format: "%.1f", book.rating ?? 0))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x12252C))
                Rectangle()
                    .fill(Color(hex: 0xE7D8C5))
                    .frame(width: 1, height: 24)
                Text(L10n.bookDetailDownloadCount(book.displayedDownloadCount))
                    .font(.body)
                    .foregroundStyle(Color(hex: 0x7D8A8F))
                    .lineLimit(1)
                if book.isPremiumOnly {
                    Text(L10n.premiumTitle)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(EKitapligimPalette.profileGoldDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(EKitapligimPalette.amberSoft, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    private func heroMetaLine(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color.opacity(0.82))
                .frame(width: 17, height: 17)
            Text(text)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    private func actionsSection(_ book: BookDTO) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if isSignedIn {
                    NavigationLink {
                        ReaderView(book: book)
                    } label: {
                        readButtonLabel
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { showingReaderLoginAlert = true } label: {
                        readButtonLabel
                    }
                    .accessibilityLabel(L10n.bookDetailRead)
                    .buttonStyle(.plain)
                }

                Button {
                    guard isSignedIn else {
                        showingReaderLoginAlert = true
                        return
                    }
                    Task { await download(book) }
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3.weight(.bold))
                        .accessibilityLabel(L10n.bookDetailOfflineDownload)
                        .foregroundStyle(access?.canDownload == true ? Color(hex: 0x087A80) : Color(hex: 0x20363D))
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(colors: [.white, Color(hex: 0xFFFBF4)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xE7D8C5)) }
                }
                .accessibilityLabel(L10n.bookDetailOfflineDownload)
            }

            HStack(spacing: 10) {
                Menu {
                    Button(L10n.libraryShelfLater) { Task { await updateShelf("OKUYACAGIM") } }
                    Button(L10n.libraryShelfReading) { Task { await updateShelf("OKUYORUM") } }
                    Button(L10n.libraryShelfFinished) { Task { await updateShelf("OKUDUM") } }
                    Button(L10n.libraryShelfRemove, role: .destructive) { Task { await updateShelf("NONE") } }
                } label: {
                    Label(shelfActionTitle, systemImage: "bookmark.fill")
                        .font(.system(.subheadline, design: .serif).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0xD9A24A), Color(hex: 0xC48728), Color(hex: 0xB97718)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: 0xE0B567), lineWidth: 1)
                        }
                }
                .disabled(!isSignedIn || isUpdatingShelf)
                .accessibilityLabel(L10n.libraryShelfPicker)

                Button {
                    Task { await toggleFavorite() }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isFavorite ? Color(hex: 0xC58A32) : Color(hex: 0x20363D))
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(colors: [.white, Color(hex: 0xFFFBF4)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xE7D8C5)) }
                }
                .disabled(!isSignedIn || isUpdatingShelf)
                .accessibilityLabel(L10n.bookDetailAddToFavorites)

            }
        }
    }

    private var readButtonLabel: some View {
        Label(access?.canReadOnline == true ? L10n.bookDetailRead : L10n.bookDetailCheckReading, systemImage: "book.fill")
            .font(.system(.subheadline, design: .serif).weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x0A3B43), Color(hex: 0x0E5660), Color(hex: 0x08323A)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: 0x0F5961).opacity(0.55), lineWidth: 1)
            }
    }

    private var shelfActionTitle: String {
        switch currentShelfState.uppercased() {
        case "OKUYACAGIM", "WANT_TO_READ": L10n.libraryShelfLaterShort
        case "OKUYORUM", "READING": L10n.libraryShelfReading
        case "OKUDUM", "READ", "FINISHED": L10n.libraryShelfFinished
        default: L10n.libraryShelfAdd
        }
    }

    @ViewBuilder
    private var statusBanners: some View {
        if let downloadStatusMessage {
            statusBanner(downloadStatusMessage, icon: "arrow.down.circle.fill", tint: EKitapligimPalette.teal)
        }
        if let shelfStatusMessage {
            statusBanner(shelfStatusMessage, icon: "books.vertical.fill", tint: EKitapligimPalette.success)
        }
    }

    private func statusBanner(_ message: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(message).font(.caption).foregroundStyle(EKitapligimPalette.ink)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func infoCard(_ book: BookDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(L10n.bookDetailInfoTitle)
            HStack(spacing: 10) {
                infoCell("tag.fill", L10n.bookDetailInfoCategory, book.category, accent: Color(hex: 0xE75D8F))
                infoCell("globe", L10n.bookDetailInfoLanguage, book.language)
            }
            HStack(spacing: 10) {
                infoCell("book.closed.fill", L10n.bookDetailInfoPages, String(book.pageCount))
                infoCell("calendar", L10n.bookDetailInfoYear, book.publishYear)
            }
            HStack(spacing: 10) {
                infoCell("barcode", L10n.bookDetailInfoISBN, book.isbn)
                infoCell("doc.text", L10n.bookDetailInfoFormat, book.displayedFormat)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xE7D3B3), lineWidth: 1)
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .serif).weight(.heavy))
                .foregroundStyle(Color(hex: 0x0D3037))
            Rectangle()
                .fill(Color(hex: 0xD5A65A))
                .frame(width: 46, height: 1)
            Spacer(minLength: 0)
        }
    }

    private func infoCell(_ icon: String, _ label: String, _ value: String, accent: Color = Color(hex: 0x42646A)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hex: 0x8C8175))
                Text(value.isEmpty ? L10n.bookDetailUnspecified : value)
                    .font(.system(.subheadline, design: .serif).weight(.bold))
                    .foregroundStyle(label == L10n.bookDetailInfoCategory ? Color(hex: 0xE75D8F) : Color(hex: 0x18252B))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xEBD8BD), lineWidth: 1)
        }
    }

    private func synopsisCard(_ book: BookDTO) -> some View {
        let cleaned = book.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let paragraphs = cleaned
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let canExpand = cleaned.count > 320 || paragraphs.count > 2
        let visible: [String] = {
            if cleaned.isEmpty { return [] }
            if !canExpand || isSynopsisExpanded { return paragraphs }
            let initial = Array(paragraphs.prefix(3))
            let joined = initial.joined(separator: "\n\n")
            if joined.count <= 320 { return initial }
            let trimmed = String(joined.prefix(320)).trimmingCharacters(in: CharacterSet(charactersIn: ",.;: "))
            return [trimmed + "..."]
        }()

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeading(L10n.bookDetailSynopsisSectionTitle)
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Color(hex: 0x244C73), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.bookDetailSynopsisTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(hex: 0x1F2937))
                    Text(L10n.bookDetailSynopsisSubtitle)
                        .font(.caption2)
                        .foregroundStyle(Color(hex: 0x8A6E52))
                }
                Spacer(minLength: 0)
            }
            if visible.isEmpty {
                Text(L10n.bookDetailMissingDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x7A6B5A))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xE18A1A), Color(hex: 0x244C73)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                        .frame(minHeight: 92)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(visible.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(.body)
                                .foregroundStyle(Color(hex: 0x374151))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if canExpand {
                Button {
                    isSynopsisExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(isSynopsisExpanded ? L10n.bookDetailSynopsisShowLess : L10n.bookDetailSynopsisReadMore)
                            .font(.caption.weight(.bold))
                        Image(systemName: isSynopsisExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0x0B3D45), in: Capsule())
                    .overlay {
                        Capsule().stroke(Color(hex: 0x174F58), lineWidth: 1)
                    }
                }
                .accessibilityLabel(isSynopsisExpanded ? L10n.bookDetailSynopsisShowLess : L10n.bookDetailSynopsisReadMore)
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0xFFFCF6), Color(hex: 0xF8F3EC)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xEFE3D4), lineWidth: 1)
        }
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xE18A1A))
                    .padding(10)
                    .background(Color(hex: 0xFFE8C9), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.bookDetailIssueTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(hex: 0x1F2937))
                    Text(L10n.bookDetailIssueSubtitle)
                        .font(.caption2)
                        .foregroundStyle(Color(hex: 0x667085))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                issueChip(L10n.bookDetailIssueBrokenLink, icon: "link", type: "broken_link")
                issueChip(L10n.bookDetailIssueMissingCover, icon: "photo", type: "missing_cover")
                issueChip(L10n.bookDetailIssueCopyright, icon: "c.circle", type: "copyright")
            }
            if let issueFeedback {
                Text(issueFeedback)
                    .font(.caption2)
                    .foregroundStyle(Color(hex: issueFeedback.localizedCaseInsensitiveContains("alındı") ? 0x0F766E : 0xB45309))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xF7FBFA), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xC9E5E3), lineWidth: 1)
        }
    }


    private func issueShortLabel(_ type: String) -> String {
        switch type {
        case "broken_link": L10n.bookDetailIssueBrokenLink
        case "missing_cover": L10n.bookDetailIssueMissingCover
        default: L10n.bookDetailIssueCopyright
        }
    }

    private func issueChip(_ title: String, icon: String, type: String) -> some View {
        Button {
            if isSignedIn {
                selectedIssueType = type
                showingReport = true
            } else {
                issueFeedback = type == "copyright"
                    ? L10n.bookDetailIssueCopyrightLoginRequired
                    : L10n.bookDetailIssueLoginRequired
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(Color(hex: 0x244C73))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: 0xDCE4EE), lineWidth: 1)
            }
        }
        .accessibilityLabel(title)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var similarSection: some View {
        if !similarBooks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(L10n.bookDetailSimilarBooks)
                        .font(.system(.title3, design: .serif).weight(.heavy))
                        .foregroundStyle(Color(hex: 0x0D3037))
                    Spacer(minLength: 0)
                    Text(L10n.homeSeeAll)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x0D3037))
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x7D8A8F))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(similarBooks.prefix(8)) { similar in
                            NavigationLink {
                                BookDetailView(bookID: Int(similar.id) ?? 0)
                            } label: {
                                SimilarBookCard(book: similar, width: similarCardWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var commentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            commentsSectionHeader
            if isSignedIn {
                commentsComposer
            }
            commentsFeedback
            ForEach(comments.filter { comment in
                guard let userID = comment.userId else { return true }
                return !container.blockedUserIDs.contains(userID)
            }) { comment in
                BookCommentRow(comment: comment) {
                    if let userID = comment.userId {
                        comments.removeAll { $0.userId == userID }
                    }
                }
            }
            if commentsPage < commentsLastPage {
                Button(L10n.commonLoadMore) { Task { await loadComments(reset: false) } }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.tealDark)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xF8FBFA), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xDCECEA), lineWidth: 1)
        }
    }

    private var commentsSectionHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "text.bubble.fill")
                .font(.title3)
                .foregroundStyle(Color(hex: 0x153F45))
                .frame(width: 46, height: 46)
                .background(Color(hex: 0xE8EFEA), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.bookCommentsTitleCount(comments.count))
                    .font(.system(.title3, design: .serif).weight(.heavy))
                    .foregroundStyle(Color(hex: 0x0D3037))
                Text(isSignedIn ? L10n.bookCommentsSignedInSubtitle : L10n.bookCommentsGuestSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0x56666C))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if !isSignedIn {
                Button(L10n.bookCommentsLoginToComment) { showingCommentLoginAlert = true }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0x0B3D45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var commentsComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(L10n.bookCommentsYourRating)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x56666C))
                ForEach(1...5, id: \.self) { value in
                    Button { commentRating = value } label: {
                        Image(systemName: value <= commentRating ? "star.fill" : "star")
                            .font(.body)
                            .foregroundStyle(Color(hex: 0xD08A27))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.bookCommentsRating(value))
                }
            }
            TextField(L10n.bookCommentsPlaceholder, text: $commentText, axis: .vertical)
                .focused($isCommentFocused)
                .lineLimit(2...5)
                .frame(minHeight: 84, alignment: .top)
                .padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: isCommentFocused ? 0x087A80 : 0xD7C9B4), lineWidth: 1)
                }
            HStack {
                Spacer(minLength: 0)
                Button(L10n.bookCommentsSubmit) { Task { await submitComment() } }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0x0B3D45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(isSubmittingComment)
            }
        }
    }

    @ViewBuilder
    private var commentsFeedback: some View {
        if let commentsError {
            Text(commentsError).font(.footnote).foregroundStyle(EKitapligimPalette.danger)
        }
    }

    private func load() async {
        guard bookID > 0 else {
            isLoading = false
            errorMessage = L10n.bookDetailInvalidId
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let detailResult = container.books.bookDetail(id: bookID)
            async let accessResult = container.books.readerAccess(bookID: bookID)
            let detail = try await detailResult
            book = detail.book
            similarBooks = Array(detail.similarBooks.filter { Int($0.id) != bookID }.prefix(8))
            access = try? await accessResult
            syncShelfFromLibrary()
            await loadComments(reset: true)
        } catch {
            book = nil
            errorMessage = L10n.bookDetailLoadFailed
        }
    }

    private func syncShelfFromLibrary() {
        guard let item = libraryItem else {
            currentShelfState = ""
            isFavorite = false
            return
        }
        currentShelfState = item.displayShelfStateForMenu
        isFavorite = item.isFavoriteItem
    }

    private var libraryItem: LibraryItemDTO? {
        container.libraryItems.first(where: { $0.bookId == String(bookID) })
    }

    private func preservedReadingProgress() -> (percent: Int, page: Int) {
        libraryItem?.readingProgressForShelfUpdate ?? (0, 0)
    }

    private func applyOptimisticShelfUpdate(shelfState: String, isFavorite favoriteOverride: Bool? = nil) {
        let bookIDString = String(bookID)
        let progress = preservedReadingProgress()
        let favorite = favoriteOverride ?? (shelfState == "FAVORI")

        if let existing = libraryItem {
            container.patchLibraryItem(bookIDString) { item in
                item.updating(
                    shelfState: shelfState,
                    progressPercent: progress.percent,
                    lastReadPage: progress.page,
                    isFavorite: favorite
                )
            }
        } else if let book {
            container.upsertLibraryItem(
                LibraryItemDTO(
                    bookId: bookIDString,
                    shelfState: shelfState,
                    progressPercent: progress.percent,
                    lastReadPage: progress.page,
                    isDownloaded: false,
                    isFavorite: favorite,
                    title: book.title,
                    author: book.author,
                    coverUrl: book.coverUrl,
                    pageCount: book.pageCount
                )
            )
        }

        if favoriteOverride != nil {
            isFavorite = favoriteOverride ?? isFavorite
        }
        if !shelfState.isEmpty, shelfState != "FAVORI", shelfState != "NONE" {
            currentShelfState = shelfState
        }
    }

    private func updateShelf(_ state: String) async {
        guard isSignedIn, !isUpdatingShelf else { return }
        isUpdatingShelf = true
        shelfStatusMessage = nil
        defer { isUpdatingShelf = false }
        let progress = preservedReadingProgress()
        do {
            try await container.books.updateLibraryItem(
                bookID: bookID,
                shelfState: state,
                progressPercent: progress.percent,
                lastReadPage: progress.page
            )
            applyOptimisticShelfUpdate(shelfState: state)
            shelfStatusMessage = shelfLabel(for: state)
            Task { await container.refreshSessionData() }
            syncShelfFromLibrary()
        } catch {
            shelfStatusMessage = L10n.libraryUpdateFailed
        }
    }

    private func toggleFavorite() async {
        guard isSignedIn, !isUpdatingShelf else { return }
        isUpdatingShelf = true
        defer { isUpdatingShelf = false }
        // Android toggles favorite via shelf_state FAVORI <-> NONE while preserving reading shelf metadata.
        let nextState = isFavorite ? "NONE" : "FAVORI"
        let progress = preservedReadingProgress()
        do {
            try await container.books.updateLibraryItem(
                bookID: bookID,
                shelfState: nextState,
                progressPercent: progress.percent,
                lastReadPage: progress.page
            )
            applyOptimisticShelfUpdate(
                shelfState: nextState,
                isFavorite: nextState == "FAVORI"
            )
            Task { await container.refreshSessionData() }
            syncShelfFromLibrary()
            shelfStatusMessage = isFavorite ? L10n.libraryShelfFavorites : L10n.libraryShelfRemove
        } catch {
            shelfStatusMessage = L10n.libraryUpdateFailed
        }
    }

    private func shelfLabel(for state: String) -> String {
        switch state.uppercased() {
        case "OKUYORUM", "READING": L10n.libraryShelfReading
        case "OKUYACAGIM", "WANT_TO_READ": L10n.libraryShelfLater
        case "OKUDUM", "READ", "FINISHED": L10n.libraryShelfFinished
        case "FAVORI", "FAVORITE": L10n.libraryShelfFavorites
        case "NONE", "": L10n.libraryShelfRemove
        default: state
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
        guard isSignedIn, !message.isEmpty, !isSubmittingComment else { return }
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
        guard let resolvedID = Int(book.id) else {
            downloadStatusMessage = L10n.bookDetailInvalidId
            return
        }
        let currentAccess = (try? await container.books.readerAccess(bookID: resolvedID)) ?? access
        access = currentAccess
        guard let currentAccess, currentAccess.canDownload else {
            downloadStatusMessage = downloadDenialMessage(from: currentAccess)
            return
        }
        do {
            let session = try await container.books.createReaderSession(bookID: resolvedID, purpose: .download)
            guard let url = ReaderSourcePolicy.nativeContentURL(
                session: session,
                bookID: resolvedID,
                apiBaseURL: container.config.apiBaseURL
            ) else {
                downloadStatusMessage = L10n.readerAtsLinkMissing
                return
            }
            await container.downloadManager.download(
                bookID: book.id,
                sourceURL: url,
                expectedFileType: session.fileType
            )
        } catch {
            downloadStatusMessage = (error as? APIClientError)?.serverMessage ?? downloadDenialMessage(from: currentAccess)
            return
        }
        switch container.downloadManager.states[book.id] {
        case .downloaded:
            downloadStatusMessage = L10n.bookDetailDownloadReady
            _ = await container.refreshLibrary()
        case .failed(let message):
            downloadStatusMessage = message
        default:
            downloadStatusMessage = L10n.bookDetailDownloadStarted
        }
    }

    private func downloadDenialMessage(from access: ReaderAccessDTO?) -> String {
        if let message = access?.denialMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            return message
        }
        if let quota = access?.dailyDownload, !quota.isAllowed, quota.limit > 0 {
            return L10n.quotaDownloadSubtitle(used: quota.used, limit: quota.limit)
        }
        if let code = access?.denialCode?.uppercased() {
            switch code {
            case "PREMIUM_REQUIRED", "SUBSCRIPTION_REQUIRED", "PREMIUM_ONLY":
                return L10n.premiumLoginRequired
            default:
                break
            }
        }
        return L10n.bookDetailSecureDownloadMissing
    }


    private var topBarTitle: String {
        guard let book, !book.title.isEmpty else { return L10n.bookDetailTitle }
        return book.title
    }

    private var androidBookTopBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                androidRoundToolbarIcon("arrow.backward")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.commonBack)

            Text(topBarTitle)
                .font(.system(.headline, design: .serif).weight(.heavy))
                .foregroundStyle(Color(hex: 0x0D3037))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Group {
                if let book {
                    ShareLink(
                        item: BookShareFormatting.body(title: book.title, author: book.author, pdfURL: "", bookID: book.id),
                        subject: Text(book.title)
                    ) {
                        androidRoundToolbarIcon("square.and.arrow.up")
                    }
                    .accessibilityLabel(L10n.commonShare)
                } else {
                    androidRoundToolbarIcon("square.and.arrow.up")
                        .opacity(0.35)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 78)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(EKitapligimPalette.border)
                        .frame(height: 1)
                }
        }
    }

    private func androidRoundToolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(hex: 0x153F45))
            .frame(width: 48, height: 48)
            .background(Color.white.opacity(0.96), in: Circle())
            .overlay {
                Circle().stroke(Color(hex: 0xE3C79A), lineWidth: 1)
            }
    }
}

@MainActor
private struct SimilarBookCard: View {
    let book: BookDTO
    var width: CGFloat = 116

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.white
                .aspectRatio(0.66, contentMode: .fit)
                .overlay {
                    EKitapligimRemoteCover(urlString: book.coverUrl)
                        .padding(4)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: 0xE5D7BD), lineWidth: 1)
                }
            Text(book.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(hex: 0x10232D))
                .lineLimit(2)
            if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(book.author)
                    .font(.caption2)
                    .foregroundStyle(Color(hex: 0x68737A))
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

@MainActor
private struct BookCommentRow: View {
    let comment: BookCommentDTO
    let onBlocked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(comment.username)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: 0x0D3037))
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { value in
                        Image(systemName: value <= comment.rating ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: 0xD08A27))
                    }
                }
                .accessibilityLabel(L10n.bookCommentsRating(comment.rating))
                if let postID = Int(comment.id) {
                    UGCSafetyMenu(type: .bookComment, contentID: postID, userID: comment.userId, onBlocked: onBlocked)
                }
            }
            if !comment.message.isEmpty {
                Text(comment.message)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0x3E4A50))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xE4E9EA), lineWidth: 1)
        }
    }
}

private struct BookDetailHeroWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
