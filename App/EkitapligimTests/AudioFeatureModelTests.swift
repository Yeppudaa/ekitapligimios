import XCTest
@testable import Ekitapligim
import EkitapligimCore

@MainActor
final class AudioFeatureModelTests: XCTestCase {
    func testRefreshDuringShelfPostAlwaysReleasesBusyAndKeepsAcknowledgedState() async throws {
        let service = AudioFeatureTestService()
        // Use the same controlled service for both the metadata request and mutation.
        let controlled = AudioDetailModel(bookID: 27, repository: service)
        controlled.activate(account: "reader"); await controlled.load()
        let mutation = Task { await controlled.toggle(.favorite, account: "reader") }
        await service.waitForShelf(account: "reader")
        XCTAssertTrue(controlled.shelfBusy)
        await controlled.load() // A pull-to-refresh changes the read generation while POST is pending.
        await service.finishShelf(account: "reader")
        let saved = await mutation.value
        XCTAssertTrue(saved); XCTAssertFalse(controlled.shelfBusy); XCTAssertTrue(controlled.favorite)
    }
    func testOldAccountMutationCannotClearNewAccountsBusyOrPublishOldFavorite() async throws {
        let service = AudioFeatureTestService()
        let controlled = AudioDetailModel(bookID: 27, repository: service)
        controlled.activate(account: "reader"); await controlled.load()
        let first = Task { await controlled.toggle(.favorite, account: "reader") }
        await service.waitForShelf(account: "reader")
        controlled.activate(account: "other")
        let second = Task { await controlled.toggle(.later, account: "other") }
        await service.waitForShelf(account: "other")
        await service.finishShelf(account: "reader")
        let oldSaved = await first.value
        XCTAssertFalse(oldSaved); XCTAssertTrue(controlled.shelfBusy); XCTAssertFalse(controlled.favorite)
        await service.finishShelf(account: "other")
        let newSaved = await second.value
        XCTAssertTrue(newSaved); XCTAssertFalse(controlled.shelfBusy); XCTAssertTrue(controlled.later)
    }
    func testFailedNextPageRetriesExactPageAndPreservesExistingBooks() async throws {
        let service = AudioFeatureTestService()
        let controlled = AudioCatalogModel(repository: service)
        await controlled.load(); XCTAssertEqual(controlled.books.map(\.id), [1])
        await controlled.more()
        XCTAssertNotNil(controlled.error); XCTAssertEqual(controlled.filters.page, 1); XCTAssertEqual(controlled.books.map(\.id), [1])
        await controlled.retry()
        XCTAssertNil(controlled.error); XCTAssertEqual(controlled.filters.page, 2); XCTAssertEqual(controlled.books.map(\.id), [1, 2])
        let pages = await service.catalogPages
        XCTAssertEqual(pages, [1, 2, 2])
    }
    func testNextPageButtonAfterFailureCannotSkipTheFailedPage() async throws {
        let service = AudioFeatureTestService()
        let controlled = AudioCatalogModel(repository: service)
        await controlled.load(); await controlled.more(); await controlled.more()
        let pages = await service.catalogPages
        XCTAssertEqual(pages, [1, 2, 2]); XCTAssertEqual(controlled.books.map(\.id), [1, 2])
    }
    func testServerFormattedListeningStatsAreNotConvertedToZero() {
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("3 sa 5 dk"), "3 sa 5 dk")
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("20 dk"), "20 dk")
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("0 sn"), "0 sn")
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("3660"), AudioL10n.duration(3660))
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("23"), AudioL10n.format("seconds", 23))
    }
}

private actor AudioFeatureTestService: AudioServing {
    private var shelfContinuations: [String: CheckedContinuation<Void, Never>] = [:]
    private var shelfWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var requestedAccounts: Set<String> = []
    private var pageTwoFailed = false
    private(set) var catalogPages: [Int] = []
    func waitForShelf(account: String) async {
        if requestedAccounts.contains(account) { return }
        await withCheckedContinuation { shelfWaiters[account, default: []].append($0) }
    }
    func finishShelf(account: String) { shelfContinuations.removeValue(forKey: account)?.resume() }
    func catalog(filters: AudioFilters) async throws -> AudioCatalogDTO {
        catalogPages.append(filters.page)
        if filters.page == 2 && !pageTwoFailed { pageTwoFailed = true; throw AudioError.unavailable }
        return try decode(AudioCatalogDTO.self, "{\"api_version\":1,\"books\":[{\"thread_id\":\(filters.page),\"title\":\"Book\"}],\"pagination\":{\"page\":\(filters.page),\"pages\":3,\"total\":3}}")
    }
    func detail(bookID: Int) async throws -> AudioDetailDTO {
        try decode(AudioDetailDTO.self, #"{"api_version":1,"book":{"thread_id":27,"title":"Book","user_state":{"favorite":false,"later":false,"saved":false}},"related":[],"same_author":[]}"#)
    }
    func shelf(bookID: Int, field: AudioShelfField, value: Bool, account: String) async throws {
        await withCheckedContinuation { continuation in
            shelfContinuations[account] = continuation; requestedAccounts.insert(account)
            for waiter in shelfWaiters.removeValue(forKey: account) ?? [] { waiter.resume() }
        }
    }
    func library(tab: AudioLibraryTab, account: String) async throws -> AudioLibraryDTO { throw AudioError.unavailable }
    func manifest(bookID: Int, account: String) async throws -> AudioManifestDTO { throw AudioError.unavailable }
    func saveProgress(_ write: AudioProgressWrite, account: String) async throws -> AudioProgressResponseDTO { throw AudioError.unavailable }
    func bookmark(bookID: Int, chapterID: Int, position: Double, label: String, account: String) async throws -> AudioBookmarkDTO { throw AudioError.unavailable }
    func deleteBookmark(bookID: Int, bookmarkID: Int, account: String) async throws { throw AudioError.unavailable }
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T { try JSONDecoder().decode(type, from: Data(json.utf8)) }
}
