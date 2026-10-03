import Foundation

/// Projects an account-scoped reader record into the library shared by Home and Profile.
/// A fetched library remains authoritative; only pending records are overlaid after a fetch.
public enum ReaderLibraryProjection {
    public static func item(
        bookID: Int,
        record: SavedReaderProgress,
        existing: LibraryItemDTO?,
        isDownloaded: Bool
    ) -> LibraryItemDTO? {
        guard let position = record.position else {
            return existing?.updating(progressPercent: 0, lastReadPage: 0, lastReadAt: 0)
        }
        // Invalid or non-finite transport values must never reach Double-to-Int conversion.
        guard position.isValid else { return nil }
        let percent = Int(position.progressPercent.rounded())
        let date = record.pending ? record.changedAt : position.lastReadDate
        if let existing {
            return existing.updating(progressPercent: percent, lastReadPage: position.page ?? 0,
                lastReadAt: date, positionType: position.positionType)
        }
        guard let book = record.book else { return nil }
        return LibraryItemDTO(bookId: String(bookID), shelfState: "NONE", progressPercent: percent,
            lastReadPage: position.page ?? 0, isDownloaded: isDownloaded, isFavorite: false,
            title: book.title, author: book.author, coverUrl: book.coverURL, pageCount: book.pageCount,
            lastReadAt: date, positionType: position.positionType)
    }
}
