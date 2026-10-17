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
    func testFailedChangedCriteriaClearsOldBooksAndRetryStartsNewCriteriaAtPageOne() async throws {
        let service = ControlledAudioCatalogService()
        let model = AudioCatalogModel(repository: service)
        let initial = Task { await model.load() }
        await service.waitForRequestCount(1)
        try await service.succeed(0, bookIDs: [1], page: 1, pages: 3)
        await initial.value
        XCTAssertEqual(model.books.map(\.id), [1]); XCTAssertTrue(model.hasMore)

        let changed = Task { await model.apply { $0.category = 7; $0.author = "New author" } }
        await service.waitForRequestCount(2)
        XCTAssertTrue(model.loading)
        XCTAssertEqual(model.books, []); XCTAssertNil(model.catalog); XCTAssertFalse(model.hasMore)
        XCTAssertEqual(model.categories.map(\.id), [6, 7]); XCTAssertEqual(model.hero?.id, 99)
        await service.fail(1, error: .unavailable)
        await changed.value
        XCTAssertNotNil(model.error); XCTAssertEqual(model.books, []); XCTAssertFalse(model.hasMore)
        await service.setRejectAdditionalRequests(true)
        await model.more(); await model.load(append: true)
        let afterFailedReset = await service.requests
        XCTAssertEqual(afterFailedReset.count, 2, "A failed page-one reset must not request or append page two")
        guard afterFailedReset.count == 2 else { return } // An unsafe baseline must fail without waiting for an invalid request.
        await service.setRejectAdditionalRequests(false)

        let retry = Task { await model.retry() }
        await service.waitForRequestCount(3)
        let retriedRequests = await service.requests
        XCTAssertEqual(retriedRequests[2].category, 7); XCTAssertEqual(retriedRequests[2].author, "New author")
        XCTAssertEqual(retriedRequests[2].page, 1)
        try await service.succeed(2, bookIDs: [71], page: 1, pages: 2, includeMetadata: false)
        await retry.value
        XCTAssertNil(model.error); XCTAssertEqual(model.books.map(\.id), [71]); XCTAssertTrue(model.hasMore)
        XCTAssertEqual(model.categories.map(\.id), [6, 7]); XCTAssertEqual(model.hero?.id, 99)

        let append = Task { await model.more() }
        await service.waitForRequestCount(4)
        try await service.succeed(3, bookIDs: [71, 72], page: 2, pages: 2)
        await append.value
        XCTAssertEqual(model.books.map(\.id), [71, 72]); XCTAssertFalse(model.hasMore)
        let requests = await service.requests
        XCTAssertEqual(requests.map(\.page), [1, 1, 1, 2]); XCTAssertEqual(requests.map(\.category), [0, 7, 7, 7])
    }
    func testInitialCatalogFailureCannotRequestMoreWithoutSuccessfulPageOne() async {
        let service = ControlledAudioCatalogService()
        let model = AudioCatalogModel(repository: service)
        let initial = Task { await model.load() }
        await service.waitForRequestCount(1)
        await service.fail(0, error: .unavailable)
        await initial.value
        XCTAssertNotNil(model.error); XCTAssertTrue(model.books.isEmpty); XCTAssertFalse(model.hasMore)
        await service.setRejectAdditionalRequests(true)
        await model.more(); await model.load(append: true)
        let requests = await service.requests
        XCTAssertEqual(requests.map(\.page), [1])
    }
    func testSameCriteriaRefreshFailureKeepsValidBooksAndSuccessfulPagination() async throws {
        let service = ControlledAudioCatalogService()
        let model = AudioCatalogModel(repository: service)
        let initial = Task { await model.load() }
        await service.waitForRequestCount(1)
        try await service.succeed(0, bookIDs: [1], page: 1, pages: 3)
        await initial.value
        let second = Task { await model.more() }
        await service.waitForRequestCount(2)
        try await service.succeed(1, bookIDs: [2], page: 2, pages: 3)
        await second.value

        let refresh = Task { await model.load() }
        await service.waitForRequestCount(3)
        XCTAssertEqual(model.books.map(\.id), [1, 2])
        await service.fail(2, error: .unavailable)
        await refresh.value
        XCTAssertEqual(model.books.map(\.id), [1, 2]); XCTAssertEqual(model.filters.page, 2)
        XCTAssertEqual(model.catalog?.pagination.page, 2); XCTAssertTrue(model.hasMore); XCTAssertNotNil(model.error)

        let retry = Task { await model.retry() }
        await service.waitForRequestCount(4)
        let requests = await service.requests
        XCTAssertEqual(requests.map(\.page), [1, 2, 1, 1], "Refresh retry must replace page one rather than append another page")
        try await service.succeed(3, bookIDs: [11], page: 1, pages: 2)
        await retry.value
        XCTAssertEqual(model.books.map(\.id), [11]); XCTAssertEqual(model.filters.page, 1); XCTAssertNil(model.error)
    }
    func testLateOldCriteriaSuccessCannotRestoreBooksOrClearNewCriteriaError() async throws {
        let service = ControlledAudioCatalogService()
        let model = AudioCatalogModel(repository: service)
        let old = Task { await model.load() }
        await service.waitForRequestCount(1)
        let current = Task { await model.apply { $0.narrator = "Current narrator" } }
        await service.waitForRequestCount(2)
        await service.fail(1, error: .unavailable)
        await current.value
        let currentError = model.error
        XCTAssertEqual(currentError, AudioL10n.error(AudioError.unavailable))
        try await service.succeed(0, bookIDs: [1], page: 1, pages: 8)
        await old.value
        XCTAssertEqual(model.error, currentError); XCTAssertTrue(model.books.isEmpty); XCTAssertNil(model.catalog)
        XCTAssertFalse(model.hasMore); XCTAssertFalse(model.loading); XCTAssertEqual(model.filters.narrator, "Current narrator")

        let retry = Task { await model.retry() }
        await service.waitForRequestCount(3)
        let requests = await service.requests
        XCTAssertEqual(requests[2].narrator, "Current narrator"); XCTAssertEqual(requests[2].page, 1)
        try await service.succeed(2, bookIDs: [71], page: 1, pages: 1)
        await retry.value
        XCTAssertEqual(model.books.map(\.id), [71]); XCTAssertNil(model.error)
    }
    func testLateOldCriteriaFailureCannotOverwriteCurrentSuccessfulBooks() async throws {
        let service = ControlledAudioCatalogService()
        let model = AudioCatalogModel(repository: service)
        let old = Task { await model.load() }
        await service.waitForRequestCount(1)
        let current = Task { await model.apply { $0.query = "Current story"; $0.language = "Türkçe" } }
        await service.waitForRequestCount(2)
        try await service.succeed(1, bookIDs: [71], page: 1, pages: 2)
        await current.value
        await service.fail(0, error: .authenticationRequired)
        await old.value
        XCTAssertEqual(model.books.map(\.id), [71]); XCTAssertNil(model.error); XCTAssertTrue(model.hasMore)
        XCTAssertEqual(model.filters.query, "Current story"); XCTAssertEqual(model.filters.language, "Türkçe")
        XCTAssertFalse(model.loading)
    }
    func testServerFormattedListeningStatsAreNotConvertedToZero() {
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("3 sa 5 dk"), "3 sa 5 dk")
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("20 dk"), "20 dk")
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("0 sn"), "0 sn")
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("3660"), AudioL10n.duration(3660))
        XCTAssertEqual(AudioPresentationPolicy.serverDuration("23"), AudioL10n.format("seconds", 23))
    }
}

