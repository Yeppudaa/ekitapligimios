import Foundation

public enum AudioL10n {
    public static func text(_ key: String) -> String { NSLocalizedString(key, tableName: "Audio", bundle: .module, comment: "Audiobook interface") }
    public static func format(_ key: String, _ arguments: CVarArg...) -> String { String(format: text(key), locale: Locale.current, arguments: arguments) }
    public static func error(_ error: Error) -> String {
        guard let error = error as? AudioError else { return text("connectionError") }
        switch error {
        case .authenticationRequired: return text("signInRequired")
        case .accountChanged: return text("accountChanged")
        case .premiumRequired: return text("premiumMessage")
        case .sessionConflict: return text("sessionConflict")
        case .unavailable: return text("unavailable")
        case .invalidRange: return text("rangeError")
        default: return text("connectionError")
        }
    }
    public static func duration(_ seconds: Double) -> String {
        let whole = Int(min(AudioPolicy.finite(seconds), Double(Int32.max)))
        if whole < 60 { return format("seconds", whole) }
        let minutes = whole / 60
        return minutes >= 60 ? format("hoursMinutes", minutes / 60, minutes % 60) : format("minutes", minutes)
    }
}
