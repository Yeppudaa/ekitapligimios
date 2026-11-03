import Foundation

public struct ContentSafety: Sendable {
    private let blockedTerms: [String]

    public init(blockedTerms: [String]? = nil) {
        self.blockedTerms = (blockedTerms ?? Self.defaultBlockedTerms).map(Self.fold)
    }

    public func validateUserGeneratedText(_ text: String) -> ContentSafetyResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .rejected(reason: .empty)
        }
        let folded = Self.fold(trimmed)
        if blockedTerms.contains(where: { folded.contains($0) }) {
            return .rejected(reason: .blockedTerm)
        }
        return .accepted
    }

    /// Lowercases in Turkish and then drops the dotted/dotless and accent differences,
    /// so "KISISEL", "kişisel" and "KİŞİSEL" all compare equal. Before, typing the
    /// dotless capital (or plain ASCII) slipped past every Turkish blocked term.
    static func fold(_ text: String) -> String {
        text.lowercased(with: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
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
