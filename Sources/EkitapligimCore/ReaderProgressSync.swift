import Foundation

public enum ReaderProgressSyncState: Equatable, Sendable { case idle, syncing, synced, failed }

public struct ReaderBookMetadata: Codable, Equatable, Sendable {
    public let title: String
    public let author: String
    public let coverURL: String
    public let pageCount: Int
    public init(title: String, author: String, coverURL: String, pageCount: Int) {
        self.title = title; self.author = author; self.coverURL = coverURL; self.pageCount = pageCount
    }
}

public struct SavedReaderProgress: Codable, Equatable, Sendable {
    public var position: ReaderPositionDTO?
    public var revision: String
    public var pending: Bool
    public var changeID: UUID
    public var changedAt: Int
    public var book: ReaderBookMetadata?

    public init(position: ReaderPositionDTO?, revision: String, pending: Bool = false, changedAt: Int = 0) {
        self.position = position
        self.revision = revision
        self.pending = pending
        self.changeID = UUID()
        self.changedAt = changedAt
    }
}

@MainActor
public protocol ReaderProgressStorage {
    func load(account: String) throws -> [Int: SavedReaderProgress]
    func save(_ records: [Int: SavedReaderProgress], account: String) throws
    func remove(account: String) throws
}

public extension ReaderProgressStorage {
    func remove(account: String) throws { try save([:], account: account) }
}

@MainActor
public final class FileReaderProgressStorage: ReaderProgressStorage {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }

    private func url(account: String) -> URL {
        let name = Data(account.utf8).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".json")
    }

    public func load(account: String) throws -> [Int: SavedReaderProgress] {
        let file = url(account: account)
        guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
        return try JSONDecoder().decode([Int: SavedReaderProgress].self, from: Data(contentsOf: file))
    }

    public func save(_ records: [Int: SavedReaderProgress], account: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excludedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excludedDirectory.setResourceValues(values)
        let data = try JSONEncoder().encode(records)
        #if os(iOS)
        try data.write(to: url(account: account), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url(account: account), options: .atomic)
        #endif
    }

    public func remove(account: String) throws {
        let file = url(account: account)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}

/// One owner for durable local positions, pending writes and server reconciliation.
/// Debouncing never cancels an HTTP write already in flight.
@MainActor
public final class ReaderProgressSync {
    public private(set) var records: [Int: SavedReaderProgress] = [:]
    public private(set) var states: [Int: ReaderProgressSyncState] = [:]
    public var didChange: (@MainActor (Int, SavedReaderProgress?, ReaderProgressSyncState) -> Void)?
    private let repository: any ReaderProgressRepositoryProtocol
    private let storage: any ReaderProgressStorage
    private let queue: ReaderWriteQueue
    private var account: String?
    private var generation = UUID()
    private var timers: [Int: Task<Void, Never>] = [:]

    public init(repository: any ReaderProgressRepositoryProtocol, storage: any ReaderProgressStorage, queue: ReaderWriteQueue? = nil) {
        self.repository = repository
        self.storage = storage
        self.queue = queue ?? ReaderWriteQueue()
    }

    public func activate(account: String?) {
        guard self.account != account else { return }
        timers.values.forEach { $0.cancel() }
        timers = [:]
        generation = UUID()
        self.account = account
        records = [:]
        states = [:]
        if let account {
            do { records = try storage.load(account: account) }
            catch { records = [:] }
        }
    }

    public func eraseCurrentAccount() throws {
        guard let account else { return }
        activate(account: nil)
        try storage.remove(account: account)
    }

