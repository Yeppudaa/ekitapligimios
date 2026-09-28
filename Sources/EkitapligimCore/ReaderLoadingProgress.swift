import Foundation

public enum ReaderL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Reader", bundle: .module, comment: "Native reader")
    }
}

public enum ReaderPaperTheme: String, CaseIterable, Sendable {
    case sepia, white, night
    public var title: String { ReaderL10n.text("theme.\(rawValue)") }
}

/// Actual transferred bytes. Unknown Content-Length is deliberately indeterminate, never an invented percentage.
public struct BookTransferProgress: Equatable, Sendable {
    public let receivedBytes: Int64
    public let expectedBytes: Int64?
    public init(receivedBytes: Int64, expectedBytes: Int64) {
        self.receivedBytes = max(0, receivedBytes)
        self.expectedBytes = expectedBytes > 0 ? expectedBytes : nil
    }
    public var fraction: Double? {
        guard let expectedBytes else { return nil }
        return min(1, Double(receivedBytes) / Double(expectedBytes))
    }
    public var percent: Int? { fraction.map { Int(($0 * 100).rounded(.down)) } }
    public var byteDescription: String {
        let received = ByteCountFormatter.string(fromByteCount: receivedBytes, countStyle: .file)
        guard let expectedBytes else { return received }
        return received + " / " + ByteCountFormatter.string(fromByteCount: expectedBytes, countStyle: .file)
    }
}

public enum ReaderLoadingPhase: Equatable, Sendable {
    case authorizing, restoring, downloading(BookTransferProgress), validating, opening
    public var title: String {
        switch self {
        case .authorizing: ReaderL10n.text("loading.authorizing")
        case .restoring: ReaderL10n.text("loading.restoring")
        case .downloading: ReaderL10n.text("loading.downloading")
        case .validating: ReaderL10n.text("loading.validating")
        case .opening: ReaderL10n.text("loading.opening")
        }
    }
    public var transfer: BookTransferProgress? {
        if case .downloading(let progress) = self { return progress }
        return nil
    }
}
