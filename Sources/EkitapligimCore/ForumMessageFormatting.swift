import Foundation

public struct ForumMessageBlock: Equatable, Sendable, Identifiable {
    public let id: Int
    public let text: String
    public let isSeparator: Bool
    public let isHeading: Bool
    public let isBullet: Bool

    public init(id: Int, text: String, isSeparator: Bool, isHeading: Bool, isBullet: Bool) {
        self.id = id
        self.text = text
        self.isSeparator = isSeparator
        self.isHeading = isHeading
        self.isBullet = isBullet
    }
}

public enum ForumMessageFormatting {
    /// Mirrors Android blank-username fallback (`Ekitaplığım`).
    public static func displayUsername(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.forumDefaultUsername : trimmed
    }

    /// Mirrors Android `compactForumMessageBlocks` for forum thread posts.
    public static func blocks(from raw: String) -> [ForumMessageBlock] {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var blocks: [ForumMessageBlock] = []
        blocks.reserveCapacity(normalized.count)

        for (index, line) in normalized.enumerated() {
            let cleaned = line.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }

            let separatorCount = cleaned.filter { "━-_".contains($0) }.count
            let isSeparator = separatorCount >= 6
            let isHeading = cleaned.range(of: #"^\d+\.\s+.+"#, options: .regularExpression) != nil
                || cleaned.hasSuffix(":")
                || cleaned.localizedCaseInsensitiveContains("Son Not")
            let isBullet = cleaned.hasPrefix("•") || cleaned.hasPrefix("-") || cleaned.hasPrefix("*")

            blocks.append(
                ForumMessageBlock(
                    id: index,
                    text: cleaned,
                    isSeparator: isSeparator,
                    isHeading: isHeading,
                    isBullet: isBullet
                )
            )
        }
        return blocks
    }
}
