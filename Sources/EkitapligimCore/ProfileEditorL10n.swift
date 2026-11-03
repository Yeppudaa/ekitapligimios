import Foundation

public enum ProfileEditorL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "ProfileEditor", bundle: .module, comment: "Profile editor")
    }
}
