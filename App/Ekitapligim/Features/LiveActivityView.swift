import SwiftUI
import EkitapligimCore

/// Canlı Aktivite — cursor paginated activity stream with the CANLI badge.
@MainActor
struct LiveActivityView: View {
    @EnvironmentObject private var container: AppContainer
    var userID: String?

    @State private var items: [LiveActivityItemDTO] = []
    @State private var nextBefore: Int?
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    hero
                    content
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .refreshable { await load(reset: true) }
        }
        .navigationTitle(L10n.liveActivityTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(reset: true) }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                EKLiveBadge()
                Text(L10n.liveActivitySubtitle)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                Text(L10n.liveActivityHeroBody)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [EKitapligimPalette.liveRed, EKitapligimPalette.liveOrange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder private var content: some View {
        if isLoading && items.isEmpty {
            EKSkeletonCard(height: 74)
            EKSkeletonCard(height: 74)
            EKSkeletonCard(height: 74)
        } else if let errorMessage, items.isEmpty {
            EKStateCard(
                title: L10n.liveActivityErrorTitle,
                message: errorMessage,
                retryTitle: L10n.commonRetry
            ) {
                Task { await load(reset: true) }
            }
        } else if items.isEmpty {
            EKStateCard(title: L10n.liveActivityEmptyTitle, message: L10n.liveActivityEmptySubtitle)
        } else {
            ForEach(items) { item in
                LiveActivityRow(item: item)
            }
            if hasMore {
                EKLoadMoreButton(isLoading: isLoadingMore, tint: EKitapligimPalette.liveRed) {
                    Task { await load(reset: false) }
                }
            }
        }
    }

    private func load(reset: Bool) async {
        if reset {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore, hasMore, nextBefore != nil else { return }
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        errorMessage = nil
        do {
            let page = try await container.liveActivity.activity(
                limit: 20,
                before: reset ? nil : nextBefore,
                userID: userID
            )
            if reset {
                items = page.items
            } else {
                let existing = Set(items.map(\.id))
                items += page.items.filter { !existing.contains($0.id) }
            }
            nextBefore = page.nextBefore
            hasMore = page.hasMore && page.nextBefore != nil
        } catch {
            errorMessage = L10n.liveActivityLoadFailed
            if reset { items = [] }
        }
    }
}

// MARK: - Aktivite satırı

struct LiveActivityRow: View {
    @EnvironmentObject private var container: AppContainer
    let item: LiveActivityItemDTO
    var showsChevron: Bool = true

    private var kind: LiveActivityKind { LiveActivityKind(rawValue: item.type) }

    var body: some View {
        Button {
            openActivity()
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .disabled(!hasDestination)
        .accessibilityLabel(hasDestination ? item.message : item.message)
        .accessibilityHint(kind.title)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(kind.tint.opacity(0.14))
                Image(systemName: kind.systemImage)
                    .font(.caption)
                    .foregroundStyle(kind.tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(kind.title)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(kind.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(kind.tint.opacity(0.12), in: Capsule())
                    Spacer(minLength: 0)
                    Text(EKitapligimFormat.relativeTime(item.eventDate))
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.muted)
                }

                Text(EKitapligimFormat.plainText(item.message))
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let book = item.book, !book.title.isEmpty {
                    HStack(spacing: 8) {
                        EKitapligimRemoteCover(urlString: book.coverUrl ?? "")
                            .frame(width: 26, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(book.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.ink)
                                .lineLimit(1)
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.system(size: 10))
                                    .foregroundStyle(EKitapligimPalette.muted)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(EKitapligimPalette.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }

            if showsChevron, hasDestination {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 15)
        .accessibilityElement(children: .combine)
    }

    private var hasDestination: Bool {
        resolvedRoute != nil || bookID != nil
    }

    private var resolvedRoute: AppRoute? {
        DeepLinkParser().parseNotification(
            appRoute: item.appRoute,
            targetURL: item.targetUrl,
            contentID: Int(item.id),
            type: item.type
        )
    }

    private func openActivity() {
        if let route = resolvedRoute {
            container.open(route: route)
        } else if let bookID {
            container.open(route: .bookDetail(bookID))
        }
    }

    private var bookID: Int? {
        guard let raw = item.book?.id else { return nil }
        return Int(raw)
    }
}

/// Android renders one colour and label per activity type; unknown types fall back to a neutral style.
enum LiveActivityKind {
    case reading
    case finished
    case review
    case comment
    case agenda
    case chat
    case member
    case request
    case other

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "reading", "reading_progress", "progress": self = .reading
        case "finished", "book_finished", "completed": self = .finished
        case "review", "book_review", "rating": self = .review
        case "comment", "book_comment", "post": self = .comment
        case "agenda", "book_agenda", "agenda_post": self = .agenda
        case "chat", "chat_message": self = .chat
        case "member", "new_member", "registration": self = .member
        case "request", "book_request": self = .request
        default: self = .other
        }
    }

    var title: String {
        switch self {
        case .reading: L10n.liveActivityTypeReading
        case .finished: L10n.liveActivityTypeRead
        case .review: L10n.liveActivityTypeReview
        case .comment: L10n.liveActivityTypeComment
        case .agenda: L10n.liveActivityTypeAgenda
        case .chat: L10n.liveActivityTypeChat
        case .member: L10n.liveActivityTypeJoin
        case .request: L10n.liveActivityTypeRequest
        case .other: L10n.liveActivityTypeGeneric
        }
    }

    var systemImage: String {
        switch self {
        case .reading: "book.pages.fill"
        case .finished: "checkmark.seal.fill"
        case .review: "star.fill"
        case .comment: "bubble.right.fill"
        case .agenda: "square.text.square.fill"
        case .chat: "bubble.left.and.text.bubble.right.fill"
        case .member: "person.crop.circle.badge.plus"
        case .request: "tray.and.arrow.down.fill"
        case .other: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .reading: EKitapligimPalette.teal
        case .finished: EKitapligimPalette.success
        case .review: EKitapligimPalette.gold
        case .comment: EKitapligimPalette.agendaPurple
        case .agenda: EKitapligimPalette.agendaPurple
        case .chat: EKitapligimPalette.chatTeal
        case .member: EKitapligimPalette.liveOrange
        case .request: EKitapligimPalette.liveRed
        case .other: EKitapligimPalette.muted
        }
    }
}
