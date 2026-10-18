import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol AudioServing: Sendable {
    func catalog(filters: AudioFilters) async throws -> AudioCatalogDTO
    func detail(bookID: Int) async throws -> AudioDetailDTO
    func library(tab: AudioLibraryTab, account: String) async throws -> AudioLibraryDTO
    func manifest(bookID: Int, account: String) async throws -> AudioManifestDTO
    func saveProgress(_ write: AudioProgressWrite, account: String) async throws -> AudioProgressResponseDTO
    func shelf(bookID: Int, field: AudioShelfField, value: Bool, account: String) async throws
    func bookmark(bookID: Int, chapterID: Int, position: Double, label: String, account: String) async throws -> AudioBookmarkDTO
    func deleteBookmark(bookID: Int, bookmarkID: Int, account: String) async throws
}

/// The audiobook bridge shares the existing server's mobile-session table with IosApi. It never modifies
/// membership, login or purchase implementations. Every metadata/range read re-checks the captured account.
public final class AudioRepository: AudioServing, Sendable {
    public let baseURL: URL
    private let tokens: any SessionTokenManaging
    private let session: URLSession
    private let mediaTransport: AudioBoundedMediaTransport
    private let refresh: @Sendable (String) async throws -> String
    public init(webBaseURL: URL, tokens: any SessionTokenManaging, refresh: @escaping @Sendable (String) async throws -> String,
                session: URLSession? = nil) throws {
        baseURL = try AudioPolicy.baseURL(webBaseURL: webBaseURL); self.tokens = tokens; self.refresh = refresh
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false; configuration.urlCredentialStorage = nil
        configuration.urlCache = nil; configuration.timeoutIntervalForResource = 45; configuration.timeoutIntervalForRequest = 30
        let selectedSession = session ?? URLSession(configuration: configuration, delegate: AudioNoRedirects(), delegateQueue: nil)
        self.session = selectedSession
        self.mediaTransport = AudioBoundedMediaTransport(configuration: selectedSession.configuration)
    }
    public func catalog(filters: AudioFilters = .init()) async throws -> AudioCatalogDTO {
        try await request(path: "audio-books", query: filters.queryItems)
    }
    public func detail(bookID: Int) async throws -> AudioDetailDTO { try validate(bookID); return try await request(path: "audio-books/\(bookID)") }
    public func library(tab: AudioLibraryTab = .saved, account: String) async throws -> AudioLibraryDTO {
        try await request(path: "audio-library", account: account, query: [.init(name: "tab", value: tab.rawValue)])
    }
    public func manifest(bookID: Int, account: String) async throws -> AudioManifestDTO {
        try validate(bookID)
        let manifest: AudioManifestDTO = try await request(path: "audio-books/\(bookID)/manifest", account: account, fields: ["resume": "0"])
        guard manifest.book.id == bookID, manifest.book.canListen else { throw AudioError.premiumRequired }
        for chapter in manifest.chapters { _ = try AudioPolicy.streamURL(chapter.url, bookID: bookID, chapterID: chapter.id, baseURL: baseURL) }
        return manifest
    }
    public func saveProgress(_ write: AudioProgressWrite, account: String) async throws -> AudioProgressResponseDTO {
        try validate(write.bookID); try validate(write.chapterID)
        guard !write.session.isEmpty, write.sequence > 0, write.position.isFinite, write.position >= 0 else { throw AudioError.invalidInput }
        return try await request(path: "audio-books/\(write.bookID)/progress", account: account, fields: write.fields)
    }
    public func shelf(bookID: Int, field: AudioShelfField, value: Bool, account: String) async throws {
        try validate(bookID)
        let result: AudioMutationDTO = try await request(path: "audio-books/\(bookID)/shelf", account: account, fields: ["field": field.rawValue, "value": value ? "1" : "0"])
        guard result.saved else { throw AudioError.invalidResponse }
    }
    public func bookmark(bookID: Int, chapterID: Int, position: Double, label: String, account: String) async throws -> AudioBookmarkDTO {
        try validate(bookID); try validate(chapterID); guard position.isFinite, position >= 0 else { throw AudioError.invalidInput }
        return try await request(path: "audio-books/\(bookID)/bookmark", account: account,
            fields: ["chapter_id": String(chapterID), "position": String(position), "label": String(label.prefix(255))])
    }
    public func deleteBookmark(bookID: Int, bookmarkID: Int, account: String) async throws {
        try validate(bookID); try validate(bookmarkID)
        let result: AudioMutationDTO = try await request(path: "audio-books/\(bookID)/bookmark", account: account, fields: ["delete": String(bookmarkID)])
        guard result.deleted else { throw AudioError.invalidResponse }
    }
    public func mediaURL(bookID: Int, chapter: AudioChapterDTO) throws -> URL {
        try AudioPolicy.streamURL(chapter.url, bookID: bookID, chapterID: chapter.id, baseURL: baseURL)
    }
    public func mediaMetadata(bookID: Int, chapter: AudioChapterDTO, account: String) async throws -> AudioMediaMetadata {
        let url = try mediaURL(bookID: bookID, chapter: chapter)
        let captured = try await tokens.loadSession()
        guard captured?.username == account else { throw AudioError.authenticationRequired }
        let (_, response) = try await execute(url: url, account: account, method: "HEAD", media: true)
        guard Self.sameAccount(captured, try await tokens.loadSession()) else { throw AudioError.accountChanged }
        if try !AudioMediaMetadata.requiresRangeProbe(response: response) { return try AudioMediaMetadata(response: response) }
        // A single authenticated byte determines the representation size without trusting an optional
        // HEAD Content-Length or downloading a whole book. The transport rejects ignored/oversized ranges.
        let (data, probe) = try await execute(url: url, account: account, method: "GET", media: true, range: 0...0)
        guard Self.sameAccount(captured, try await tokens.loadSession()) else { throw AudioError.accountChanged }
        let metadata = try AudioMediaMetadata(probeResponse: probe, dataCount: data.count)
        if let length = response.value(forHTTPHeaderField: "Content-Length") {
            guard Int64(length.trimmingCharacters(in: .whitespacesAndNewlines)) == metadata.length else { throw AudioError.invalidRange }
        }
        return metadata
    }
    public func mediaData(bookID: Int, chapter: AudioChapterDTO, account: String, start: Int64, end: Int64) async throws -> Data {
        guard start >= 0, end >= start, end - start < AudioRangePolicy.chunkSize else { throw AudioError.invalidRange }
        let url = try mediaURL(bookID: bookID, chapter: chapter)
        let (data, response) = try await execute(url: url, account: account, method: "GET", media: true, range: start...end)
        try AudioRangePolicy.validate(response: response, dataCount: data.count, start: start, end: end); return data
    }
    public func isCurrent(account: String) async -> Bool { (try? await tokens.loadSession()?.username) == account }

