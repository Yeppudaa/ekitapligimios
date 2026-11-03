import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class DirectoryListModelTests: XCTestCase {
    func testLetterFindsAuthorBeyondMultipleNonmatchingCandidatePages() async throws {
        let pages = try [page(["Franz Kafka"], number: 1, last: 4), page(["Aziz Nesin"], number: 2, last: 4),
                         page(["Zülfü Livaneli"], number: 3, last: 4), page(["Zygmunt Bauman"], number: 4, last: 4)]
        let calls = DirectoryCalls()
        let model = make { number, query in
            await calls.record(number, query)
            return pages[number - 1]
        }
        let filter = DirectoryFilter(letter: "Z")
        await model.load(filter: filter, reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Zülfü Livaneli", "Zygmunt Bauman"])
        XCTAssertEqual(model.currentPage, 4)
        XCTAssertFalse(model.hasMore)
        await model.load(filter: filter, reset: false)
        XCTAssertEqual(model.items.map(\.name), ["Zülfü Livaneli", "Zygmunt Bauman"])
        XCTAssertFalse(model.hasMore)
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.map(\.0), [1, 2, 3, 4])
        XCTAssertEqual(recorded.map(\.1), ["Z", "Z", "Z", "Z"])
    }

    func testPublisherDottedInitialScansPastDotlessCandidates() async throws {
        let pages = try [page(["Işık Yayınları"], number: 1, last: 2), page(["İletişim Yayınları"], number: 2, last: 2)]
        let model = make(kind: .publisher) { number, _ in pages[number - 1] }
        await model.load(filter: DirectoryFilter(letter: "İ"), reset: true)
        XCTAssertEqual(model.items.map(\.name), ["İletişim Yayınları"])
        XCTAssertNil(model.errorMessage)
    }

    func testAllDirectoryPagesRemainReachableAndDeduplicateWithinAndAcrossPages() async throws {
        let pages = try [page(["Ada", "Ada", "Bora"], number: 1, last: 2), page(["Bora", "Zeynep"], number: 2, last: 2)]
        let model = make { number, _ in pages[number - 1] }
        await model.load(filter: DirectoryFilter(), reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Ada", "Bora"])
        await model.load(filter: DirectoryFilter(), reset: false)
        XCTAssertEqual(model.items.map(\.name), ["Ada", "Bora", "Zeynep"])
        XCTAssertFalse(model.hasMore)
    }

    func testSearchAndLetterIntersectAndClearingRestartsAtFirstPage() async throws {
        let searched = try page(["Elif Şafak", "Şafak Pavey"])
        let all = try page(["Ahmet Hamdi Tanpınar"])
        let calls = DirectoryCalls()
        let model = make { number, query in
            await calls.record(number, query)
            return query == nil ? all : searched
        }
        await model.load(filter: DirectoryFilter(query: "şafak", letter: "E"), reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Elif Şafak"])
        await model.load(filter: DirectoryFilter(), reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Ahmet Hamdi Tanpınar"])
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.map(\.0), [1, 1])
        XCTAssertEqual(recorded.map(\.1), ["şafak", nil])
    }

    func testOldLetterResponseCannotReplaceNewSelectionEvenDuringDebounce() async throws {
        let old = try page(["Ahmet"])
        let new = try page(["Zülfü"])
        let started = expectation(description: "A request started")
        let gate = DirectoryGate(value: old, started: started)
        let model = make { _, query in query == "A" ? await gate.run() : new }
        let oldTask = Task { await model.load(filter: DirectoryFilter(letter: "A"), reset: true) }
        await fulfillment(of: [started], timeout: 3)
        model.select(DirectoryFilter(letter: "Z"))
        await gate.release()
        await oldTask.value
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.isLoading)
        await model.load(filter: DirectoryFilter(letter: "Z"), reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Zülfü"])
        XCTAssertFalse(model.isLoading)
    }

    func testPaginationFailurePreservesRowsAndRetriesSameCursor() async throws {
        let first = try page(["Ada"], number: 1, last: 2)
        let second = try page(["Bora"], number: 2, last: 2)
        let calls = DirectoryCalls()
        let model = make { number, query in
            let count = await calls.record(number, query)
            if count == 2 { throw DirectoryTestError.offline }
            return number == 1 ? first : second
        }
        await model.load(filter: DirectoryFilter(), reset: true)
        await model.load(filter: DirectoryFilter(), reset: false)
        XCTAssertEqual(model.items.map(\.name), ["Ada"])
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertTrue(model.hasMore)
        await model.load(filter: DirectoryFilter(), reset: false)
        XCTAssertEqual(model.items.map(\.name), ["Ada", "Bora"])
        XCTAssertNil(model.errorMessage)
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.map(\.0), [1, 2, 2])
    }

    func testFailureWhileSkippingEmptyCandidatesResumesWithoutLosingMatches() async throws {
        let first = try page(["Franz Kafka"], number: 1, last: 2)
        let second = try page(["Zülfü"], number: 2, last: 2)
        let calls = DirectoryCalls()
        let model = make { number, query in
            let count = await calls.record(number, query)
            if count == 2 { throw DirectoryTestError.offline }
            return number == 1 ? first : second
        }
        let filter = DirectoryFilter(letter: "Z")
        await model.load(filter: filter, reset: true)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.hasMore)
        await model.load(filter: filter, reset: false)
        XCTAssertEqual(model.items.map(\.name), ["Zülfü"])
    }

    func testEmptyOnlyAfterAllCandidatesAndRepeatedCursorCannotLoop() async throws {
        let first = try page(["Franz Kafka"], number: 1, last: 2)
        let final = try page(["Aziz Nesin"], number: 2, last: 2)
        let model = make { number, _ in number == 1 ? first : final }
        await model.load(filter: DirectoryFilter(letter: "Z"), reset: true)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertEqual(model.currentPage, 2)
        XCTAssertFalse(model.hasMore)
        XCTAssertNil(model.errorMessage)
        let malformed = make { _, _ in first }
        await malformed.load(filter: DirectoryFilter(letter: "Z"), reset: true)
        XCTAssertNotNil(malformed.errorMessage)
        XCTAssertEqual(malformed.currentPage, 1)
        XCTAssertFalse(malformed.isLoading)
    }

    func testOptionalStatsFailureDoesNotHideSuccessfulResults() async throws {
        let result = try page(["Ada"])
        let model = make { _, _ in result }
        await model.loadStatistics()
        await model.load(filter: DirectoryFilter(), reset: true)
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.totalEntries, 1)
        XCTAssertNil(model.errorMessage)
    }

    func testStatsStayGlobalWhenLetterChanges() async throws {
        let result = try page(["Zülfü"])
        let camelStats = try JSONDecoder().decode(SiteStatsDTO.self, from: Data(#"{"totalBooks":400,"totalAuthors":200,"totalPublishers":90}"#.utf8))
        let model = DirectoryListModel()
        model.configure(kind: .publisher, loadPage: { _, _ in result }, loadStats: { camelStats })
        await model.loadStatistics()
        await model.load(filter: DirectoryFilter(letter: "Z"), reset: true)
        XCTAssertEqual(model.totalEntries, 90)
        XCTAssertEqual(model.totalBooks, 400)
    }

    func testPartialStatisticsCannotReplaceKnownDirectoryCountsWithZero() async throws {
        let result = try page(["Ada"])
        let partial = try JSONDecoder().decode(SiteStatsDTO.self, from: Data("{}".utf8))
        let model = DirectoryListModel()
        model.configure(kind: .author, loadPage: { _, _ in result }, loadStats: { partial })
        await model.loadStatistics()
        await model.load(filter: DirectoryFilter(), reset: true)
        XCTAssertEqual(model.totalEntries, 1)
        XCTAssertEqual(model.totalBooks, 2)
    }

    func testSparseInitialPagesAccumulateThirtyMatchesAndReachEveryResultForBothDirectories() async throws {
        for kind in DirectoryKind.allCases {
            let names = (1...67).map { "C \(kind.rawValue) \($0)" }
            let pages = try names.enumerated().map { index, name in
                try page(["Alice \(index)", name], number: index + 1, last: names.count)
            }
            let calls = DirectoryCalls()
            let model = make(kind: kind) { number, query in
                await calls.record(number, query)
                return pages[number - 1]
            }
            let selection = DirectoryFilter(letter: "C")
            await model.load(filter: selection, reset: true)
            XCTAssertEqual(model.items.count, 30, "One match per server page must not end the display batch")
            XCTAssertEqual(model.currentPage, 30)
            XCTAssertTrue(model.hasMore)
            await model.load(filter: selection, reset: false)
            XCTAssertEqual(model.items.count, 60)
            XCTAssertTrue(model.hasMore)
            await model.load(filter: selection, reset: false)
            XCTAssertEqual(model.items.map(\.name), names)
            XCTAssertFalse(model.hasMore)
            let recorded = await calls.snapshot
            XCTAssertEqual(recorded.map(\.0), Array(1...67))
            XCTAssertTrue(recorded.allSatisfy { $0.1 == "C" })
        }
    }

    func testBatchKeepsOverflowFromWholePageInsteadOfDroppingMatchesPastThirty() async throws {
        let names = (1...65).map { "D Yazar \($0)" }
        let pages = try [page(Array(names.prefix(20)), number: 1, last: 3),
                         page(Array(names[20..<40]), number: 2, last: 3),
                         page(Array(names.suffix(25)), number: 3, last: 3)]
        let model = make { number, _ in pages[number - 1] }
        let filter = DirectoryFilter(letter: "D")
        await model.load(filter: filter, reset: true)
        XCTAssertEqual(model.items.count, 40)
        XCTAssertEqual(model.currentPage, 2)
        await model.load(filter: filter, reset: false)
        XCTAssertEqual(model.items.map(\.name), names)
        XCTAssertFalse(model.hasMore)
    }

    func testPartialBatchFailurePreservesMatchesAndRetryReachesRemainingResults() async throws {
        let pages = try [page(["Cem"], number: 1, last: 3), page(["Cengiz"], number: 2, last: 3),
                         page(["Carl"], number: 3, last: 3)]
        let calls = DirectoryCalls()
        let model = make { number, query in
            let call = await calls.record(number, query)
            if call == 2 { throw DirectoryTestError.offline }
            return pages[number - 1]
        }
        let selection = DirectoryFilter(letter: "C")
        await model.load(filter: selection, reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Cem"])
        XCTAssertNotNil(model.errorMessage)
        await model.load(filter: selection, reset: false)
        XCTAssertEqual(model.items.map(\.name), ["Cem", "Cengiz", "Carl"])
        XCTAssertNil(model.errorMessage)
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.map(\.0), [1, 2, 2, 3])
    }

    func testChangingLetterWhileCollectingBatchStopsOldPagesAndClearsPartialResults() async throws {
        let first = try page(["Cem"], number: 1, last: 3)
        let delayed = try page(["Cengiz"], number: 2, last: 3)
        let new = try page(["Dost"])
        let started = expectation(description: "Second candidate page started")
        let gate = DirectoryGate(value: delayed, started: started)
        let calls = DirectoryCalls()
        let model = make { number, query in
            await calls.record(number, query)
            if query == "D" { return new }
            return number == 1 ? first : await gate.run()
        }
        let task = Task { await model.load(filter: DirectoryFilter(letter: "C"), reset: true) }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(model.items.map(\.name), ["Cem"])
        await model.load(filter: DirectoryFilter(letter: "D"), reset: true)
        await gate.release()
        await task.value
        XCTAssertEqual(model.items.map(\.name), ["Dost"])
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.map(\.0), [1, 2, 1])
        XCTAssertFalse(model.isLoading)
    }

    func testLeavingDirectoryStopsBatchWithoutFetchingRemainingPages() async throws {
        let first = try page(["Cem"], number: 1, last: 20)
        let delayed = try page(["Cengiz"], number: 2, last: 20)
        let started = expectation(description: "Batch page suspended")
        let gate = DirectoryGate(value: delayed, started: started)
        let calls = DirectoryCalls()
        let model = make { number, query in
            await calls.record(number, query)
            return number == 1 ? first : await gate.run()
        }
        let task = Task { await model.load(filter: DirectoryFilter(letter: "C"), reset: true) }
        await fulfillment(of: [started], timeout: 3)
        model.cancelLoading()
        await gate.release()
        await task.value
        XCTAssertEqual(model.items.map(\.name), ["Cem"])
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.map(\.0), [1, 2])
    }

    func testFirstRowsAndFinishedLoadingDoNotWaitForSlowStatistics() async throws {
        let result = try page(["Cem"])
        let stats = try JSONDecoder().decode(SiteStatsDTO.self, from: Data(#"{"totalAuthors":400,"totalBooks":900}"#.utf8))
        let started = expectation(description: "Optional stats suspended")
        let gate = DirectoryStatsGate(value: stats, started: started)
        let model = DirectoryListModel()
        model.configure(kind: .author, loadPage: { _, _ in result }, loadStats: { await gate.run() })
        let counters = Task { await model.loadStatistics() }
        await fulfillment(of: [started], timeout: 3)
        await model.load(filter: DirectoryFilter(letter: "C"), reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Cem"])
        XCTAssertFalse(model.isLoading, "Even loading completion is independent from counters")
        XCTAssertNotEqual(model.totalBooks, 900)
        await gate.release()
        await counters.value
        XCTAssertEqual(model.totalBooks, 900)
        XCTAssertEqual(model.totalEntries, 400)
    }

    func testFirstMatchingRowsAppearBeforeTheRestOfBatchArrives() async throws {
        let first = try page(["Cem"], number: 1, last: 2)
        let second = try page(["Cengiz"], number: 2, last: 2)
        let started = expectation(description: "Slow second candidate page")
        let gate = DirectoryGate(value: second, started: started)
        let model = make { number, _ in number == 1 ? first : await gate.run() }
        let task = Task { await model.load(filter: DirectoryFilter(letter: "C"), reset: true) }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(model.items.map(\.name), ["Cem"])
        XCTAssertTrue(model.isLoading)
        await gate.release()
        await task.value
        XCTAssertEqual(model.items.map(\.name), ["Cem", "Cengiz"])
    }

    func testReturningToLetterUsesMemoryAndResumesCorrectPaginationCursor() async throws {
        let names = (1...35).map { "C Yazar \($0)" }
        let first = try page(Array(names.prefix(30)), number: 1, last: 2)
        let second = try page(Array(names.suffix(5)), number: 2, last: 2)
        let other = try page(["Dost"])
        let calls = DirectoryCalls()
        let model = make { number, query in
            await calls.record(number, query)
            if query == "D" { return other }
            return number == 1 ? first : second
        }
        let selected = DirectoryFilter(letter: "C")
        await model.load(filter: selected, reset: true)
        await model.load(filter: DirectoryFilter(letter: "D"), reset: true)
        await model.load(filter: selected, reset: true)
        let cachedCalls = await calls.snapshot
        XCTAssertEqual(cachedCalls.count, 2, "A repeated letter needs zero new HTTP requests")
        XCTAssertEqual(model.items.count, 30)
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertTrue(model.hasMore)
        await model.load(filter: selected, reset: false)
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.map(\.0), [1, 1, 2])
        XCTAssertEqual(model.items.map(\.name), names)
        XCTAssertFalse(model.hasMore)
    }

    func testExplicitRefreshAndExpiredSnapshotFetchFreshServerRows() async throws {
        let clock = DirectoryTestClock()
        let first = try page(["Cem"])
        let updated = try page(["Cengiz"])
        let calls = DirectoryCalls()
        let model = DirectoryListModel(now: { clock.date })
        model.configure(kind: .author, loadPage: { number, query in
            await calls.record(number, query) == 1 ? first : updated
        }, loadStats: { throw DirectoryTestError.offline })
        let selected = DirectoryFilter(letter: "C")
        await model.load(filter: selected, reset: true)
        clock.date += 119
        await model.load(filter: selected, reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Cem"])
        clock.date += 1
        await model.load(filter: selected, reset: true)
        XCTAssertEqual(model.items.map(\.name), ["Cengiz"])
        await model.load(filter: selected, reset: true, forceRefresh: true)
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.count, 3)
    }

    func testSnapshotIsBoundedAndCannotCrossDirectoryKinds() async throws {
        let result = try page(["A", "B", "C", "D", "E", "F", "G"])
        let calls = DirectoryCalls()
        let model = make { number, query in await calls.record(number, query); return result }
        for letter in ["A", "B", "C", "D", "E", "F", "G"] {
            await model.load(filter: DirectoryFilter(letter: letter), reset: true)
        }
        XCTAssertFalse(model.hasFreshSnapshot(for: DirectoryFilter(letter: "A")))
        XCTAssertTrue(model.hasFreshSnapshot(for: DirectoryFilter(letter: "G")))
        model.configure(kind: .publisher, loadPage: { number, query in await calls.record(number, query); return result },
                        loadStats: { throw DirectoryTestError.offline })
        XCTAssertFalse(model.hasFreshSnapshot(for: DirectoryFilter(letter: "G")))
        await model.load(filter: DirectoryFilter(letter: "G"), reset: true)
        let recorded = await calls.snapshot
        XCTAssertEqual(recorded.count, 8)
    }

    func testChangingLetterCancelsOldTransportInsteadOfOnlyIgnoringItsResponse() async throws {
        let new = try page(["Dost"])
        let started = expectation(description: "Old transport started")
        let cancelled = expectation(description: "Old transport cancelled")
        let model = make { _, query in
            if query == "C" {
                started.fulfill()
                do { try await Task.sleep(for: .seconds(60)) }
                catch { cancelled.fulfill(); throw error }
            }
            return new
        }
        let oldTask = Task { await model.load(filter: DirectoryFilter(letter: "C"), reset: true) }
        await fulfillment(of: [started], timeout: 3)
        await model.load(filter: DirectoryFilter(letter: "D"), reset: true)
        await fulfillment(of: [cancelled], timeout: 3)
        await oldTask.value
        XCTAssertEqual(model.items.map(\.name), ["Dost"])
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    private func make(kind: DirectoryKind = .author, load: @escaping DirectoryListModel.LoadPage) -> DirectoryListModel {
        let model = DirectoryListModel()
        model.configure(kind: kind, loadPage: load, loadStats: { throw DirectoryTestError.offline })
        return model
    }

    private func page(_ names: [String], number: Int = 1, last: Int = 1) throws -> DirectoryPageDTO {
        let rows = names.map { ["id": $0, "name": $0, "bookCount": 2] as [String: Any] }
        let data = try JSONSerialization.data(withJSONObject: ["items": rows, "pagination": ["page": number, "pages": last, "total": names.count]])
        return try JSONDecoder().decode(DirectoryPageDTO.self, from: data)
    }
}

private enum DirectoryTestError: Error { case offline }
@MainActor private final class DirectoryTestClock { var date = Date(timeIntervalSince1970: 1_000) }
private actor DirectoryStatsGate {
    let value: SiteStatsDTO
    let started: XCTestExpectation
    var continuation: CheckedContinuation<SiteStatsDTO, Never>?
    init(value: SiteStatsDTO, started: XCTestExpectation) { self.value = value; self.started = started }
    func run() async -> SiteStatsDTO { await withCheckedContinuation { continuation = $0; started.fulfill() } }
    func release() { continuation?.resume(returning: value); continuation = nil }
}
private actor DirectoryCalls {
    var snapshot: [(Int, String?)] = []
    @discardableResult func record(_ page: Int, _ query: String?) -> Int {
        snapshot.append((page, query)); return snapshot.count
    }
}
private actor DirectoryGate {
    let value: DirectoryPageDTO
    let started: XCTestExpectation
    var continuation: CheckedContinuation<DirectoryPageDTO, Never>?
    init(value: DirectoryPageDTO, started: XCTestExpectation) { self.value = value; self.started = started }
    func run() async -> DirectoryPageDTO {
        await withCheckedContinuation { continuation = $0; started.fulfill() }
    }
    func release() { continuation?.resume(returning: value); continuation = nil }
}
