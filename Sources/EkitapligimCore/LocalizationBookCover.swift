import Foundation

public extension L10n {
    static var bookCoverBrand: String {
        NSLocalizedString("brand", tableName: "BookCover", bundle: .module, comment: "Book cover brand")
    }

    static var bookCoverCollection: String {
        NSLocalizedString("collection", tableName: "BookCover", bundle: .module, comment: "Book cover collection")
    }

    static var bookCoverFallbackTitle: String {
        NSLocalizedString("fallbackTitle", tableName: "BookCover", bundle: .module, comment: "Untitled book cover")
    }
}
