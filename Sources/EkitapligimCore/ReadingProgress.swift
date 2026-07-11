import Foundation

public struct ReadingProgress: Equatable, Sendable {
    public let currentPage: Int
    public let totalPages: Int

    public init(currentPage: Int, totalPages: Int) {
        self.totalPages = max(1, totalPages)
        self.currentPage = min(max(1, currentPage), self.totalPages)
    }

    public var percent: Double {
        (Double(currentPage) / Double(totalPages) * 100).rounded()
    }

    public func advanced(to page: Int) -> ReadingProgress {
        ReadingProgress(currentPage: page, totalPages: totalPages)
    }
}

public enum DownloadState: Equatable, Sendable {
    case notDownloaded
    case queued
    case downloading(progress: Double)
    case downloaded(localFileName: String)
    case failed(message: String)
}
