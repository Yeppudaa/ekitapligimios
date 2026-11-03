#if DEBUG
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Opt-in, local-only media contract for the shipping SwiftUI screens. No live writes.
enum ModernParityAgendaMediaFixture {
    static var mode: String { ProcessInfo.processInfo.environment["MODERN_PARITY_AGENDA_MEDIA"] ?? "" }
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-modern-parity-ui-fixture") && !mode.isEmpty }
    static var photo: Data { photo(for: mode) }
    private static func photo(for mode: String) -> Data {
        let portrait = "iVBORw0KGgoAAAANSUhEUgAAACgAAABQCAIAAADk7aCWAAAAQUlEQVR4nO3NIREAAAgEMEJ8TjTxsTTA7G5+lZ4XJRaLxWKxWCwWi8VisVgsFovFYrFYLBaLxWKxWCwWi8XinHgB0h41tZ2zJqoAAAAASUVORK5CYII="
        let landscape = "iVBORw0KGgoAAAANSUhEUgAAAFAAAAAoCAIAAADmAupWAAAAS0lEQVR4nO3PAQkAIBDAQDOZzkymNIawP1iA3bpnj2p9PwAGBgYGBgYeE3A94HrA9YDrAdcDrgdcD7gecD3gesD1gOsB1wOuB3ziPdutmvE3VPJSAAAAAElFTkSuQmCC"
        return Data(base64Encoded: mode == "landscape" ? landscape : portrait) ?? Data()
    }
    static var attachments: [[String: Any]] { attachments(for: mode) }
    private static func attachments(for mode: String) -> [[String: Any]] {
        (1...(mode == "gallery" ? 2 : 1)).map { index in
            ["id": String(20 + index), "url": "", "thumbnail_url": "", "protected_image": true,
             "width": mode == "landscape" ? 80 : 40, "height": mode == "landscape" ? 40 : 80]
        }
    }
    static func response(for request: URLRequest) -> (status: Int, mime: String, data: Data)? {
        guard enabled else { return nil }
        return response(for: request, scenario: mode)
    }

    // The Development app deliberately uses a non-resolving API origin. The offline
    // transport must recognize it as well as Production; otherwise generic feed JSON
    // silently replaces media capabilities and image bytes during native UI tests.
    static func response(for request: URLRequest, scenario mode: String) -> (status: Int, mime: String, data: Data)? {
        guard let url = request.url, url.scheme == "https",
              ["ekitapligim.com", "ekitapligim.local.invalid", "staging.ekitapligim.com"].contains(url.host ?? ""),
              (url.port ?? 443) == 443, url.user == nil, url.password == nil else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let readOnly = request.httpMethod == nil || request.httpMethod == "GET"
        if readOnly, url.path.contains("/book-agenda/"), query.contains(where: { $0.name == "image_id" }) {
            return mode == "failure" ? (503, "application/json", Data()) : (200, "image/png", photo(for: mode))
        }
        if readOnly, url.path.hasSuffix("/book-agenda"), query.contains(.init(name: "media_capabilities", value: "1")) {
            return json(mode == "unsupported" ? ["items": []] : ["image_upload_version": 1, "can_upload_images": true, "maximum_bytes": 8388608])
        }
        if request.httpMethod == "POST", url.path.hasSuffix("/book-agenda") {
            if mode == "upload-failure" { return json(["errors": [["code": "upload_failed", "message": "Fotoğraf yüklenemedi."]]], status: 503) }
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(contentsOf: buffer.prefix(count))
                    if data.count > 9 * 1024 * 1024 { return json(["errors": []], status: 413) }
                }
            }
            let body = String(decoding: data, as: UTF8.self)
            guard body.contains("name=\"image\"; filename=\"agenda.jpg\""), body.contains("name=\"image_upload\"\r\n\r\n1") else {
                return json(["errors": []], status: 422)
            }
            return json(["success": true, "post": ["id": "940001", "type": "standard", "message": "Fotoğraflı paylaşım",
                "actor": ["id": "900001", "username": "parity-fixture"], "attachments": attachments(for: mode)]])
        }
        return nil
    }
    private static func json(_ payload: [String: Any], status: Int = 200) -> (Int, String, Data) {
        (status, "application/json", (try? JSONSerialization.data(withJSONObject: payload)) ?? Data())
    }
}
#endif
