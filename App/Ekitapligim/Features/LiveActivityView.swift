import SwiftUI
import EkitapligimCore

/// Canlı Aktivite — cursor paginated activity stream with the CANLI badge.
@MainActor
struct LiveActivityView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    var userID: String?

    @StateObject private var model = LiveActivityModel()

    private struct Lifecycle: Hashable {
        let isActive: Bool
        let sessionID: UUID
        let userID: String?
    }

    private var lifecycle: Lifecycle {
        Lifecycle(isActive: scenePhase == .active, sessionID: container.sessionRevision, userID: userID)
    }

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    CommunityLiteraryHero(
                        artwork: "community_reader_salon",
                        artworkBehindCopy: true,
                        eyebrow: CommunityRefreshL10n.text("activity.eyebrow"),
                        title: CommunityRefreshL10n.text("activity.title"),
                        emphasis: CommunityRefreshL10n.text("activity.emphasis"),
                        subtitle: CommunityRefreshL10n.text("activity.body"),
                        actionTitle: CommunityRefreshL10n.text("activity.discover")
                    ) { withAnimation { proxy.scrollTo("activity-feed", anchor: .top) } }
                    ModernSectionHeading(title: CommunityRefreshL10n.text("activity.collection"))
                        .id("activity-feed")
                    content
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .refreshable { await model.load(reset: true) }
            .accessibilityIdentifier("live.scroll")
            }
        }
        .navigationTitle(L10n.liveActivityTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.load(reset: true) } } label: {
                    Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44)
                }.disabled(model.isLoading).accessibilityLabel(L10n.commonRefresh)
                    .accessibilityIdentifier("live.refresh")
            }
        }
        .task(id: lifecycle) {
            model.configure(repository: container.liveActivity, sessionID: container.sessionRevision, userID: userID)
            guard scenePhase == .active else { return }
            await model.load(reset: true)
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                guard !Task.isCancelled else { return }
                await model.refreshLatest()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioActivityChanged)) { _ in
            guard scenePhase == .active else { return }
            Task { await model.refreshLatest() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .libraryActivityChanged)) { _ in
            guard scenePhase == .active else { return }
            Task { await model.refreshLatest() }
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.items.isEmpty {
            EKSkeletonCard(height: 74)
            EKSkeletonCard(height: 74)
            EKSkeletonCard(height: 74)
        } else if let errorMessage = model.errorMessage, model.items.isEmpty {
            EKStateCard(
                title: L10n.liveActivityErrorTitle,
                message: errorMessage,
                retryTitle: L10n.commonRetry
            ) {
                Task { await model.load(reset: true) }
            }
        } else if model.items.isEmpty {
            EKStateCard(title: L10n.liveActivityEmptyTitle, message: L10n.liveActivityEmptySubtitle)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    LiveActivityRow(item: item, style: .timeline, showsConnector: index < model.items.count - 1)
                }
            }
            if let errorMessage = model.errorMessage {
                EKInlineError(message: errorMessage)
            }
            if model.hasMore {
                EKLoadMoreButton(isLoading: model.isLoadingMore, tint: EKitapligimPalette.liveRed) {
                    Task { await model.load(reset: false) }
                }
            }
        }
    }

}

// MARK: - Aktivite satırı

enum LiveActivityRowStyle {
    case standard
    case compact
    case timeline
}

