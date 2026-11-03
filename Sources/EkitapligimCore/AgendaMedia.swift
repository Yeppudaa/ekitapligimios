import Foundation

public enum AgendaMediaPolicy {
    public static let maximumUploadBytes = 8 * 1_024 * 1_024
    public static let maximumDownloadBytes = 20 * 1_024 * 1_024

    public static func imageURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}

public enum AgendaMediaError: Error, Equatable { case invalidImage, imageTooLarge, uploadUnavailable }

public struct AgendaMediaCapabilitiesDTO: Decodable, Sendable {
    public let canUploadImages: Bool
    public let maximumBytes: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .imageUploadVersion) ?? 0
        let permitted = try container.decodeIfPresent(Bool.self, forKey: .canUploadImages) ?? false
        canUploadImages = version == 1 && permitted
        maximumBytes = max(0, min(AgendaMediaPolicy.maximumUploadBytes,
            try container.decodeIfPresent(Int.self, forKey: .maximumBytes) ?? 0))
    }
    private enum CodingKeys: String, CodingKey { case imageUploadVersion, canUploadImages, maximumBytes }
}

public enum AgendaMediaL10n {
    public static func imageCount(_ count: Int) -> String { String(format: text("images.count"), count) }
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "AgendaMedia", bundle: .module, comment: "Book agenda photos")
    }
}

public extension APIEndpoint {
    static var agendaMediaCapabilities: APIEndpoint {
        APIEndpoint(method: .get, path: "book-agenda", queryItems: [URLQueryItem(name: "media_capabilities", value: "1")])
    }
    static func agendaImage(postID: String, attachmentID: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "book-agenda/\(postID)", queryItems: [URLQueryItem(name: "image_id", value: attachmentID)])
    }
}
