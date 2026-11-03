import Foundation

/// The API's q parameter is a contains search. Initial-letter matching stays explicit
/// so names containing a letter elsewhere cannot be mistaken for that letter's index.
public struct DirectoryFilter: Hashable, Sendable {
    public static let letters = ["#", "A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H", "I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P", "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"]
    private static let locale = Locale(identifier: "tr_TR")
    public let query: String
    public let letter: String

    public init(query: String = "", letter: String = "#") {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = letter.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(with: Self.locale)
        self.letter = Self.letters.contains(normalized) ? normalized : "#"
    }

    public var isUnfiltered: Bool { query.isEmpty && letter == "#" }
    public var remoteQuery: String? { !query.isEmpty ? query : (letter == "#" ? nil : letter) }

    public func matches(_ item: DirectoryItemDTO) -> Bool {
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = name.first.map { String($0).uppercased(with: Self.locale) }
        return (letter == "#" || initial == letter)
            && (query.isEmpty || name.range(of: query, options: .caseInsensitive, locale: Self.locale) != nil)
    }

    public func sorted(_ items: [DirectoryItemDTO], ascending: Bool) -> [DirectoryItemDTO] {
        items.sorted {
            let order = $0.name.compare($1.name, options: .caseInsensitive, locale: Self.locale)
            if order == .orderedSame { return $0.id < $1.id }
            return order == (ascending ? .orderedAscending : .orderedDescending)
        }
    }
}
