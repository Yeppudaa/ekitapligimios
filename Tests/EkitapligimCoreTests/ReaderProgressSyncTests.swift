import XCTest
@testable import EkitapligimCore

@MainActor
final class ReaderProgressSyncTests: XCTestCase {
    func testPDFRestores25Writes40AndCanReturnTo12() async throws {
        let repository = ProgressServer(page: 25)
        let sync = makeSync(repository)
        let restored = try await sync.prepare(bookID: 7)
        XCTAssertEqual(restored?.page, 25)
        let initialWrites = await repository.writes
        XCTAssertTrue(initialWrites.isEmpty)
        sync.record(bookID: 7, position: pdf(40))
        XCTAssertEqual(sync.records[7]?.position?.page, 40)
        XCTAssertTrue(sync.records[7]?.pending == true)
        await sync.flush(bookID: 7)
        sync.record(bookID: 7, position: pdf(12))
        await sync.flush(bookID: 7)
        let pages = await repository.writes.map(\.page)
        XCTAssertEqual(pages, [40, 12])
        XCTAssertEqual(sync.states[7], .synced)
    }

    func testWebChangeWinsOverOfflinePendingWriteEvenWhenPageIsSmaller() async throws {
        let repository = ProgressServer(page: 25)
        let sync = makeSync(repository)
        _ = try await sync.prepare(bookID: 7)
        sync.record(bookID: 7, position: pdf(40))
        await repository.webRead(page: 12)
        await sync.flush(bookID: 7)
        XCTAssertEqual(sync.records[7]?.position?.page, 12)
        XCTAssertFalse(sync.records[7]?.pending ?? true)
        let writes = await repository.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testNewPageDuringHTTPWriteSurvivesOlderAcknowledgement() async throws {
        let repository = ProgressServer(page: 1)
        let sync = makeSync(repository)
        _ = try await sync.prepare(bookID: 7)
        await repository.pauseNextSave()
        sync.record(bookID: 7, position: pdf(25))
        let flushing = Task { await sync.flush(bookID: 7) }
        await repository.waitForSave()
        sync.record(bookID: 7, position: pdf(40))
        XCTAssertEqual(sync.records[7]?.position?.page, 40)
        await repository.releaseSave()
        await flushing.value
        XCTAssertEqual(sync.records[7]?.position?.page, 40)
        let writes = await repository.writes.map(\.page)
        XCTAssertEqual(writes, [25, 40])
        XCTAssertFalse(sync.records[7]?.pending ?? true)
    }

    func testLostAcknowledgementRetriesWithoutOverwritingOrDuplicateWrite() async throws {
        let repository = ProgressServer(page: 25)
        let sync = makeSync(repository)
        _ = try await sync.prepare(bookID: 7)
        await repository.loseNextResponse()
        sync.record(bookID: 7, position: pdf(40))
        await sync.flush(bookID: 7)
        XCTAssertEqual(sync.states[7], .failed)
        await sync.retryPending()
        let writes = await repository.writes
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(sync.states[7], .synced)
    }

    func testPendingRecordSurvivesRestartAndRemainsAccountScoped() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = FileReaderProgressStorage(directory: directory)
        let repository = ProgressServer(page: 25)
        let first = makeSync(repository, storage: storage)
        _ = try await first.prepare(bookID: 7)
        await repository.setOffline(true)
        first.record(bookID: 7, position: pdf(40))
        await first.flush(bookID: 7)
        let restarted = makeSync(repository, storage: storage)
        let restored = try await restarted.prepare(bookID: 7)
        XCTAssertEqual(restored?.page, 40)
        XCTAssertTrue(restarted.records[7]?.pending == true)
        restarted.activate(account: "second-user")
        XCTAssertTrue(restarted.records.isEmpty)
        restarted.activate(account: "reader")
        await repository.setOffline(false)
        await restarted.retryPending()
        XCTAssertEqual(restarted.states[7], .synced)
    }

    func testSwitchingAccountIgnoresInFlightResponse() async throws {
        let repository = ProgressServer(page: 25)
        let sync = makeSync(repository)
        _ = try await sync.prepare(bookID: 7)
        await repository.pauseNextSave()
        sync.record(bookID: 7, position: pdf(40))
        let flushing = Task { await sync.flush(bookID: 7) }
        await repository.waitForSave()
        sync.activate(account: "second-user")
        await repository.releaseSave()
        await flushing.value
        XCTAssertTrue(sync.records.isEmpty)
        XCTAssertTrue(sync.states.isEmpty)
    }

