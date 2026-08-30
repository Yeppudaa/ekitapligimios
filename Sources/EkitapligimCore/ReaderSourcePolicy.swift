import Foundation

public enum ReaderSourcePolicy {
    /// Converts Google Drive sharing/preview URLs into a binary download URL.
    /// Non-Drive HTTPS URLs are returned unchanged so temporary server tokens survive intact.
    public static func downloadableURL(from sourceURL: URL) -> URL? {
        guard sourceURL.scheme?.lowercased() == "https" else { return nil }
        let host = sourceURL.host?.lowercased() ?? ""
        if host == "drive.usercontent.google.com" {
            return sourceURL
        }
        guard isGoogleDriveHost(host) else { return sourceURL }
        if isDirectGoogleDownload(sourceURL) {
            return sourceURL
        }
        guard let fileID = googleDriveFileID(in: sourceURL) else { return sourceURL }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "drive.usercontent.google.com"
        components.path = "/download"
        var queryItems = [
            URLQueryItem(name: "id", value: fileID),
            URLQueryItem(name: "export", value: "download"),
            URLQueryItem(name: "confirm", value: "t")
        ]
        if let resourceKey = queryValue("resourcekey", in: sourceURL) {
            queryItems.append(URLQueryItem(name: "resourcekey", value: resourceKey))
        }
        components.queryItems = queryItems
        return components.url
    }

    /// Picks the native binary source for PDFKit/Readium.
    /// Web `books/.../read-source` pages need XenForo cookies. XenForo REST
    /// `/api/books/.../reader/source` needs an XF-Api-Key. Neither is a native client URL.
    public static func nativeContentURL(
        session: ReaderSessionDTO,
        bookID: Int,
        apiBaseURL: URL
    ) -> URL? {
        let candidates = [session.apiSourceUrl, session.sourceUrl]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap(URL.init(string:))

        for url in candidates {
            if isTrustedNativeReaderSource(url, apiBaseURL: apiBaseURL),
               let downloadURL = downloadableURL(from: url) {
                return downloadURL
            }
        }
        for url in candidates {
            let host = url.host?.lowercased() ?? ""
            if isGoogleDriveHost(host) || host == "drive.usercontent.google.com",
               let downloadURL = downloadableURL(from: url) {
                return downloadURL
            }
        }
        return constructedReaderSourceURL(bookID: bookID, token: session.token, apiBaseURL: apiBaseURL)
    }

    public static func constructedReaderSourceURL(bookID: Int, token: String, apiBaseURL: URL) -> URL? {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard bookID > 0, !trimmedToken.isEmpty else { return nil }
        guard var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = normalizedPath(apiBaseURL.path) + "/books/\(bookID)/reader/source"
        components.queryItems = [URLQueryItem(name: "t", value: trimmedToken)]
        components.fragment = nil
        return components.url
    }

    public static func looksLikeGoogleDriveInterstitial(_ data: Data) -> Bool {
        googleDriveConfirmURL(fromHTMLData: data) != nil
            || interstitialProbe(data)
    }

    public static func googleDriveConfirmURL(fromHTMLData data: Data) -> URL? {
        let prefix = data.prefix(16_384)
        guard let html = String(data: prefix, encoding: .utf8)
            ?? String(data: prefix, encoding: .ascii) else { return nil }
        return googleDriveConfirmURL(from: html)
    }

