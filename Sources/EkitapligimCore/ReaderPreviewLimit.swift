import Foundation

/// Free preview stops after page 9. Page 10 is the premium limit screen.
public struct ReaderPreviewLimit: Equatable, Sendable {
    public static let standardPageCount = 10

    public let isPreviewMode: Bool
    public let currentPage: Int
    public let documentPageCount: Int
    public let catalogPageCount: Int

    public init(
        isPreviewMode: Bool,
        currentPage: Int,
        documentPageCount: Int,
        catalogPageCount: Int = 0
    ) {
        self.isPreviewMode = isPreviewMode
        self.currentPage = max(1, currentPage)
        self.documentPageCount = max(0, documentPageCount)
        self.catalogPageCount = max(0, catalogPageCount)
    }

    public var knownTotalPages: Int {
        max(documentPageCount, catalogPageCount, 1)
    }

    public var accessiblePageLimit: Int {
        guard isPreviewMode else { return knownTotalPages }
        return min(Self.standardPageCount, knownTotalPages)
    }

    /// Last page the reader may show as book content before the paywall.
    public var lastFreePage: Int {
        max(accessiblePageLimit - 1, 1)
    }

    public var hasLockedContent: Bool {
        isPreviewMode && knownTotalPages >= Self.standardPageCount
    }

    public var isOnLimitPage: Bool {
        hasLockedContent && currentPage >= accessiblePageLimit
    }

    public func clamped(_ page: Int) -> Int {
        let upper = hasLockedContent ? accessiblePageLimit : knownTotalPages
        return min(max(1, page), max(upper, 1))
    }

    public func blocks(_ page: Int) -> Bool {
        hasLockedContent && page > accessiblePageLimit
    }
}
