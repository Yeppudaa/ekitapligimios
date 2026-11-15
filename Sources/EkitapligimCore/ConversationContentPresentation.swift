import Foundation

public struct ConversationLinkPresentation: Equatable, Sendable, Identifiable {
    public let url: URL
    public let isImage: Bool
    public var id: String { url.absoluteString }
    public var route: AppRoute? {
        guard ["ekitapligim.com", "www.ekitapligim.com"].contains(url.host?.lowercased() ?? "") else { return nil }
        return DeepLinkParser().parse(url.absoluteString)
    }
    public var bookID: Int? {
        guard case .bookDetail(let id) = route, id > 0 else { return nil }
        return id
    }
    /// Only the existing first-party public image surface is loaded inline.
    /// Other image links remain explicit browser actions, with no background third-party request.
    public var inlineImageURL: URL? {
        guard isImage, ["ekitapligim.com", "www.ekitapligim.com"].contains(url.host?.lowercased() ?? ""),
              ["jpg", "jpeg", "png", "webp", "gif"].contains(url.pathExtension.lowercased()) else { return nil }
        return url
    }
}

/// Converts forum markup to plain copy and native cards. Never interprets message text as code.
public struct ConversationContentPresentation: Equatable, Sendable {
    public let text: String
    public let links: [ConversationLinkPresentation]

    public init(_ raw: String) {
        var source = String(raw.prefix(100_000))
        source = Self.replace(source, pattern: #"<a\b[^>]*\bhref\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#, template: "[URL=$1]$2[/URL]")
        source = Self.replace(source, pattern: #"<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>"#, template: "[IMG]$1[/IMG]")
        source = Self.replace(source, pattern: #"\[/?EMBED[^\]]*\]"#, template: "")
        source = Self.replace(source, pattern: #"\[ATTACH[^\]]*\]\d+\[/ATTACH\]"#, template: ReadingRoomL10n.text("message.attachment"))
        var found: [ConversationLinkPresentation] = []
        func record(_ rawURL: String, image: Bool = false) {
            guard let url = Self.safeURL(rawURL), found.count < 10,
                  !found.contains(where: { $0.url == url }) else { return }
            found.append(ConversationLinkPresentation(url: url, isImage: image || ["jpg", "jpeg", "png", "webp", "gif"].contains(url.pathExtension.lowercased())))
        }
        if let regex = try? NSRegularExpression(pattern: #"\[(URL|IMG)(?:=([^\]]*)|\s[^\]]*)?\](.*?)\[/\1\]"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let original = source as NSString
            let matches = regex.matches(in: source, range: NSRange(location: 0, length: original.length))
            for match in matches {
                let kind = original.substring(with: match.range(at: 1)).uppercased()
                let body = Self.plain(original.substring(with: match.range(at: 3)))
                let target = match.range(at: 2).location != NSNotFound ? original.substring(with: match.range(at: 2)) : body
                record(target.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")), image: kind == "IMG")
            }
            for match in matches.reversed() {
                guard let range = Range(match.range, in: source) else { continue }
                let body = Self.plain(original.substring(with: match.range(at: 3)))
                let isImage = original.substring(with: match.range(at: 1)).uppercased() == "IMG"
                let rawTarget = match.range(at: 2).location != NSNotFound ? original.substring(with: match.range(at: 2)) : body
                let target = Self.safeURL(rawTarget.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")))
                let represented = target.map { url in found.contains(where: { $0.url == url }) } == true
                var replacement = represented && (isImage || Self.safeURL(body) != nil) ? " " : body
                if !represented, let target, Self.safeURL(body) != target {
                    replacement += " " + target.absoluteString
                }
                source.replaceSubrange(range, with: replacement)
            }
        }
        source = Self.plain(source)
        if let regex = try? NSRegularExpression(pattern: #"(?:https?://|www\.)[^\s<>\[\]"']+"#, options: [.caseInsensitive]) {
            let original = source as NSString
            let matches = regex.matches(in: source, range: NSRange(location: 0, length: original.length))
            for match in matches {
                var value = original.substring(with: match.range).trimmingCharacters(in: CharacterSet(charactersIn: ".,;!"))
                while value.hasSuffix(")") && value.filter({ $0 == ")" }).count > value.filter({ $0 == "(" }).count { value.removeLast() }
                record(value)
            }
            for match in matches.reversed() {
                var value = original.substring(with: match.range).trimmingCharacters(in: CharacterSet(charactersIn: ".,;!"))
                while value.hasSuffix(")") && value.filter({ $0 == ")" }).count > value.filter({ $0 == "(" }).count { value.removeLast() }
                if let url = Self.safeURL(value), found.contains(where: { $0.url == url }),
                   let range = Range(match.range, in: source) { source.replaceSubrange(range, with: " ") }
            }
        }
        self.text = Self.replace(source, pattern: #"[ \t]{2,}"#, template: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        self.links = found
    }

    public static func safeURL(_ raw: String) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "&amp;", with: "&")
        if value.hasPrefix("//") { value = "https:" + value }
        else if value.hasPrefix("/") { value = "https://ekitapligim.com" + value }
        else if value.lowercased().hasPrefix("www.") { value = "https://" + value }
        guard let url = URL(string: value), url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              let host = url.host?.lowercased(), host.contains("."),
              !host.hasSuffix(".local"), !host.hasSuffix(".localhost"), !host.hasSuffix(".internal"),
              !host.allSatisfy({ $0.isNumber || $0 == "." }), !host.contains(":"),
              !value.contains("\\") else { return nil }
        return url
    }

    private static func plain(_ raw: String) -> String {
        var value = replace(raw, pattern: #"<br\s*/?>|</p>"#, template: "\n")
        value = replace(value, pattern: #"<[^>]*>"#, template: "")
        value = replace(value, pattern: #"\[/?(?:B|I|U|S|COLOR|SIZE|FONT|QUOTE|SPOILER|CENTER|LEFT|RIGHT|LIST|INDENT|MEDIA|USER|ATTACH|ICODE|CODE|PLAIN|EMBED|IMG|URL)[^\]]*\]"#, template: "")
        value = replace(value, pattern: #"\[/?(?:EMBED|IMG|URL|ATTACH)\b[^\]]*$|\[/[A-Z]{1,8}(?:\.{3}|…)?$"#, template: "")
        for (entity, decoded) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#039;", "'"), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " "), ("&amp;", "&")] {
            value = value.replacingOccurrences(of: entity, with: decoded)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replace(_ value: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return value }
        return regex.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: template)
    }
}