struct LiveActivityRow: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: LiveActivityItemDTO
    var style: LiveActivityRowStyle = .standard
    var showsChevron: Bool = true
    var showsConnector: Bool = false

    private var kind: LiveActivityKind { LiveActivityKind(rawValue: item.type) }

    var body: some View {
        Button {
            openActivity()
        } label: {
            Group {
                switch style {
                case .timeline:
                    timelineRowContent
                case .compact, .standard:
                    rowContent
                }
            }
        }
        .buttonStyle(LiveActivityRowButtonStyle())
        .disabled(!hasDestination)
        .accessibilityLabel(hasDestination ? item.message : item.message)
        .accessibilityHint(kind.title)
        .accessibilityIdentifier("live.activity.\(item.id)")
    }

    private var timelineRowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(kind.tint.opacity(0.16))
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(kind.tint)
                        .frame(width: 10, height: 10)
                }
                if showsConnector {
                    Rectangle()
                        .fill(kind.tint.opacity(0.22))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 8) {
                activityBody
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EKitapligimPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(EKitapligimPalette.border)
            }
            .shadow(color: EKitapligimPalette.ink.opacity(0.04), radius: 8, y: 3)
            .padding(.bottom, showsConnector ? 14 : 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

            activityBody

            if showsChevron, hasDestination {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
        }
        .padding(style == .compact ? EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16) : EdgeInsets(top: 13, leading: 13, bottom: 13, trailing: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style == .compact ? AnyShapeStyle(Color.clear) : AnyShapeStyle(EKitapligimPalette.paper))
        .clipShape(RoundedRectangle(cornerRadius: style == .compact ? 0 : 15, style: .continuous))
        .overlay {
            if style != .compact {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(EKitapligimPalette.border)
            }
        }
        .shadow(color: style == .compact ? .clear : EKitapligimPalette.ink.opacity(0.04), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }

    private var activityBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))) {
                Text(kind.title)
                    .font(.caption2.weight(.heavy))
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
                .font(style == .compact ? .caption : .subheadline)
                .foregroundStyle(EKitapligimPalette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let book = item.book, !book.title.isEmpty {
                HStack(spacing: 8) {
                    EKitapligimRemoteCover(urlString: book.coverUrl ?? "", title: book.title, author: book.author)
                        .frame(width: 26, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        if !book.author.isEmpty {
                            Text(book.author)
                                .font(.caption2)
                                .foregroundStyle(EKitapligimPalette.muted)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(EKitapligimPalette.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }

    private var hasDestination: Bool {
        resolvedRoute != nil || bookID != nil
    }

    private var resolvedRoute: AppRoute? {
        item.nativeDestination
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
    case wantToRead
    case favorite
    case listening
    case audioFavorite
    case audioSaved
    case audioLater
    case audioCompleted
    case premium
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
        case "audio_listening_started", "audiobook_listening_started", "audio_started", "listening", "audio_progress", "audiobook_progress", "audio_shelf_changed": self = .listening
        case "audio_favorite", "audio_favorite_added", "audiobook_favorite", "audiobook_favorite_added": self = .audioFavorite
        case "audio_saved": self = .audioSaved
        case "audio_later": self = .audioLater
        case "audio_completed", "audiobook_completed": self = .audioCompleted
        case "premium", "premium_upgrade", "user_upgrade": self = .premium
        case "reading", "reading_progress", "progress": self = .reading
        case "want_to_read": self = .wantToRead
        case "favorite", "favorite_added", "book_favorite": self = .favorite
        case "read", "finished", "book_finished", "completed": self = .finished
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
        case .listening: CommunityRefreshL10n.text("activity.listening")
        case .audioFavorite: CommunityRefreshL10n.text("activity.audioFavorite")
        case .audioSaved: CommunityRefreshL10n.text("activity.audioSaved")
        case .audioLater: CommunityRefreshL10n.text("activity.audioLater")
        case .audioCompleted: CommunityRefreshL10n.text("activity.audioCompleted")
        case .premium: CommunityRefreshL10n.text("activity.premium")
        case .reading: L10n.liveActivityTypeReading
        case .wantToRead: L10n.libraryTabWantToRead
        case .favorite: L10n.libraryShelfFavorites
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
        case .listening: "headphones"
        case .audioFavorite: "heart.fill"
        case .audioSaved: "bookmark.fill"
        case .audioLater: "headphones"
        case .audioCompleted: "checkmark.circle.fill"
        case .premium: "crown.fill"
        case .reading: "book.pages.fill"
        case .wantToRead: "clock.fill"
        case .favorite: "heart.fill"
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
        case .listening: EKitapligimPalette.teal
        case .audioFavorite: EKitapligimPalette.liveRed
        case .audioSaved, .audioLater: EKitapligimPalette.teal
        case .audioCompleted: EKitapligimPalette.success
        case .premium: EKitapligimPalette.gold
        case .reading: EKitapligimPalette.teal
        case .wantToRead: EKitapligimPalette.teal
        case .favorite: EKitapligimPalette.liveRed
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

private struct LiveActivityRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
