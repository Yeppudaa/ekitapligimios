#if DEBUG
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Explicitly enabled, in-memory library responses for the shipping UI's mutation regressions.
/// URLProtocol returns these bytes locally; no favorite, shelf or activity request reaches a server.
enum ModernParityLibraryFixture {
    private static let lock = NSLock()
    private static var seeded = false
    private static var library: [[String: Any]] = []
    private static var activity: [[String: Any]] = []
    private static var book: [String: Any] = [:]
    private static let bookID = "900042"
    private static let actorID = "900001"
    private static let username = "parity-fixture"

    static var enabled: Bool {
        let process = ProcessInfo.processInfo
        return process.arguments.contains("-modern-parity-ui-fixture") &&
            ["success", "failure"].contains(process.environment["MODERN_PARITY_LIBRARY_MUTATIONS"] ?? "")
    }

    static func seed(book: [String: Any], library initialLibrary: [[String: Any]]) {
        guard enabled else { return }
        lock.lock()
        defer { lock.unlock() }
        guard !seeded else { return }
        seeded = true
        self.book = book
        var item: [String: Any] = [
            "book_id": bookID, "shelf_state": "NONE", "is_favorite": false,
            "progress_percent": 0, "last_read_page": 0, "last_read_at": 0,
            "is_downloaded": false, "position_type": "pdf"
        ]
        for key in ["title", "author", "cover_url", "page_count"] { item[key] = book[key] }
        library = [item] + initialLibrary.filter { String(describing: $0["book_id"] ?? "") != bookID }
        activity = []
    }

    static func response(for request: URLRequest) -> (status: Int, headers: [String: String], data: Data)? {
        // Development uses a reserved invalid host. Both origins remain local URLProtocol responses
        // and are accepted only with the explicit DEBUG launch flag and fixture marker.
        guard enabled, let url = request.url,
              url.scheme == "https", ["ekitapligim.com", "ekitapligim.local.invalid"].contains(url.host ?? ""),
              (url.port ?? 443) == 443,
              url.user == nil, url.password == nil, url.fragment == nil,
              request.value(forHTTPHeaderField: ModernParityAudioFixture.markerHeader) == ModernParityAudioFixture.markerValue else { return nil }
        let path = url.path
        let method = request.httpMethod ?? "GET"
        guard path == "/ios-api/v1/me/library" || path == "/ios-api/v1/me/library/\(bookID)" ||
                path == "/ios-api/v1/live-activity" else { return nil }
        if path == "/ios-api/v1/live-activity", method == "GET" {
            lock.lock()
            let rows = activity
            lock.unlock()
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let requestedUser = query.first { $0.name == "user_id" }?.value
            let limit = max(1, min(50, Int(query.first { $0.name == "limit" }?.value ?? "20") ?? 20))
            let visible = requestedUser == nil || requestedUser == actorID ? Array(rows.prefix(limit)) : []
            return json(["items": visible, "pagination": ["has_more": false]])
        }
        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(ModernParityAudioFixture.token)",
              request.value(forHTTPHeaderField: "Cookie") == nil else {
            return json(status: 401, ["success": false, "errors": ["Offline fixture account required."]])
        }
        if path == "/ios-api/v1/me/library", method == "GET" {
            lock.lock()
            let items = library
            lock.unlock()
            return json(["items": items])
        }
        guard path == "/ios-api/v1/me/library/\(bookID)", method == "PUT", url.query == nil,
              let fields = request.fixtureLibraryFields else {
            return json(status: 405, ["success": false, "errors": ["Unsupported offline fixture mutation."]])
        }
        lock.lock()
        defer { lock.unlock() }
        guard let index = library.firstIndex(where: { ($0["book_id"] as? String) == bookID }) else {
            return json(status: 404, ["success": false])
        }
        if Set(fields.keys) == ["is_favorite"], ["0", "1"].contains(fields["is_favorite"] ?? "") {
            if ProcessInfo.processInfo.environment["MODERN_PARITY_LIBRARY_MUTATIONS"] == "failure" {
                // A transport-level 200 must still reject an explicitly unacknowledged mutation.
                return json(["success": false])
            }
            let value = fields["is_favorite"] == "1"
            let wasFavorite = library[index]["is_favorite"] as? Bool ?? false
            library[index]["is_favorite"] = value
            if value && !wasFavorite { publish(type: "favorite", verb: "favorilerine ekledi") }
            return json(["success": true])
        }
        guard Set(fields.keys) == ["shelf_state", "progress_percent", "last_read_page"],
              let state = fields["shelf_state"], ["NONE", "OKUYORUM", "OKUYACAGIM", "OKUDUM"].contains(state),
              let percent = Int(fields["progress_percent"] ?? ""), (0...100).contains(percent),
              let page = Int(fields["last_read_page"] ?? ""), page >= 0 else {
            return json(status: 400, ["success": false, "errors": ["Invalid offline library fields."]])
        }
        let previous = library[index]["shelf_state"] as? String ?? "NONE"
        library[index]["shelf_state"] = state
        library[index]["progress_percent"] = percent
        library[index]["last_read_page"] = page
        if state == "OKUYORUM", previous != state {
            library[index]["last_read_at"] = Int(Date().timeIntervalSince1970)
            publish(type: "reading", verb: "okumaya başladı")
        }
        return json(["success": true])
    }

    /// Called while holding the fixture lock, only after its canonical mutation succeeds.
    private static func publish(type: String, verb: String) {
        let title = book["title"] as? String ?? "Book"
        let reference: [String: Any] = ["id": bookID, "title": title,
            "author": book["author"] as? String ?? "", "cover_url": book["cover_url"] as? String ?? ""]
        activity.insert([
            "id": "library-\(type)-\(bookID)", "type": type,
            "message": "\(username) \(title) kitabını \(verb).",
            "event_date": Int(Date().timeIntervalSince1970),
            "actor": ["id": actorID, "username": username], "book": reference,
            "app_route": "book/\(bookID)"
        ], at: 0)
    }

    private static func json(status: Int = 200, _ fields: [String: Any]) -> (Int, [String: String], Data) {
        (status, ["Content-Type": "application/json", "Cache-Control": "no-store"],
         (try? JSONSerialization.data(withJSONObject: fields)) ?? Data("{}".utf8))
    }
}

private extension URLRequest {
    var fixtureLibraryFields: [String: String]? {
        let data: Data
        if let httpBody { data = httpBody }
        else if let stream = httpBodyStream {
            stream.open()
            defer { stream.close() }
            var collected = Data(), buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count < 0 { return nil }
                if count == 0 { break }
                guard collected.count + count <= 8192 else { return nil }
                collected.append(buffer, count: count)
            }
            data = collected
        } else { return nil }
        guard data.count <= 8192, let encoded = String(data: data, encoding: .utf8),
              let components = URLComponents(string: "https://fixture.invalid/?" + encoded), components.fragment == nil else { return nil }
        let items = components.queryItems ?? []
        guard Set(items.map(\.name)).count == items.count else { return nil }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}
#endif