    public static func googleDriveConfirmURL(from html: String) -> URL? {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "<" else { return nil }
        let lowered = html.lowercased()
        guard lowered.contains("drive.google.com") || lowered.contains("drive.usercontent.google.com") else {
            return nil
        }

        guard let regex = try? NSRegularExpression(
            pattern: #"href="([^"]*(?:/uc\?|download\?)[^"]*confirm=[^"]*)""#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let hrefRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        var href = String(html[hrefRange])
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x3d;", with: "=")
            .replacingOccurrences(of: "&#61;", with: "=")
        if href.hasPrefix("//") {
            href = "https:" + href
        } else if href.hasPrefix("/") {
            href = "https://drive.google.com" + href
        }
        guard let url = URL(string: href), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    public static func shouldAttachAccessToken(to url: URL, apiBaseURL: URL) -> Bool {
        isUnderAPIBase(url, apiBaseURL: apiBaseURL)
    }

    /// Some public endpoints wrap the ebook as `{ "data": "<base64>" }` or `{ "innerContent": { "data": ... } }`.
    public static func unpackedBookFileData(from data: Data) -> Data {
        if DownloadFilePolicy.sniffedFileExtension(fromHeader: data) != nil {
            return data
        }
        guard looksLikeJSONObject(data),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        if let unpacked = base64FilePayload(in: object) {
            return unpacked
        }
        if let inner = object["innerContent"] as? [String: Any],
           let unpacked = base64FilePayload(in: inner) {
            return unpacked
        }
        return data
    }

    private static func interstitialProbe(_ data: Data) -> Bool {
        guard let html = String(data: data.prefix(2_048), encoding: .utf8) else { return false }
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first == "<"
            && html.lowercased().contains("drive.google.com")
    }

    private static func isTrustedNativeReaderSource(_ url: URL, apiBaseURL: URL) -> Bool {
        isNativeReaderSourcePath(url) && isUnderAPIBase(url, apiBaseURL: apiBaseURL)
    }

    private static func isUnderAPIBase(_ url: URL, apiBaseURL: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              apiBaseURL.scheme?.lowercased() == "https" else { return false }
        let requestHost = url.host?.lowercased() ?? ""
        let apiHost = apiBaseURL.host?.lowercased() ?? ""
        guard !requestHost.isEmpty, requestHost == apiHost else { return false }
        let requestPath = normalizedPath(url.path)
        let basePath = normalizedPath(apiBaseURL.path)
        guard basePath != "/", !basePath.isEmpty else { return false }
        return requestPath == basePath || requestPath.hasPrefix(basePath + "/")
    }

    private static func normalizedPath(_ path: String) -> String {
        var result = path.lowercased()
        if result.isEmpty { return "/" }
        if !result.hasPrefix("/") { result = "/" + result }
        while result.count > 1, result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    private static func isNativeReaderSourcePath(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        let parts = url.path.split(separator: "/").map { $0.lowercased() }
        guard parts.count >= 2 else { return false }
        for index in 0..<(parts.count - 1) where parts[index] == "reader" && parts[index + 1] == "source" {
            return true
        }
        return false
    }

    private static func looksLikeJSONObject(_ data: Data) -> Bool {
        guard let first = data.first(where: {
            $0 != 0x20 && $0 != 0x09 && $0 != 0x0A && $0 != 0x0D
        }) else { return false }
        return first == 0x7B
    }

    private static func base64FilePayload(in object: [String: Any]) -> Data? {
        for key in ["data", "contents", "file", "file_data", "fileData"] {
            guard let encoded = object[key] as? String else { continue }
            let trimmed = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let decoded = Data(base64Encoded: trimmed) else { continue }
            if DownloadFilePolicy.sniffedFileExtension(fromHeader: decoded) != nil {
                return decoded
            }
        }
        return nil
    }

    private static func isGoogleDriveHost(_ host: String) -> Bool {
        host == "drive.google.com" || host == "docs.google.com"
    }

    private static func isDirectGoogleDownload(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        let confirm = queryValue("confirm", in: url)
        if path.contains("/uc") { return true }
        if let confirm, !confirm.isEmpty, confirm.lowercased() != "t" { return true }
        return false
    }

    private static func googleDriveFileID(in url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        if let marker = components.firstIndex(of: "d"), components.indices.contains(marker + 1) {
            return validatedDriveFileID(components[marker + 1])
        }
        return queryValue("id", in: url).flatMap(validatedDriveFileID)
    }

    private static func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == name.lowercased() })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private static func validatedDriveFileID(_ value: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !value.isEmpty,
              value.utf8.count <= 256,
              value.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return value
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
