import Foundation

/// Mirrors the Android `AppRoutes` table so both apps resolve the same deep links.
public enum AppRoute: Hashable, Identifiable, Sendable {
    case home
    case login
    case catalog
    case bookDetail(Int)
    case reader(Int)
    case forum
    case forumDetail(Int)
    case thread(Int)
    case authors
    case publishers
    case requests
    case bookAgenda
    case bookAgendaPost(Int)
    case chat
    case chatRoom(Int)
    case liveActivity
    case members
    case member(Int)
    case messages
    case conversation(Int)
    case notifications
    case profile
    case profileEdit
    case library(tab: Int)
    case stats
    case myComments
    case premium

    public var id: String { nativeRoute }

    /// The Android-compatible native route string, used for notification payload parity.
    public var nativeRoute: String {
        switch self {
        case .home: "home"
        case .login: "login"
        case .catalog: "catalog"
        case .bookDetail(let id): "detail/\(id)"
        case .reader(let id): "reader/\(id)"
        case .forum: "forum"
        case .forumDetail(let id): "forum/\(id)"
        case .thread(let id): "thread/\(id)"
        case .authors: "authors"
        case .publishers: "publishers"
        case .requests: "requests"
        case .bookAgenda: "book-agenda"
        case .bookAgendaPost(let id): "book-agenda/\(id)"
        case .chat: "chat"
        case .chatRoom(let id): "chat/\(id)"
        case .liveActivity: "live-activity"
        case .members: "members"
        case .member(let id): "member/\(id)"
        case .messages: "messages"
        case .conversation(let id): "conversation/\(id)"
        case .notifications: "notifications"
        case .profile: "profile"
        case .profileEdit: "profile/edit"
        case .library(let tab): "library/\(tab)"
        case .stats: "stats"
        case .myComments: "my-comments"
        case .premium: "premium"
        }
    }

    /// Routes that require a signed-in session before they can show anything useful.
    public var requiresAuthentication: Bool {
        switch self {
        case .profile, .profileEdit, .library, .stats, .myComments, .notifications, .messages, .conversation:
            true
        default:
            false
        }
    }
}

public struct DeepLinkParser: Sendable {
    public init() {}

    public func parse(_ rawURL: String) -> AppRoute? {
        guard let url = URL(string: rawURL) else { return nil }
        let host = (url.host ?? "").replacingOccurrences(of: "www.", with: "")
        if !host.isEmpty, host.lowercased() != "ekitapligim.com" { return nil }
        let segments = url.path.split(separator: "/").map(String.init)
        guard let first = segments.first?.lowercased() else { return host.isEmpty ? nil : .home }
        let id = segments.last.flatMap(Self.trailingID)

        switch first {
        case "books", "konular":
            return id.map(AppRoute.bookDetail) ?? .catalog
        case "threads":
            return id.map(AppRoute.thread) ?? .forum
        case "forum", "forums":
            return id.map(AppRoute.forumDetail) ?? .forum
        case "live-activity":
            return .liveActivity
        case "kitap-gundemi":
            return id.map(AppRoute.bookAgendaPost) ?? .bookAgenda
        case "chat":
            let roomID = segments.dropFirst().compactMap(Self.trailingID).first
            return roomID.map(AppRoute.chatRoom) ?? .chat
        case "kullanicilar", "members":
            return id.map(AppRoute.member) ?? .members
        case "book-authors", "authors":
            return .authors
        case "book-publishers", "publishers":
            return .publishers
        case "book-requests":
            return .requests
        default:
            return nil
        }
    }

    public func parseNativeRoute(_ rawRoute: String?) -> AppRoute? {
        guard let route = rawRoute?.trimmingCharacters(in: .whitespacesAndNewlines), !route.isEmpty else {
            return nil
        }
        if route.contains("://") { return nil }

        let normalized = route.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let segments = normalized.split(separator: "/").map(String.init)
        guard let first = segments.first else { return nil }
        let id = segments.count == 2 ? Int(segments[1]) : nil

        if normalized == "profile/edit" { return .profileEdit }
        if normalized == "my-comments" { return .myComments }
        if normalized == "live-activity" { return .liveActivity }

        switch first {
        case "home": return .home
        case "login": return .login
        case "catalog": return .catalog
        case "detail": return id.map(AppRoute.bookDetail)
        case "reader": return id.map(AppRoute.reader)
        case "forum": return id.map(AppRoute.forumDetail) ?? (segments.count == 1 ? .forum : nil)
        case "thread": return id.map(AppRoute.thread)
        case "authors": return .authors
        case "publishers": return .publishers
        case "requests": return .requests
        case "book-agenda": return id.map(AppRoute.bookAgendaPost) ?? (segments.count == 1 ? .bookAgenda : nil)
        case "chat": return id.map(AppRoute.chatRoom) ?? (segments.count == 1 ? .chat : nil)
        case "members": return .members
        case "member": return id.map(AppRoute.member)
        case "messages": return .messages
        case "conversation": return id.map(AppRoute.conversation)
        case "notifications": return .notifications
        case "profile": return segments.count == 1 ? .profile : nil
        case "library": return .library(tab: id ?? 0)
        case "stats": return .stats
        case "premium": return .premium
        default: return nil
        }
    }

    public func parseNotification(
        appRoute: String?,
        targetURL: String?,
        contentID: Int? = nil,
        type: String? = nil
    ) -> AppRoute? {
        if let route = parseNativeRoute(appRoute) { return route }
        if let targetURL, let route = parse(targetURL) { return route }
        guard let contentID, contentID > 0 else {
            return type?.lowercased().hasPrefix("chat") == true ? .chat : nil
        }
        switch type?.lowercased() {
        case "post", "thread", "forum_post":
            return .thread(contentID)
        case "book_agenda", "social_post", "kitap_gundemi":
            return .bookAgendaPost(contentID)
        case "chat", "chat_message", "siropu_chat_room_message":
            return .chatRoom(contentID)
        default:
            return nil
        }
    }

    private static func trailingID(_ value: String) -> Int? {
        let digits = value.reversed().prefix(while: { $0.isNumber }).reversed()
        return Int(String(digits))
    }
}
