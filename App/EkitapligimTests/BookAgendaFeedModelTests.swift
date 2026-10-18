import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class BookAgendaFeedModelTests: XCTestCase {
    func testFilterChangeDiscardsDelayedOldFeed() async throws {
        let model = BookAgendaFeedModel()
        let old = try Self.page([1])
        let latest = try Self.page([2])
        let started = expectation(description: "Old feed suspended")
        let gate = AgendaFeedGate(value: old, started: started)
        configure(model, feed: { _, filter, _, _ in
            if filter == nil { return await gate.run() }
            return latest
        })
        let first = Task { await model.load(tab: .agenda, filter: nil, reset: true) }
        await fulfillment(of: [started], timeout: 3)
        await model.load(tab: .agenda, filter: "review", reset: true)
        await gate.release()
        await first.value
        XCTAssertEqual(model.posts.map(\.id), ["2"])
        XCTAssertFalse(model.isLoading)
    }

    func testRefreshDiscardsOldPaginationAndDeduplicatesItems() async throws {
        let model = BookAgendaFeedModel()
        let initial = try Self.page([1, 1], hasMore: true)
        let oldPage = try Self.page([2], hasMore: false)
        let started = expectation(description: "Old pagination suspended")
        let gate = AgendaFeedGate(value: oldPage, started: started)
        configure(model, feed: { _, _, page, _ in page == 1 ? initial : await gate.run() })
        await model.load(tab: .agenda, filter: nil, reset: true)
        XCTAssertEqual(model.posts.map(\.id), ["1"])
        let pagination = Task { await model.load(tab: .agenda, filter: nil, reset: false) }
        await fulfillment(of: [started], timeout: 3)
        await model.load(tab: .agenda, filter: nil, reset: true)
        await gate.release()
        await pagination.value
        XCTAssertEqual(model.posts.map(\.id), ["1"])
        XCTAssertFalse(model.isLoadingMore)
    }

    func testLogoutClearsPrivateFeedAndRejectsOldSessionResponse() async throws {
        let model = BookAgendaFeedModel()
        let privatePage = try Self.page([1], hasMore: true)
        let started = expectation(description: "Personal feed suspended")
        let gate = AgendaFeedGate(value: privatePage, started: started)
        let dependencies = dependencies(feed: { _, _, _, _ in await gate.run() })
        model.configure(dependencies: dependencies, signedIn: true, sessionID: "first")
        let load = Task { await model.load(tab: .personal, filter: "saved", reset: true) }
        await fulfillment(of: [started], timeout: 3)
        model.configure(dependencies: dependencies, signedIn: false, sessionID: "guest")
        await gate.release()
        await load.value
        XCTAssertTrue(model.posts.isEmpty)
        XCTAssertFalse(model.canCreate)
        XCTAssertFalse(model.hasMore)
        XCTAssertFalse(model.isLoading)
    }

    func testDoubleReactionTapSendsOneToggleAndKeepsPostIfRefreshFails() async throws {
        let model = BookAgendaFeedModel()
        let page = try Self.page([1])
        let response = try JSONDecoder.ekitapligim.decode(BookAgendaActionDTO.self, from: Data(#"{"success":true,"reacted":true}"#.utf8))
        let started = expectation(description: "Reaction suspended")
        let gate = AgendaFeedGate(value: response, started: started)
        let counter = AgendaFeedCounter()
        var deps = dependencies(feed: { _, _, _, _ in page })
        deps.react = { _ in await counter.record(); return await gate.run() }
        model.configure(dependencies: deps, signedIn: true, sessionID: "first")
        await model.load(tab: .agenda, filter: nil, reset: true)
        let post = try XCTUnwrap(model.posts.first)
        let first = Task { await model.react(post) }
        await fulfillment(of: [started], timeout: 3)
        await model.react(post)
        await gate.release()
        await first.value
        let calls = await counter.calls
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.posts.map(\.id), ["1"])
        XCTAssertNotNil(model.actionMessage)
        XCTAssertFalse(model.isMutating(postID: "1"))
    }

    func testDeletedAndBlockedPostsCannotReappearFromRefresh() async throws {
        let model = BookAgendaFeedModel()
        let page = try Self.page([1, 2, 3])
        configure(model, feed: { _, _, _, _ in page })
        await model.load(tab: .agenda, filter: nil, reset: true)
        model.remove(postID: "1")
        model.removeBlockedActor("actor2")
        await model.load(tab: .agenda, filter: nil, reset: true)
        XCTAssertEqual(model.posts.map(\.id), ["3"])
    }

    func testFailedRefreshPreservesExistingPostsAndShowsError() async throws {
        let model = BookAgendaFeedModel()
        let page = try Self.page([1])
        configure(model, feed: { _, _, _, _ in page })
        await model.load(tab: .agenda, filter: nil, reset: true)
        configure(model, feed: { _, _, _, _ in throw AgendaFeedError.unavailable })
        await model.load(tab: .agenda, filter: nil, reset: true)
        XCTAssertEqual(model.posts.map(\.id), ["1"])
        XCTAssertNotNil(model.errorMessage)
    }

    private func configure(_ model: BookAgendaFeedModel,
        feed: @escaping @Sendable (BookAgendaTab, String?, Int, Int) async throws -> BookAgendaPageDTO) {
        model.configure(dependencies: dependencies(feed: feed), signedIn: true, sessionID: "first")
    }

    private func dependencies(
        feed: @escaping @Sendable (BookAgendaTab, String?, Int, Int) async throws -> BookAgendaPageDTO
    ) -> BookAgendaFeedDependencies {
        BookAgendaFeedDependencies(feed: feed,
            post: { _ in throw AgendaFeedError.unavailable },
            react: { _ in throw AgendaFeedError.unavailable },
            bookmark: { _ in throw AgendaFeedError.unavailable },
            repost: { _ in throw AgendaFeedError.unavailable },
            follow: { _, _ in nil }, delete: { _ in })
    }

    nonisolated private static func page(_ ids: [Int], hasMore: Bool = false) throws -> BookAgendaPageDTO {
        let items: [[String: Any]] = ids.map { id in
            ["id": String(id), "message": "Fixture", "actor": ["id": "actor\(id)", "username": "Reader"],
             "viewer": ["can_react": true, "can_delete": true]]
        }
        let data = try JSONSerialization.data(withJSONObject: ["items": items,
            "pagination": ["has_more": hasMore], "capabilities": ["authenticated": true, "can_create": true]])
        return try JSONDecoder.ekitapligim.decode(BookAgendaPageDTO.self, from: data)
    }
}

private enum AgendaFeedError: Error { case unavailable }
private actor AgendaFeedCounter {
    private(set) var calls = 0
    func record() { calls += 1 }
}
private actor AgendaFeedGate<Value: Sendable> {
    let value: Value
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<Value, Never>?
    init(value: Value, started: XCTestExpectation) { self.value = value; self.started = started }
    func run() async -> Value {
        started.fulfill()
        return await withCheckedContinuation { continuation = $0 }
    }
    func release() { continuation?.resume(returning: value); continuation = nil }
}
