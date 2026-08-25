import Foundation

public enum ReaderSourcePolicy {
    /// Converts Google Drive sharing/preview URLs into a binary download URL.
    /// Non-Drive HTTPS URLs are returned unchanged so temporary server tokens survive intact.
    public static func downloadableURL(from sourceURL: URL) -> URL? {
        guard sourceURL.scheme?.lowercased() == "https" else { return nil }
        guard sourceURL.host?.lowercased() == "drive.google.com" else { return sourceURL }
        guard let fileID = googleDriveFileID(in: sourceURL) else { return sourceURL }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "drive.usercontent.google.com"
        components.path = "/download"
        components.queryItems = [
            URLQueryItem(name: "id", value: fileID),
            URLQueryItem(name: "export", value: "download"),
            URLQueryItem(name: "confirm", value: "t")
        ]
        return components.url
    }

    private static func googleDriveFileID(in url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        if let marker = components.firstIndex(of: "d"), components.indices.contains(marker + 1) {
            return validatedDriveFileID(components[marker + 1])
        }
        let queryID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "id" })?
            .value
        return queryID.flatMap(validatedDriveFileID)
    }

    private static func validatedDriveFileID(_ value: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !value.isEmpty,
              value.utf8.count <= 256,
              value.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return value
    }
}
