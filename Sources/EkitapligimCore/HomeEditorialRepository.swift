import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Reads the same public editor selection as Android; never creates an authenticated session.
public struct HomeEditorialRepository: Sendable {
    public let webBaseURL: URL
    private let session: URLSession

    public init(webBaseURL: URL, session: URLSession = .shared) {
        self.webBaseURL = webBaseURL
        self.session = session
    }

    public var requestURL: URL? {
        var components = URLComponents(url: webBaseURL.appendingPathComponent("books", isDirectory: true), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "featured", value: "1")]
        return components?.url
    }

    public func books() async throws -> [BookDTO] {
        guard let url = requestURL else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpShouldHandleCookies = false
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              data.count <= 8_000_000, let html = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return HomeEditorialCatalogParser.books(html: html, baseURL: webBaseURL)
    }
}

/// The source is the website's catalog cards, not the featured hero or arbitrary links.
public enum HomeEditorialCatalogParser {
    public static func books(html: String, baseURL: URL) -> [BookDTO] {
        guard let article = try? NSRegularExpression(pattern: #"<article\b[^>]*class=["'][^"']*\bxcuBktCatalog-card\b[^"']*["'][^>]*>[\s\S]*?</article>"#, options: [.caseInsensitive]) else { return [] }
        var seen = Set<String>()
        return article.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let range = Range(match.range, in: html) else { return nil }
            let card = String(html[range])
            guard let id = capture(#"href=["'][^"']*/(?:konular|threads)/[^"']*\.(\d+)/?["']"#, in: card), !seen.contains(id) else { return nil }
            let title = plain(capture(#"xcuBktCatalog-bookTitle[\s\S]*?<a\b[^>]*>([\s\S]*?)</a>"#, in: card) ?? capture(#"\balt=["']([^"']+)["']"#, in: card) ?? "")
            guard !title.isEmpty else { return nil }
            let author = plain(capture(#"class=["'][^"']*\bxcuBktCatalog-author\b[^"']*["'][^>]*>([\s\S]*?)</div>"#, in: card) ?? "")
            let cover = plain(capture(#"<img\b[^>]*\bsrc=["']([^"']+)["']"#, in: card) ?? "")
            let resolvedCover = cover.isEmpty ? "" : URL(string: cover, relativeTo: baseURL)?.absoluteURL.absoluteString ?? ""
            let category = plain(capture(#"xcuBktCatalog-tag[^>]*>([\s\S]*?)</span>"#, in: card) ?? "")
            let object: [String: Any] = ["id": id, "title": title, "author": author, "publisher": "", "isbn": "", "category": category, "language": "", "publishYear": "", "description": "", "coverUrl": resolvedCover, "pdfUrl": "", "pageCount": 0, "isPremiumOnly": card.range(of: "Premium", options: .caseInsensitive) != nil]
            guard let data = try? JSONSerialization.data(withJSONObject: object), let book = try? JSONDecoder().decode(BookDTO.self, from: data) else { return nil }
            seen.insert(id)
            return book
        }
    }

    private static func capture(_ pattern: String, in source: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]), let match = expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)), let range = Range(match.range(at: 1), in: source) else { return nil }
        return String(source[range])
    }

    private static func plain(_ source: String) -> String {
        var result = source.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
        for (entity, value) in ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "] {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        if let regex = try? NSRegularExpression(pattern: "&#(x[0-9a-fA-F]+|[0-9]+);") {
            for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
                guard let range = Range(match.range, in: result), let codeRange = Range(match.range(at: 1), in: result) else { continue }
                let code = String(result[codeRange])
                let number = code.first == "x" ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
                if let number, let scalar = UnicodeScalar(number) { result.replaceSubrange(range, with: String(scalar)) }
            }
        }
        return result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
