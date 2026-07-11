import Foundation

public enum AppRoute: Equatable, Sendable {
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

    private static func trailingID(_ value: String) -> Int? {
        let digits = value.reversed().prefix(while: { $0.isNumber }).reversed()
        return Int(String(digits))
    }
}
