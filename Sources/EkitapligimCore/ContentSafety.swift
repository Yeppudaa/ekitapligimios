import Foundation

public struct ContentSafety: Sendable {
    private let blockedTerms: [String]

    public init(blockedTerms: [String] = Self.defaultBlockedTerms) {
        self.blockedTerms = blockedTerms.map { $0.lowercased(with: Locale(identifier: "tr_TR")) }
    }

    public func validateUserGeneratedText(_ text: String) -> ContentSafetyResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .rejected(reason: .empty)
        }
        if trimmed.count < 3 {
            return .rejected(reason: .tooShort)
        }
        let folded = trimmed.lowercased(with: Locale(identifier: "tr_TR"))
        if blockedTerms.contains(where: { folded.contains($0) }) {
            return .rejected(reason: .blockedTerm)
        }
        return .accepted
    }

    private static let defaultBlockedTerms = [
        "spamlink",
        "nefret söylemi",
        "kişisel veri paylaşımı"
    ]
}

public enum ContentSafetyResult: Equatable, Sendable {
    case accepted
    case rejected(reason: ContentSafetyRejection)
}

public enum ContentSafetyRejection: Equatable, Sendable {
    case empty
    case tooShort
    case blockedTerm

    public var userMessage: String {
        switch self {
        case .empty:
            return "Metin boş olamaz."
        case .tooShort:
            return "Metin çok kısa."
        case .blockedTerm:
            return "Metin topluluk kurallarına aykırı olabilir."
        }
    }
}
