import Foundation

/// The web reader's wire format. EPUB values are CFI strings, never Readium page indices.
public struct ReaderPositionDTO: Codable, Equatable, Sendable {
    public let positionType: String
    public let positionValue: String
    public let progressPercent: Double
    public let lastReadDate: Int

    public init(positionType: String, positionValue: String, progressPercent: Double, lastReadDate: Int = 0) {
        self.positionType = positionType
        self.positionValue = positionValue
        self.progressPercent = progressPercent
        self.lastReadDate = lastReadDate
    }

    public var page: Int? { positionType == "pdf" ? Int(positionValue) : nil }
    public var isValid: Bool {
        guard progressPercent.isFinite, (0...100).contains(progressPercent), positionValue.utf8.count <= 255 else { return false }
        if positionType == "pdf" { return (page ?? 0) > 0 && positionValue.allSatisfy { $0.isASCII && $0.isNumber } }
        return positionType == "epub" && (try? EPUBCFI(positionValue)) != nil
    }

    public func hasSameLocation(as other: Self?) -> Bool {
        guard let other else { return false }
        return positionType == other.positionType && positionValue == other.positionValue
    }
}

public struct ReaderProgressResponseDTO: Decodable, Sendable {
    public let progress: ReaderPositionDTO?
    public let revision: String
    public let saved: Bool
    public let conflict: Bool

    public init(progress: ReaderPositionDTO?, revision: String, saved: Bool = false, conflict: Bool = false) {
        self.progress = progress
        self.revision = revision
        self.saved = saved
        self.conflict = conflict
    }
}

public protocol ReaderProgressRepositoryProtocol: Sendable {
    func readerProgress(bookID: Int) async throws -> ReaderProgressResponseDTO
    func saveReaderProgress(bookID: Int, position: ReaderPositionDTO, baseRevision: String, accountName: String) async throws -> ReaderProgressResponseDTO
}

public extension APIEndpoint {
    static func readerProgress(bookID: Int) -> APIEndpoint {
        APIEndpoint(method: .get, path: "books/\(bookID)/reader/progress", requiresAuthentication: true)
    }

    static func saveReaderProgress(bookID: Int, position: ReaderPositionDTO, baseRevision: String, accountName: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "books/\(bookID)/reader/progress", body: .form([
            "position_type": position.positionType,
            "position_value": position.positionValue,
            "progress_percent": String(position.progressPercent),
            "base_revision": baseRevision,
            "account_name": accountName
        ]), requiresAuthentication: true)
    }
}
