import Foundation

extension Notification.Name {
    /// Emitted only after the server acknowledges an audio activity, never on a playback timer.
    static let audioActivityChanged = Notification.Name("Ekitapligim.audioActivityChanged")
}
