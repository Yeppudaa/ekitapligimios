import Foundation

public enum ReadingRoomL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "ReadingRoom", bundle: .module, comment: "Reading room presentation")
    }
}
