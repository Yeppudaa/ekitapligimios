import Foundation

/// Serializes reader shelf/progress writes without blocking presentation. Once submitted,
/// a write finishes before the next starts, even if its original screen task is cancelled.
@MainActor
public final class ReaderWriteQueue {
    private var tail: Task<Void, Never>?
    private var lastID = UUID()

    public init() {}

    @discardableResult
    public func enqueue(_ operation: @escaping @MainActor @Sendable () async -> Void) -> Task<Void, Never> {
        let previous = tail
        let id = UUID()
        lastID = id
        let task = Task { [weak self] in
            await previous?.value
            await operation()
            if self?.lastID == id { self?.tail = nil }
        }
        tail = task
        return task
    }
}
