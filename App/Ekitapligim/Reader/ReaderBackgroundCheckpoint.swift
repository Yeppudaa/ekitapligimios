import UIKit

/// A short, bounded opportunity to persist/flush a final reading event before suspension.
@MainActor
final class ReaderBackgroundCheckpoint {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    static func run(_ operation: @escaping @MainActor () async -> Void) {
        let checkpoint = ReaderBackgroundCheckpoint()
        checkpoint.identifier = UIApplication.shared.beginBackgroundTask(withName: "Reader progress") { [weak checkpoint] in
            Task { @MainActor in checkpoint?.finish() }
        }
        Task {
            await operation()
            checkpoint.finish()
        }
    }

    private func finish() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
