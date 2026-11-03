import Foundation

public extension LiveActivityItemDTO {
    var memberDestination: AppRoute? {
        guard let value = actor?.id, let id = Int(value), id > 0, id <= Int32.max else { return nil }
        return .member(id)
    }

    /// A book-name tap is independent of the event's forum/profile destination.
    var bookDestination: AppRoute? {
        let parser = DeepLinkParser()
        let native = parser.parseNativeRoute(appRoute)
        let web = targetUrl.flatMap { parser.parse($0) }
        let hasAudioRoute: Bool = [native, web].contains { if case .audiobook = $0 { return true }; return false }
        let audio = ActivityPresentation.audioTypes.contains(type.lowercased())
            || ["audio", "audiobook", "audio_book"].contains(contentType?.lowercased() ?? "")
            || audioBookId?.isEmpty == false || hasAudioRoute
        let audioID = audioBookId.flatMap { $0.isEmpty ? nil : $0 }
        if let value = audio ? (audioID ?? book?.id) : book?.id,
           let id = Int(value), id > 0, id <= Int32.max {
            return audio ? .audiobook(id) : .bookDetail(id)
        }
        for route in [native, web] {
            if case .audiobook(let id) = route, id > 0, id <= Int32.max { return .audiobook(id) }
            if !audio, case .bookDetail(let id) = route, id > 0, id <= Int32.max { return .bookDetail(id) }
        }
        return nil
    }
}

public struct ActivityTextRun: Equatable, Sendable {
    public let text: String
    public let route: AppRoute?
}

public enum ActivityLinks {
    /// Only known actor/book labels receive native links; text can never inject an external URL.
    public static func runs(message: String, actor: String, memberRoute: AppRoute?, book: String, bookRoute: AppRoute?) -> [ActivityTextRun] {
        func find(_ phrase: String, after start: String.Index? = nil) -> Range<String.Index>? {
            guard !phrase.isEmpty else { return nil }
            var start = start ?? message.startIndex
            while start < message.endIndex, let range = message.range(of: phrase, range: start..<message.endIndex) {
                let before = range.lowerBound > message.startIndex ? message[message.index(before: range.lowerBound)] : nil
                let after = range.upperBound < message.endIndex ? message[range.upperBound] : nil
                if before?.isLetter != true && before?.isNumber != true && after?.isLetter != true && after?.isNumber != true {
                    return range
                }
                start = range.upperBound
            }
            return nil
        }
        var member = memberRoute == nil ? nil : find(actor)
        var title = bookRoute == nil ? nil : find(book)
        if let actorRange = member, let bookRange = title, actorRange.overlaps(bookRange) {
            if actor == book { title = find(book, after: actorRange.upperBound) }
            else { member = find(actor, after: bookRange.upperBound) }
        }
        var links: [(Range<String.Index>, AppRoute)] = []
        if let member, let memberRoute { links.append((member, memberRoute)) }
        if let title, let bookRoute { links.append((title, bookRoute)) }
        links.sort { $0.0.lowerBound < $1.0.lowerBound }
        var cursor = message.startIndex
        var result: [ActivityTextRun] = []
        for (range, route) in links {
            if cursor < range.lowerBound { result.append(.init(text: String(message[cursor..<range.lowerBound]), route: nil)) }
            result.append(.init(text: String(message[range]), route: route))
            cursor = range.upperBound
        }
        if cursor < message.endIndex { result.append(.init(text: String(message[cursor...]), route: nil)) }
        return result
    }
}
