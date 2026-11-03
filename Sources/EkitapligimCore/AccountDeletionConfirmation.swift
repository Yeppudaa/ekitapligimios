import Foundation

/// The delete-account button is enabled only after the user types the confirmation word.
/// A Turkish keyboard produces "SİL" (dotted capital İ) and `uppercased()` turns a typed
/// "sil" into "SIL" only outside the Turkish locale, so both spellings must be accepted.
public enum AccountDeletionConfirmation {
    public static func isConfirmed(_ input: String) -> Bool {
        let folded = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{0130}", with: "I")
            .replacingOccurrences(of: "\u{0131}", with: "i")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return folded == "sil"
    }
}
