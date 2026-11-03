import Combine
import Foundation
import EkitapligimCore

/// Selection is replaceable and cancellable; a late iCloud result cannot restore a removed photo.
@MainActor
final class AgendaPhotoModel: ObservableObject {
    @Published private(set) var data: Data?
    @Published private(set) var isPreparing = false
    @Published private(set) var error: String?
    private var generation = UUID()
    private let prepare: @Sendable (Data) async throws -> Data

    init(prepare: @escaping @Sendable (Data) async throws -> Data) { self.prepare = prepare }

    func remove() {
        generation = UUID()
        data = nil
        isPreparing = false
        error = nil
    }

    func select(load: @Sendable () async throws -> Data?) async {
        let id = UUID()
        generation = id
        data = nil
        error = nil
        isPreparing = true
        defer { if generation == id { isPreparing = false } }
        do {
            guard let original = try await load() else { throw AgendaMediaError.invalidImage }
            try Task.checkCancellation()
            let prepared = try await prepare(original)
            guard generation == id, !Task.isCancelled else { return }
            data = prepared
        } catch is CancellationError {
            return
        } catch {
            guard generation == id, !Task.isCancelled else { return }
            self.error = AgendaMediaL10n.text("selection.failed")
        }
    }
}
