import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class LiveActivityModelTests: XCTestCase {
    func testAcknowledgementDuringInitialLoadQueuesOneFreshServerRead() async throws {
        let model = LiveActivityModel()
        let oldPage = try page([1])
        let acknowledgedPage = try page([3, 2, 1], types: ["reading", "favorite", "comment"])
        let started = expectation(description: "Initial feed request suspended")
        let gate = ActivityFeedGate(value: oldPage, started: started)
        let calls = ActivityFeedCalls()
        model.configure(loadPage: { _, before, userID in
            let request = await calls.record(before: before, userID: userID)
            return request == 1 ? await gate.run() : acknowledgedPage
        }, sessionID: UUID(), userID: nil)

        let load = Task { await model.load(reset: true) }
        await fulfillment(of: [started], timeout: 3)
        await model.refreshLatest()
        await model.refreshLatest()
        await model.refreshLatest()
        await gate.release()
        await load.value

        XCTAssertEqual(model.items.map(\.id), ["3", "2", "1"])
        XCTAssertEqual(model.items.map(\.type), ["reading", "favorite", "comment"])
        let count = await calls.count
        XCTAssertEqual(count, 2, "Acknowledgements are coalesced without dropping the required refresh")
        XCTAssertFalse(model.isLoading)
    }

    func testAcknowledgementDuringPaginationKeepsHistoryAndPaginationCursor() async throws {
        let model = LiveActivityModel()
        let initial = try page([10], nextBefore: 10)
        let older = try page([9, 8], nextBefore: 8)
        let latest = try page([12, 11, 10], nextBefore: 10)
        let final = try page([7])
        let started = expectation(description: "Older page suspended")
        let gate = ActivityFeedGate(value: older, started: started)
        let calls = ActivityFeedCalls()
        model.configure(loadPage: { _, before, userID in
            let request = await calls.record(before: before, userID: userID)
            if before == 10 { return await gate.run() }
            if before == 8 { return final }
            return request == 1 ? initial : latest
        }, sessionID: UUID(), userID: "reader-1")
        await model.load(reset: true)

        let pagination = Task { await model.load(reset: false) }
        await fulfillment(of: [started], timeout: 3)
        await model.refreshLatest()
        await gate.release()
        await pagination.value
        XCTAssertEqual(model.items.map(\.id), ["12", "11", "10", "9", "8"])
        await model.load(reset: false)

        XCTAssertEqual(model.items.map(\.id), ["12", "11", "10", "9", "8", "7"])
        let cursors = await calls.before
        XCTAssertEqual(cursors, [nil, 10, nil, 8])
        let users = await calls.users
        XCTAssertEqual(users, Array(repeating: "reader-1", count: 4))
        XCTAssertFalse(model.hasMore)
    }

    func testManualResetTakesPriorityOverQueuedIncrementalRefresh() async throws {
        let model = LiveActivityModel()
        let initial = try page([3, 2, 1])
        let latest = try page([4, 3])
        let started = expectation(description: "Latest feed suspended")
        let gate = ActivityFeedGate(value: latest, started: started)
        let calls = ActivityFeedCalls()
        model.configure(loadPage: { _, before, userID in
            let count = await calls.record(before: before, userID: userID)
            switch count {
            case 1: return initial
            case 2: return await gate.run()
            default: return latest
            }
        }, sessionID: UUID(), userID: nil)
        await model.load(reset: true)
        let refresh = Task { await model.refreshLatest() }
        await fulfillment(of: [started], timeout: 3)
        await model.load(reset: true)
        await model.refreshLatest()
        await gate.release()
        await refresh.value

        XCTAssertEqual(model.items.map(\.id), ["4", "3"], "A manual refresh replaces the full visible snapshot")
        let count = await calls.count
        XCTAssertEqual(count, 3)
    }

    func testAccountChangeRejectsOldFeedAndQueuedRefresh() async throws {
        let model = LiveActivityModel()
        let old = try page([1])
        let guest = try page([2])
        let started = expectation(description: "Account-specific feed suspended")
        let gate = ActivityFeedGate(value: old, started: started)
        model.configure(loadPage: { _, _, _ in await gate.run() }, sessionID: UUID(), userID: "old-account")
        let oldLoad = Task { await model.load(reset: true) }
        await fulfillment(of: [started], timeout: 3)
        await model.refreshLatest()

        model.configure(loadPage: { _, _, _ in guest }, sessionID: UUID(), userID: nil)
        XCTAssertTrue(model.items.isEmpty)
        await model.load(reset: true)
        await gate.release()
        await oldLoad.value

        XCTAssertEqual(model.items.map(\.id), ["2"])
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.isLoadingMore)
    }

    func testTransientLatestFailurePreservesPreviouslyLoadedServerRows() async throws {
        let model = LiveActivityModel()
        let initial = try page([1])
        let identity = UUID()
        model.configure(loadPage: { _, _, _ in initial }, sessionID: identity, userID: nil)
        await model.load(reset: true)
        model.configure(loadPage: { _, _, _ in throw ActivityFeedError.offline }, sessionID: identity, userID: nil)

        await model.refreshLatest()

        XCTAssertEqual(model.items.map(\.id), ["1"])
        XCTAssertNil(model.errorMessage)
        await model.load(reset: true)
        XCTAssertEqual(model.items.map(\.id), ["1"])
        XCTAssertNotNil(model.errorMessage)
    }

    func testDuplicateServerRowsRemainUniqueAcrossRefreshAndPagination() async throws {
        let model = LiveActivityModel()
        let initial = try page([4, 4, 3], nextBefore: 3)
        let older = try page([3, 2, 2, 1])
        let latest = try page([5, 5, 4])
        let identity = UUID()
        model.configure(loadPage: { _, before, _ in before == nil ? initial : older }, sessionID: identity, userID: nil)
        await model.load(reset: true)
        await model.load(reset: false)
        model.configure(loadPage: { _, _, _ in latest }, sessionID: identity, userID: nil)
        await model.refreshLatest()

        XCTAssertEqual(model.items.map(\.id), ["5", "4", "3", "2", "1"])
    }

    func testCancelledLoadCanBeRetriedAfterPageBecomesVisibleAgain() async throws {
        let model = LiveActivityModel()
        let cancelled = try page([1])
        let visible = try page([2])
        let identity = UUID()
        let started = expectation(description: "Cancelled request suspended")
        let gate = ActivityFeedGate(value: cancelled, started: started)
        model.configure(loadPage: { _, _, _ in await gate.run() }, sessionID: identity, userID: nil)
        let load = Task { await model.load(reset: true) }
        await fulfillment(of: [started], timeout: 3)
        load.cancel()
        await gate.release()
        await load.value
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)

        model.configure(loadPage: { _, _, _ in visible }, sessionID: identity, userID: nil)
        await model.load(reset: true)
        XCTAssertEqual(model.items.map(\.id), ["2"])
    }

    func testReturningBeforeCancelledRequestCompletesStillLoadsVisibleFeed() async throws {
        let model = LiveActivityModel()
        let old = try page([1])
        let visible = try page([2])
        let started = expectation(description: "Old visibility task suspended")
        let gate = ActivityFeedGate(value: old, started: started)
        let calls = ActivityFeedCalls()
        model.configure(loadPage: { _, before, userID in
            let count = await calls.record(before: before, userID: userID)
            return count == 1 ? await gate.run() : visible
        }, sessionID: UUID(), userID: nil)
        let oldLoad = Task { await model.load(reset: true) }
        await fulfillment(of: [started], timeout: 3)
        oldLoad.cancel()
        // The new foreground task requests its reset while URLSession still tears down the old read.
        await model.load(reset: true)
        await gate.release()
        await oldLoad.value

        let applied = expectation(description: "New visible feed applied without waiting for the poll timer")
        let observer = Task {
            while !Task.isCancelled {
                if model.items.map(\.id) == ["2"] { applied.fulfill(); return }
                await Task.yield()
            }
        }
        defer { observer.cancel() }
        await fulfillment(of: [applied], timeout: 3)
        let count = await calls.count
        XCTAssertEqual(count, 2)
        XCTAssertFalse(model.isLoading)
    }

    private func page(_ ids: [Int], nextBefore: Int? = nil, types: [String] = []) throws -> LiveActivityPageDTO {
        let rows = ids.enumerated().map { index, id in
            let type = types.indices.contains(index) ? types[index] : "reading"
            return "{\"id\":\"\(id)\",\"type\":\"\(type)\",\"message\":\"Server activity \(id)\",\"event_date\":\(id),\"book\":{\"id\":101,\"title\":\"Book\"}}"
        }.joined(separator: ",")
        let cursor = nextBefore.map(String.init) ?? "null"
        let json = "{\"items\":[\(rows)],\"pagination\":{\"next_before\":\(cursor),\"has_more\":\(nextBefore != nil)}}"
        return try JSONDecoder.ekitapligim.decode(LiveActivityPageDTO.self, from: Data(json.utf8))
    }
}

private enum ActivityFeedError: Error { case offline }

private actor ActivityFeedCalls {
    private(set) var before: [Int?] = []
    private(set) var users: [String?] = []
    var count: Int { before.count }
    func record(before: Int?, userID: String?) -> Int {
        self.before.append(before)
        users.append(userID)
        return count
    }
}

private actor ActivityFeedGate<Value: Sendable> {
    let value: Value
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?
    init(value: Value, started: XCTestExpectation) { self.value = value; self.started = started }
    func run() async -> Value {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
        return value
    }
    func release() { continuation?.resume(); continuation = nil }
}
