import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AudioError: Error, Equatable, Sendable {
    case invalidConfiguration, invalidResponse, authenticationRequired, accountChanged, premiumRequired, sessionConflict, unavailable, invalidRange, invalidInput
    case server(Int)
}

public enum AudioPolicy {
    public static func finite(_ value: Double) -> Double { value.isFinite ? max(0, value) : 0 }
    public static func speed(_ value: Double) -> Double { value.isFinite ? min(2, max(0.5, value)) : 1 }
    public static func validToken(_ token: String) -> Bool {
        token.hasPrefix("ms_at_") && token.count > 6 && !token.unicodeScalars.contains { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }
    }
    public static func baseURL(webBaseURL: URL) throws -> URL {
        guard webBaseURL.scheme == "https", let host = webBaseURL.host?.lowercased(), ["ekitapligim.com", "www.ekitapligim.com"].contains(host),
              webBaseURL.user == nil, webBaseURL.password == nil, webBaseURL.query == nil, webBaseURL.fragment == nil,
              !webBaseURL.path.contains("..") else { throw AudioError.invalidConfiguration }
        return webBaseURL.appendingPathComponent("mobile-api/v1", isDirectory: true)
    }
    /// A manifest cannot send a bearer token to another origin, book, path, query or redirect.
    public static func streamURL(_ value: String, bookID: Int, chapterID: Int, baseURL: URL) throws -> URL {
        guard bookID > 0, chapterID > 0, let url = URL(string: value, relativeTo: baseURL)?.absoluteURL,
              url.scheme == baseURL.scheme, url.scheme == "https", url.host?.lowercased() == baseURL.host?.lowercased(),
              (url.port ?? 443) == (baseURL.port ?? 443), url.user == nil, url.password == nil, url.fragment == nil,
              url.path == baseURL.appendingPathComponent("audio-books/\(bookID)/stream").path,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 1, items[0].name == "chapter_id", Int(items[0].value ?? "") == chapterID else { throw AudioError.invalidResponse }
        return url
    }
    public static func annotation(kind: AudioAnnotationKind, text: String) throws -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw AudioError.invalidInput }
        let prefix: String
        switch kind { case .bookmark: prefix = ""; case .note: prefix = "Not: "; case .quote: prefix = "Alıntı: " }
        return prefix + String(value.prefix(255 - prefix.count))
    }
    public static func time(_ seconds: Double) -> String {
        let n = Int(min(finite(seconds), Double(Int32.max)))
        return n >= 3600 ? String(format: "%d:%02d:%02d", n / 3600, n / 60 % 60, n % 60) : String(format: "%d:%02d", n / 60, n % 60)
    }
}

/// Each playback manifest is a server lease. Writes reserve an increasing sequence before any suspension.
/// Only successfully acknowledged writes consume listening credit. A new lease never replays an old write.
public struct AudioProgressLedger: Equatable, Sendable {
    public private(set) var session = ""
    public private(set) var sequence = 0
    public private(set) var pendingSeconds: Double = 0
    private var reserved: [Int: Double] = [:]
    public init() {}
    public mutating func activate(session: String, sequence: Int) { self.session = session; self.sequence = max(0, sequence); pendingSeconds = 0; reserved = [:] }
    public mutating func accrue(elapsed: Double, playing: Bool) { if playing { pendingSeconds = min(60, pendingSeconds + min(1.5, AudioPolicy.finite(elapsed))) } }
    public mutating func reserve(bookID: Int, chapterID: Int, position: Double, speed: Double) throws -> AudioProgressWrite {
        guard !session.isEmpty, bookID > 0, chapterID > 0, sequence < Int.max else { throw AudioError.invalidInput }
        sequence += 1
        let credit = pendingSeconds; pendingSeconds = 0; reserved[sequence] = credit
        return AudioProgressWrite(bookID: bookID, session: session, sequence: sequence, chapterID: chapterID,
                                  position: AudioPolicy.finite(position), speed: AudioPolicy.speed(speed), listened: credit)
    }
    public mutating func acknowledged(_ write: AudioProgressWrite) {
        guard write.session == session else { return }; reserved.removeValue(forKey: write.sequence)
    }
    public mutating func failed(_ write: AudioProgressWrite) {
        guard write.session == session, let credit = reserved.removeValue(forKey: write.sequence) else { return }
        pendingSeconds = min(60, pendingSeconds + credit)
    }
}
public struct AudioProgressWrite: Equatable, Sendable {
    public let bookID: Int
    public let session: String
    public let sequence: Int
    public let chapterID: Int
    public let position: Double
    public let speed: Double
    public let listened: Double
    public var fields: [String: String] {
        ["session": session, "sequence": String(sequence), "chapter_id": String(chapterID), "position": String(position),
         "speed": String(speed), "listened": String(min(60, AudioPolicy.finite(listened)))]
    }
}

public struct AudioMediaMetadata: Equatable, Sendable {
    public let length: Int64
    public let mimeType: String
    public let supportsRanges: Bool
    public init(response: HTTPURLResponse) throws {
        guard response.statusCode == 200, let lengthString = response.value(forHTTPHeaderField: "Content-Length"),
              let length = Int64(lengthString), length > 0 else { throw AudioError.invalidRange }
        let type = response.value(forHTTPHeaderField: "Content-Type")?.lowercased().components(separatedBy: ";").first ?? ""
        guard type.hasPrefix("audio/") || type == "application/octet-stream" else { throw AudioError.invalidResponse }
        self.length = length; mimeType = type; supportsRanges = response.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased() == "bytes"
        guard supportsRanges else { throw AudioError.invalidRange }
    }
}
public enum AudioRangePolicy {
    public static let chunkSize: Int64 = 512 * 1024
    public static func validate(response: HTTPURLResponse, dataCount: Int, start: Int64, end: Int64) throws {
        guard start >= 0, end >= start, end - start < chunkSize, response.statusCode == 206,
              let range = response.value(forHTTPHeaderField: "Content-Range"), range.hasPrefix("bytes ") else { throw AudioError.invalidRange }
        let parts = range.dropFirst(6).split(separator: "/")
        guard parts.count == 2, let total = Int64(parts[1]), total > 0 else { throw AudioError.invalidRange }
        let bounds = parts[0].split(separator: "-")
        guard bounds.count == 2, let actualStart = Int64(bounds[0]), let actualEnd = Int64(bounds[1]), actualStart == start,
              actualEnd == min(end, total - 1), actualEnd >= start, actualEnd < total,
              Int64(dataCount) == actualEnd - actualStart + 1 else { throw AudioError.invalidRange }
    }
}