private actor ControlledAudioCatalogService: AudioServing {
    private(set) var requests: [AudioFilters] = []
    private var pending: [Int: CheckedContinuation<AudioCatalogDTO, Error>] = [:]
    private var requestWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var rejectAdditionalRequests = false
    func setRejectAdditionalRequests(_ value: Bool) { rejectAdditionalRequests = value }
    func catalog(filters: AudioFilters) async throws -> AudioCatalogDTO {
        let index = requests.count
        requests.append(filters)
        if rejectAdditionalRequests { throw AudioError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            let ready = requestWaiters.filter { requests.count >= $0.0 }
            requestWaiters.removeAll { requests.count >= $0.0 }
            ready.forEach { $0.1.resume() }
        }
    }
    func waitForRequestCount(_ count: Int) async {
        guard requests.count < count else { return }
        await withCheckedContinuation { requestWaiters.append((count, $0)) }
    }
    func succeed(_ index: Int, bookIDs: [Int], page: Int, pages: Int, includeMetadata: Bool = true) throws {
        let responseBooks: [[String: Any]] = bookIDs.map { ["thread_id": $0, "title": "Book \($0)"] }
        let responseCategories: [[String: Any]] = includeMetadata
            ? [["id": 6, "title": "Roman", "count": 3], ["id": 7, "title": "Edebiyat", "count": 2]] : []
        var payload: [String: Any] = [
            "api_version": 1,
            "books": responseBooks,
            "categories": responseCategories,
            "pagination": ["page": page, "pages": pages, "total": 3]
        ]
        if includeMetadata { payload["hero"] = ["thread_id": 99, "title": "Browse recommendation"] }
        let result = try JSONDecoder().decode(AudioCatalogDTO.self, from: JSONSerialization.data(withJSONObject: payload))
        guard let continuation = pending.removeValue(forKey: index) else { throw ControlledAudioCatalogFailure.missingRequest }
        continuation.resume(returning: result)
    }
    func fail(_ index: Int, error: AudioError) { pending.removeValue(forKey: index)?.resume(throwing: error) }
    func detail(bookID: Int) async throws -> AudioDetailDTO { throw AudioError.unavailable }
    func library(tab: AudioLibraryTab, account: String) async throws -> AudioLibraryDTO { throw AudioError.unavailable }
    func manifest(bookID: Int, account: String) async throws -> AudioManifestDTO { throw AudioError.unavailable }
    func saveProgress(_ write: AudioProgressWrite, account: String) async throws -> AudioProgressResponseDTO { throw AudioError.unavailable }
    func shelf(bookID: Int, field: AudioShelfField, value: Bool, account: String) async throws { throw AudioError.unavailable }
    func bookmark(bookID: Int, chapterID: Int, position: Double, label: String, account: String) async throws -> AudioBookmarkDTO { throw AudioError.unavailable }
    func deleteBookmark(bookID: Int, bookmarkID: Int, account: String) async throws { throw AudioError.unavailable }
}

private enum ControlledAudioCatalogFailure: Error { case missingRequest }

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
