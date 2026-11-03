import Foundation

extension Notification.Name {
    /// Invalidates server-backed feeds after a confirmed library write or an authorized book opens.
    /// Carries no book, account, progress or other private data and never synthesizes feed entries.
    static let libraryActivityChanged = Notification.Name("Ekitapligim.libraryActivityChanged")
}
