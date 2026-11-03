import Foundation
import Combine
import EkitapligimCore

@MainActor
final class ReaderBookmarkStore: ObservableObject {
    @Published private(set) var collection: ReaderBookmarks

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()

    private var activeAccount: String?

    /// Bookmarks belong to the signed-in account. Nothing is shown or saved until
    /// `activate(account:)` names one, so a second account never sees the first's notes.
    init(defaults: UserDefaults = .standard, storageKey: String = "reader.bookmarks.v1") {
        self.defaults = defaults
        self.storageKey = storageKey
        collection = ReaderBookmarks()
    }

    func activate(account: String?) {
        guard account != activeAccount else { return }
        activeAccount = account
        collection = load(account: account)
    }

    private func accountKey(_ account: String?) -> String? {
        guard let account, !account.isEmpty else { return nil }
        return storageKey + ".account." + account
    }

    private func load(account: String?) -> ReaderBookmarks {
        guard let key = accountKey(account) else { return ReaderBookmarks() }
        if let data = defaults.data(forKey: key),
           let stored = try? JSONDecoder().decode(ReaderBookmarks.self, from: data) {
            return stored
        }
        // Bookmarks saved before accounts were separated move once to the first
        // account that signs in after the update (normally the device owner).
        if let legacy = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(ReaderBookmarks.self, from: legacy) {
            defaults.set(legacy, forKey: key)
            defaults.removeObject(forKey: storageKey)
            return stored
        }
        return ReaderBookmarks()
    }

    func bookmarks(for bookID: Int) -> [ReaderBookmark] {
        collection.bookmarks(for: bookID)
    }

    func contains(bookID: Int, page: Int) -> Bool {
        collection.contains(bookID: bookID, page: page)
    }

    func toggle(bookID: Int, page: Int) {
        collection.toggle(bookID: bookID, page: page)
        persist()
    }

    func remove(bookID: Int, page: Int) {
        collection.remove(bookID: bookID, page: page)
        persist()
    }

    private func persist() {
        guard let key = accountKey(activeAccount),
              let data = try? encoder.encode(collection) else { return }
        defaults.set(data, forKey: key)
    }
}