    public func makeRequest(path: String, query: [URLQueryItem] = [], fields: [String: String]? = nil, token: String? = nil) throws -> URLRequest {
        let parts = path.split(separator: "/").map(String.init)
        let validPath = parts == ["audio-books"] || parts == ["audio-library"] ||
            (parts.first == "audio-books" && (parts.count == 2 || parts.count == 3) && (Int(parts[1]) ?? 0) > 0 &&
             (parts.count == 2 || ["manifest", "progress", "shelf", "bookmark", "stream"].contains(parts[2])))
        guard validPath, parts.joined(separator: "/") == path else { throw AudioError.invalidInput }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else { throw AudioError.invalidConfiguration }
        return try Self.makeRequest(url: url, method: fields == nil ? "GET" : "POST", fields: fields, token: token, media: false)
    }
    private static func makeRequest(url: URL, method: String, fields: [String: String]? = nil, token: String?, media: Bool) throws -> URLRequest {
        var request = URLRequest(url: url); request.httpMethod = method; request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData; request.timeoutInterval = 30
        request.setValue(media ? "audio/*,application/octet-stream" : "application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let token { guard AudioPolicy.validToken(token) else { throw AudioError.authenticationRequired }; request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if media { request.setValue("identity", forHTTPHeaderField: "Accept-Encoding") }
        if let fields {
            var encoded = URLComponents(); encoded.queryItems = fields.sorted { $0.key < $1.key }.map { .init(name: $0.key, value: $0.value) }
            request.httpBody = Data((encoded.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
    private func request<T: Decodable>(path: String, account: String? = nil, query: [URLQueryItem] = [], fields: [String: String]? = nil) async throws -> T {
        let request = try makeRequest(path: path, query: query, fields: fields)
        guard let url = request.url else { throw AudioError.invalidConfiguration }
        let (data, _) = try await execute(url: url, account: account, method: request.httpMethod ?? "GET", fields: fields)
        do { return try JSONDecoder().decode(T.self, from: data) } catch let error as AudioError { throw error } catch { throw AudioError.invalidResponse }
    }
    private func execute(url: URL, account: String?, method: String, fields: [String: String]? = nil,
                         media: Bool = false, range: ClosedRange<Int64>? = nil) async throws -> (Data, HTTPURLResponse) {
        let captured = try await tokens.loadSession()
        if let account, captured?.username != account { throw AudioError.authenticationRequired }
        for attempt in 0...1 {
            try Task.checkCancellation()
            let before = try await tokens.loadSession()
            guard Self.sameAccount(captured, before) else { throw AudioError.accountChanged }
            if account != nil && before == nil { throw AudioError.authenticationRequired }
            var request = try Self.makeRequest(url: url, method: method, fields: fields, token: before?.accessToken, media: media)
            if let range { request.setValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range") }
            let data: Data
            let response: URLResponse
            if media {
                let result = try await mediaTransport.data(for: request, range: range)
                data = result.0; response = result.1
            } else {
                let result = try await session.data(for: request)
                data = result.0; response = result.1
            }
            try Task.checkCancellation()
            guard Self.sameAccount(captured, try await tokens.loadSession()) else { throw AudioError.accountChanged }
            guard let http = response as? HTTPURLResponse, http.url == url else { throw AudioError.invalidResponse }
            if http.statusCode == 401, attempt == 0, let before {
                _ = try await refresh(before.accessToken)
                guard Self.sameAccount(captured, try await tokens.loadSession()) else { throw AudioError.accountChanged }; continue
            }
            guard (200..<300).contains(http.statusCode) else {
                switch http.statusCode {
                case 401: throw AudioError.authenticationRequired
                case 403: throw AudioError.premiumRequired
                case 409: throw AudioError.sessionConflict
                case 404, 503: throw AudioError.unavailable
                default: throw AudioError.server(http.statusCode)
                }
            }
            if !media, let failure = try? JSONDecoder().decode(AudioFailureDTO.self, from: data), failure.error != nil || !(failure.errors ?? []).isEmpty { throw AudioError.invalidResponse }
            return (data, http)
        }
        throw AudioError.authenticationRequired
    }
    private static func sameAccount(_ a: Session?, _ b: Session?) -> Bool {
        switch (a, b) { case (nil, nil): return true; case (.some(let a), .some(let b)): return a.belongsToSameAccount(as: b); default: return false }
    }
    private func validate(_ id: Int) throws { if id <= 0 { throw AudioError.invalidInput } }
}
private struct AudioMutationDTO: Decodable {
    let saved: Bool; let deleted: Bool
    init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: AudioKey.self); saved = c.flag("saved"); deleted = c.flag("deleted") }
}
private struct AudioFailureDTO: Decodable {
    struct Failure: Decodable { let code: String?; let message: String? }
    let error: Failure?; let errors: [Failure]?
}
private final class AudioNoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
