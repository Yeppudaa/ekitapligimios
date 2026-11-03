import Foundation

public enum DirectoryDesignL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "DirectoryDesign", bundle: .module, comment: "Author and publisher directory")
    }

    public static func resultCount(kind: DirectoryKind, count: Int, complete: Bool) -> String {
        let number = NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
        let noun = kind == .author ? "authors" : "publishers"
        return String(format: text("results.\(noun).\(complete ? "complete" : "loaded")"), number)
    }
}
