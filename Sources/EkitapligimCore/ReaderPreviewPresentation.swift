import Foundation

/// Decides when the free-preview paywall may appear without nesting presentations.
public struct ReaderPreviewPresentation: Equatable, Sendable {
    public var didPresentLimit = false
    public var isLimitVisible = false
    public var isReaderRestored = false

    public init(
        didPresentLimit: Bool = false,
        isLimitVisible: Bool = false,
        isReaderRestored: Bool = false
    ) {
        self.didPresentLimit = didPresentLimit
        self.isLimitVisible = isLimitVisible
        self.isReaderRestored = isReaderRestored
    }

    public enum Event: Equatable, Sendable {
        case none
        case presentLimit
        case openPremium
        case clampOnly
    }

    public struct Decision: Equatable, Sendable {
        public let page: Int
        public let event: Event

        public init(page: Int, event: Event) {
            self.page = page
            self.event = event
        }
    }

    public mutating func markRestored() {
        isReaderRestored = true
    }

    public mutating func dismissLimit() {
        isLimitVisible = false
    }

    public mutating func handle(_ limit: ReaderPreviewLimit) -> Decision {
        let page = limit.clamped(limit.currentPage)
        let blocked = limit.blocks(limit.currentPage)

        guard isReaderRestored else {
            return Decision(page: page, event: blocked ? .clampOnly : .none)
        }

        if blocked {
            if isLimitVisible {
                return Decision(page: page, event: .clampOnly)
            }
            if didPresentLimit {
                return Decision(page: page, event: .openPremium)
            }
            didPresentLimit = true
            isLimitVisible = true
            return Decision(page: page, event: .presentLimit)
        }

        if limit.isOnLimitPage, !didPresentLimit {
            didPresentLimit = true
            isLimitVisible = true
            return Decision(page: page, event: .presentLimit)
        }

        return Decision(page: page, event: .none)
    }
}

/// Runs UI teardown on the next main-actor turn so UIKit/Readium callbacks can return first.
public enum ReaderDeferredTeardown: Sendable {
    public static func enqueue(_ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            work()
        }
    }
}
