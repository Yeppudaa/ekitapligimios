#if DEBUG
import Foundation

/// Only the explicitly launched DEBUG UI harness can use these synthetic audio responses.
/// They are returned by its injected URLProtocol; no network transport or server mutation occurs.
enum ModernParityAudioFixture {
    static let markerHeader = "X-Ekitapligim-UI-Fixture"
    static let markerValue = "modern-parity-offline"
    static let token = "ms_at_offline_fixture_never_send_to_network"
    static let duration = 120
    private static let wave = makeSilentWave(seconds: duration)
    private static let lock = NSLock()
    private static var leases: [Int: (session: String, sequence: Int)] = [:]

    static var enabled: Bool {
        let process = ProcessInfo.processInfo
        return process.arguments.contains("-modern-parity-ui-fixture") &&
            (process.environment["MODERN_PARITY_SCREEN"] == "audio-player" || process.environment["MODERN_PARITY_PLAY_AUDIO"] == "1") &&
            process.environment["MODERN_PARITY_GUEST"] != "1" && process.environment["MODERN_PARITY_STANDARD_MEMBER"] != "1"
    }

    static func response(for request: URLRequest) -> (status: Int, headers: [String: String], data: Data)? {
        guard enabled, let url = request.url,
              url.scheme == "https", url.host == "ekitapligim.com", (url.port ?? 443) == 443,
              url.user == nil, url.password == nil, url.fragment == nil,
              request.value(forHTTPHeaderField: markerHeader) == markerValue else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 5, Array(parts.prefix(3)) == ["mobile-api", "v1", "audio-books"],
              let bookID = Int(parts[3]), [101, 102].contains(bookID),
              ["manifest", "progress", "stream"].contains(parts[4]) else { return nil }
        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)",
              request.value(forHTTPHeaderField: "Cookie") == nil else { return json(status: 401, ["error": ["code": "fixture_account_required"]]) }
        let action = parts[4]
        let method = request.httpMethod ?? "GET"
        if action == "manifest", method == "POST" {
            guard url.query == nil, request.fixtureAudioFields["resume"] == "0" else { return json(status: 400, ["success": false]) }
            let session = "offline-ui-lease-" + UUID().uuidString
            lock.lock(); leases[bookID] = (session, 0); lock.unlock()
            let chapter: [String: Any] = ["chapter_id": bookID * 10, "title": "Birinci Bölüm · Yerel test kaydı", "duration": duration, "display_order": 0,
                "url": "https://ekitapligim.com/mobile-api/v1/audio-books/\(bookID)/stream?chapter_id=\(bookID * 10)"]
            return json(["api_version": 1, "session": session, "sequence": 0, "state": ["chapter_id": bookID * 10, "position": 0, "speed": 1],
                "book": book(bookID), "chapters": [chapter], "bookmarks": [], "recommendations": [book(bookID == 101 ? 102 : 101)]])
        }
        if action == "progress", method == "POST" {
            guard url.query == nil else { return json(status: 400, ["success": false]) }
            let fields = request.fixtureAudioFields
            guard Int(fields["chapter_id"] ?? "") == bookID * 10,
                  let sequence = Int(fields["sequence"] ?? ""), sequence > 0,
                  let position = Double(fields["position"] ?? ""), position.isFinite, position >= 0, position <= Double(duration),
                  let speed = Double(fields["speed"] ?? ""), speed.isFinite, (0.5...2).contains(speed),
                  let listened = Double(fields["listened"] ?? ""), listened.isFinite, (0...60).contains(listened) else { return json(status: 400, ["success": false]) }
            lock.lock()
            guard let lease = leases[bookID], fields["session"] == lease.session, sequence > lease.sequence else {
                lock.unlock(); return json(status: 409, ["error": ["code": "audio_session_conflict"]])
            }
            leases[bookID] = (lease.session, sequence); lock.unlock()
            return json(["saved": true, "completed": false, "credited": listened,
                "state": ["chapter_id": bookID * 10, "position": position, "progress": position / Double(duration) * 100, "speed": speed]])
        }
        if action == "stream", method == "HEAD" || method == "GET" {
            guard URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems == [.init(name: "chapter_id", value: String(bookID * 10))],
                  request.value(forHTTPHeaderField: "Accept-Encoding") == "identity" else { return json(status: 400, ["success": false]) }
            if method == "HEAD" { return (200, ["Content-Type": "audio/wav", "Content-Length": String(wave.count), "Accept-Ranges": "bytes", "Cache-Control": "no-store"], Data()) }
            guard let range = request.value(forHTTPHeaderField: "Range"), range.hasPrefix("bytes=") else { return (416, ["Content-Range": "bytes */\(wave.count)"], Data()) }
            let rangeParts = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
            guard rangeParts.count == 2, let start = Int(rangeParts[0]), let end = Int(rangeParts[1]), start >= 0, end >= start,
                  start < wave.count, end - start < 512 * 1024 else { return (416, ["Content-Range": "bytes */\(wave.count)"], Data()) }
            let last = min(end, wave.count - 1)
            return (206, ["Content-Type": "audio/wav", "Content-Length": String(last - start + 1), "Content-Range": "bytes \(start)-\(last)/\(wave.count)",
                "Accept-Ranges": "bytes", "Cache-Control": "no-store"], wave.subdata(in: start..<(last + 1)))
        }
        return json(status: 405, ["success": false])
    }

    static func book(_ id: Int) -> [String: Any] {
        ["thread_id": id, "title": id == 101 ? "Beyaz Zambaklar Ülkesinde" : "Küçük Prens",
         "author": id == 101 ? "Grigori Petrov" : "Antoine de Saint-Exupéry", "narrator": "Yerel test kaydı",
         "description": "Bu ekran için cihazda üretilmiş sessiz bir test kaydı kullanılır. Ses dosyası sunucudan indirilmez.",
         "cover_url": "", "duration": duration, "duration_label": "2 dk", "language": "Türkçe", "publisher": "Yerel test",
         "can_listen": true, "chapter_count": 1, "categories": [["id": 1, "title": "Roman"]],
         "chapters": [["chapter_id": id * 10, "title": "Birinci Bölüm · Yerel test kaydı", "duration": duration]],
         "user_state": ["saved": true, "favorite": false, "progress": 0, "position": 0, "chapter_id": id * 10]]
    }
    private static func json(status: Int = 200, _ fields: [String: Any]) -> (Int, [String: String], Data) {
        (status, ["Content-Type": "application/json", "Cache-Control": "no-store"], (try? JSONSerialization.data(withJSONObject: fields)) ?? Data("{}".utf8))
    }
    /// Original, generated PCM silence: RIFF/WAVE, mono, 22,050 Hz, 16-bit. No external media assets.
    private static func makeSilentWave(seconds: Int) -> Data {
        let rate: UInt32 = 22_050, byteCount = UInt32(seconds) * 22_050 * 2
        var result = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { result.append(contentsOf: $0) }
        }
        append(UInt32(36) + byteCount); result.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1)); append(rate); append(rate * 2)
        append(UInt16(2)); append(UInt16(16)); result.append(contentsOf: "data".utf8); append(byteCount)
        result.append(Data(repeating: 0, count: Int(byteCount))); return result
    }
}

private extension URLRequest {
    var fixtureAudioFields: [String: String] {
        let data: Data
        if let httpBody { data = httpBody }
        else if let stream = httpBodyStream {
            stream.open(); defer { stream.close() }
            var collected = Data(), buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; collected.append(buffer, count: count) }
            data = collected
        } else { return [:] }
        var components = URLComponents(); components.percentEncodedQuery = String(data: data, encoding: .utf8)
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }
}
#endif
