import Foundation

public enum ActivityPresentation {
    public static let audioTypes: Set<String> = [
        "audio_started", "audio_favorite", "audio_saved", "audio_later", "audio_completed",
        "audio_listening_started", "audiobook_listening_started", "listening", "audio_progress", "audiobook_progress",
        "audio_shelf_changed", "audio_favorite_added", "audiobook_favorite", "audiobook_favorite_added", "audiobook_completed"
    ]

    public static func message(type: String, rawMessage: String, username: String) -> String {
        guard type.lowercased() == "premium",
              rawMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || rawMessage.localizedCaseInsensitiveContains("Kitap Gündemi'nde bir paylaşım yaptı") else { return rawMessage }
        let actor = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actor.isEmpty else { return ShellRefreshL10n.text("premiumActivityGeneric") }
        return String(format: ShellRefreshL10n.text("premiumActivityMessage"), locale: Locale.current, actor)
    }
}
