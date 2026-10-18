import Foundation

public enum LibraryDetailL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "LibraryDetail", bundle: .module, comment: "Book detail library actions")
    }

    public static func currentShelf(_ name: String) -> String {
        String(format: text("currentShelf"), name)
    }
}