    func testFirstPageAndInvalidEPUBNeverWriteOnOpen() async throws {
        let repository = ProgressServer(page: 1)
        let sync = makeSync(repository)
        _ = try await sync.prepare(bookID: 7)
        sync.record(bookID: 7, position: pdf(1))
        sync.record(bookID: 7, position: ReaderPositionDTO(positionType: "epub", positionValue: "25", progressPercent: 40))
        await sync.flush(bookID: 7)
        let writes = await repository.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testPostConflictAdoptsServerRecord() async throws {
        let repository = ProgressServer(page: 25)
        let sync = makeSync(repository)
        _ = try await sync.prepare(bookID: 7)
        await repository.conflictNextSave()
        sync.record(bookID: 7, position: pdf(40))
        await sync.flush(bookID: 7)
        XCTAssertEqual(sync.records[7]?.position?.page, 17)
        XCTAssertFalse(sync.records[7]?.pending ?? true)
    }

    func testAccountDeletionErasesOnlyCurrentAccountsCachedPositions() async throws {
        let storage = MemoryProgressStorage()
        let repository = ProgressServer(page: 25)
        let sync = makeSync(repository, storage: storage)
        _ = try await sync.prepare(bookID: 7)
        sync.activate(account: "second-user")
        _ = try await sync.prepare(bookID: 9)
        try sync.eraseCurrentAccount()
        XCTAssertTrue(sync.records.isEmpty)
        sync.activate(account: "second-user")
        XCTAssertTrue(sync.records.isEmpty)
        sync.activate(account: "reader")
        XCTAssertEqual(sync.records[7]?.position?.page, 25)
    }

    private func pdf(_ page: Int) -> ReaderPositionDTO {
        ReaderPositionDTO(positionType: "pdf", positionValue: String(page), progressPercent: Double(page))
    }
    private func makeSync(_ repository: ProgressServer, storage: (any ReaderProgressStorage)? = nil) -> ReaderProgressSync {
        let sync = ReaderProgressSync(repository: repository, storage: storage ?? MemoryProgressStorage())
        sync.activate(account: "reader")
        return sync
    }
}

@MainActor
private final class MemoryProgressStorage: ReaderProgressStorage {
    var accounts: [String: [Int: SavedReaderProgress]] = [:]
    func load(account: String) throws -> [Int: SavedReaderProgress] { accounts[account] ?? [:] }
    func save(_ records: [Int: SavedReaderProgress], account: String) throws { accounts[account] = records }
}

private actor ProgressServer: ReaderProgressRepositoryProtocol {
    var progress: ReaderPositionDTO
    var version = 1
    var writes: [ReaderPositionDTO] = []
    private var offline = false
    private var pause = false
    private var loseResponse = false
    private var conflict = false
    private var saveGate: CheckedContinuation<Void, Never>?
    private var enteredGate: CheckedContinuation<Void, Never>?
    private var entered = false
    init(page: Int) { progress = ReaderPositionDTO(positionType: "pdf", positionValue: String(page), progressPercent: Double(page), lastReadDate: 100) }
    func webRead(page: Int) {
        progress = ReaderPositionDTO(positionType: "pdf", positionValue: String(page), progressPercent: Double(page), lastReadDate: 101)
        version += 1
    }
    func setOffline(_ value: Bool) { offline = value }
    func pauseNextSave() { pause = true; entered = false }
    func loseNextResponse() { loseResponse = true }
    func conflictNextSave() { conflict = true }
    func waitForSave() async { if !entered { await withCheckedContinuation { enteredGate = $0 } } }
    func releaseSave() { saveGate?.resume(); saveGate = nil }
    func readerProgress(bookID: Int) async throws -> ReaderProgressResponseDTO {
        if offline { throw APIClientError.invalidResponse }
        return ReaderProgressResponseDTO(progress: progress, revision: String(version))
    }
    func saveReaderProgress(bookID: Int, position: ReaderPositionDTO, baseRevision: String, accountName: String) async throws -> ReaderProgressResponseDTO {
        if offline { throw APIClientError.invalidResponse }
        if pause {
            pause = false; entered = true; enteredGate?.resume(); enteredGate = nil
            await withCheckedContinuation { saveGate = $0 }
        }
        if conflict { conflict = false; webRead(page: 17) }
        if baseRevision != String(version) { return ReaderProgressResponseDTO(progress: progress, revision: String(version), conflict: true) }
        writes.append(position)
        version += 1
        progress = ReaderPositionDTO(positionType: position.positionType, positionValue: position.positionValue, progressPercent: position.progressPercent, lastReadDate: 100 + version)
        if loseResponse { loseResponse = false; throw APIClientError.invalidResponse }
        return ReaderProgressResponseDTO(progress: progress, revision: String(version), saved: true)
    }
}