    public func prepare(bookID: Int) async throws -> ReaderPositionDTO? {
        guard account != nil else { throw APIClientError.authenticationRequired }
        let identity = generation
        // Drains earlier writes before opening so a late response cannot undo the restored page.
        await flush(bookID: bookID)
        guard identity == generation else { throw CancellationError() }
        do {
            let response = try await repository.readerProgress(bookID: bookID)
            guard identity == generation, !Task.isCancelled else { throw CancellationError() }
            if records[bookID]?.pending != true { accept(response, bookID: bookID) }
            return records[bookID]?.position
        } catch {
            guard identity == generation, !Task.isCancelled else { throw CancellationError() }
            if let cached = records[bookID], cached.position?.isValid == true { return cached.position }
            throw error
        }
    }

    public func record(bookID: Int, position: ReaderPositionDTO) {
        guard account != nil, position.isValid, let previous = records[bookID] else { return }
        guard !position.hasSameLocation(as: previous.position) else { return }
        records[bookID] = SavedReaderProgress(position: position, revision: previous.revision, pending: true,
            changedAt: Int(Date().timeIntervalSince1970))
        records[bookID]?.book = previous.book
        let stored = persist()
        notify(bookID, state: stored ? .syncing : .failed)
        timers[bookID]?.cancel()
        let identity = generation
        timers[bookID] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, let self, self.generation == identity else { return }
            await self.flush(bookID: bookID)
        }
    }

    public func register(bookID: Int, metadata: ReaderBookMetadata) {
        records[bookID]?.book = metadata
        _ = persist()
    }

    public func captureFailed(bookID: Int) { notify(bookID, state: .failed) }

    public func flush(bookID: Int) async {
        timers.removeValue(forKey: bookID)?.cancel()
        let identity = generation
        await queue.enqueue { [weak self] in
            guard let self, self.generation == identity, self.account != nil else { return }
            await self.sendPending(bookID: bookID, identity: identity)
        }.value
    }

    public func retryPending() async {
        let identity = generation
        let ids = records.filter { $0.value.pending }.keys.sorted()
        for id in ids {
            guard generation == identity else { return }
            await flush(bookID: id)
        }
    }

    private func sendPending(bookID: Int, identity: UUID) async {
        while identity == generation, let account, let pending = records[bookID], pending.pending, let position = pending.position {
            notify(bookID, state: .syncing)
            do {
                let remote = try await repository.readerProgress(bookID: bookID)
                guard identity == generation else { return }
                if remote.revision != pending.revision {
                    // A lost HTTP response is harmless. A genuinely different web position wins.
                    if position.hasSameLocation(as: remote.progress) {
                        acknowledge(remote, sent: pending, bookID: bookID)
                        continue
                    }
                    accept(remote, bookID: bookID)
                    return
                }
                let result = try await repository.saveReaderProgress(bookID: bookID, position: position, baseRevision: pending.revision, accountName: account)
                guard identity == generation else { return }
                if result.conflict { accept(result, bookID: bookID); return }
                guard result.saved, result.progress != nil else { throw APIClientError.invalidResponse }
                acknowledge(result, sent: pending, bookID: bookID)
            } catch {
                guard identity == generation else { return }
                notify(bookID, state: .failed)
                return
            }
        }
    }

    private func acknowledge(_ response: ReaderProgressResponseDTO, sent: SavedReaderProgress, bookID: Int) {
        if var newer = records[bookID], newer.changeID != sent.changeID {
            newer.revision = response.revision
            records[bookID] = newer
            _ = persist()
        } else { accept(response, bookID: bookID) }
    }

    private func accept(_ response: ReaderProgressResponseDTO, bookID: Int) {
        let metadata = records[bookID]?.book
        records[bookID] = SavedReaderProgress(position: response.progress, revision: response.revision)
        records[bookID]?.book = metadata
        let stored = persist()
        notify(bookID, state: stored ? .synced : .failed)
    }

    @discardableResult
    private func persist() -> Bool {
        guard let account else { return false }
        do { try storage.save(records, account: account); return true }
        catch { return false }
    }

    private func notify(_ bookID: Int, state: ReaderProgressSyncState) {
        states[bookID] = state
        didChange?(bookID, records[bookID], state)
    }
}
