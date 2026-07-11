import Foundation

public enum AppRoute: Hashable, Sendable {
    case home
    case catalog
    case bookDetail(Int)
    case forum
    case forumDetail(Int)
    case thread(Int)
    case authors
    case publishers
    case requests
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

        let segments = route.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
        guard let first = segments.first?.lowercased() else { return nil }
        let id = segments.count == 2 ? Int(segments[1]) : nil

        switch first {
        case "home": return .home
        case "catalog": return .catalog
        case "detail": return id.map(AppRoute.bookDetail)
        case "forum": return id.map(AppRoute.forumDetail) ?? .forum
        case "thread": return id.map(AppRoute.thread)
        case "authors": return .authors
        case "publishers": return .publishers
        case "requests": return .requests
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
        guard let contentID, contentID > 0 else { return nil }
        switch type?.lowercased() {
        case "post", "thread", "forum_post": return .thread(contentID)
        default: return nil
        }
    }

    private static func trailingID(_ value: String) -> Int? {
        let digits = value.reversed().prefix(while: { $0.isNumber }).reversed()
        return Int(String(digits))
    }
}
