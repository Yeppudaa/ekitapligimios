import Foundation
import EkitapligimCore

enum AudioPresentationPolicy {
    static func shelfArtwork(_ title: String) -> String {
        let value = title.lowercased(with: Locale(identifier: "tr_TR"))
        if value.contains("devam") { return "audio_shelf_continue" }
        if value.contains("yeni") { return "audio_shelf_new" }
        if value.contains("popüler") || value.contains("çok") { return "audio_shelf_popular" }
        if value.contains("editör") { return "audio_shelf_editor" }
        if value.contains("kısa") { return "audio_shelf_short" }
        if value.contains("hafta") { return "audio_shelf_weekly" }
        if value.contains("senin") || value.contains("öner") { return "audio_shelf_recommended" }
        return "audio_shelf_featured"
    }
    /// Current server stats are already formatted ("3 sa 5 dk"). Older numeric totals are seconds.
    static func serverDuration(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return AudioL10n.format("seconds", 0) }
        if let seconds = Double(value), seconds.isFinite {
            if seconds < 60 { return AudioL10n.format("seconds", Int(max(0, seconds))) }
            return AudioL10n.duration(seconds)
        }
        return value
    }
}
