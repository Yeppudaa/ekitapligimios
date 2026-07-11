import Foundation
import EkitapligimCore

@MainActor
final class ReaderBookmarkStore: ObservableObject {
    @Published private(set) var collection: ReaderBookmarks

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard, storageKey: String = "reader.bookmarks.v1") {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(ReaderBookmarks.self, from: data) {
            collection = stored
        } else {
            collection = ReaderBookmarks()
        }
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
        guard let data = try? encoder.encode(collection) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
