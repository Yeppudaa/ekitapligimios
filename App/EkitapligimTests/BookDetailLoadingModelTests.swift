import XCTest
import Combine
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class BookDetailLoadingModelTests: XCTestCase {
    func testDetailDisplaysWhileAccessAndCommentsAreStillPending() async throws {
        let model = BookDetailLoadingModel()
        let gate = DetailTestGate()
        let visible = expectation(description: "Book is visible before secondary requests finish")
        let observation = model.$isLoading.dropFirst().filter { !$0 }.sink { _ in visible.fulfill() }
        let detail = try book(42)
        let access = try accessResult()
        let comments = try commentsResult()
        let work = Task {
            await model.load(bookID: 42, detail: { detail }, access: {
                await gate.wait()
                return access
            }, comments: { _ in
                await gate.wait()
                return comments
            })
        }
        await fulfillment(of: [visible], timeout: 2)
        XCTAssertEqual(model.book?.id, "42")
        XCTAssertNil(model.access)
        XCTAssertFalse(model.isLoading)
        await gate.release()
        await work.value
        XCTAssertEqual(model.access, access)
        withExtendedLifetime(observation) {}
    }

    func testCancelledOldBookCannotOverwriteNewBookEvenIfNetworkIgnoresCancellation() async throws {
        let model = BookDetailLoadingModel()
        let gate = DetailTestGate()
        let started = expectation(description: "Old detail request started")
        let old = try book(1)
        let new = try book(2)
        let access = try accessResult()
        let comments = try commentsResult()
        let first = Task {
            await model.load(bookID: 1, detail: {
                started.fulfill()
                await gate.wait()
                return old
            }, access: { access }, comments: { _ in comments })
        }
        await fulfillment(of: [started], timeout: 2)
        model.cancel()
        await model.load(bookID: 2, detail: { new }, access: { access }, comments: { _ in comments })
        await gate.release()
        await first.value
        XCTAssertEqual(model.book?.id, "2")
        XCTAssertNil(model.errorMessage)
    }

    func testSecondaryFailuresDoNotHideSuccessfulDetail() async throws {
        enum Failure: Error { case unavailable }
        let model = BookDetailLoadingModel()
        let detail = try book(42)
        await model.load(bookID: 42, detail: { detail }, access: { throw Failure.unavailable }, comments: { _ in
            throw Failure.unavailable
        })
        XCTAssertEqual(model.book?.id, "42")
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(model.access)
        XCTAssertNotNil(model.commentsError)
        XCTAssertFalse(model.isLoadingComments)
    }

    func testConcurrentLoadMoreRequestsShareTheInFlightPage() async throws {
        let model = BookDetailLoadingModel()
        let gate = DetailTestGate()
        let started = expectation(description: "Comment request started")
        let comments = try commentsResult()
        let calls = DetailCallCounter()
        let fetch: @Sendable (Int) async throws -> BookCommentsPageDTO = { _ in
            await calls.record()
            started.fulfill()
            await gate.wait()
            return comments
        }
        let first = Task { await model.loadComments(reset: false, fetch: fetch) }
        await fulfillment(of: [started], timeout: 2)
        let secondStarted = expectation(description: "Second caller entered")
        let second = Task {
            secondStarted.fulfill()
            await model.loadComments(reset: false, fetch: fetch)
        }
        await fulfillment(of: [secondStarted], timeout: 2)
        await gate.release()
        await first.value
        await second.value
        let count = await calls.count
        XCTAssertEqual(count, 1)
    }

    private func book(_ id: Int) throws -> BookEnvelope {
        try JSONDecoder.ekitapligim.decode(BookEnvelope.self, from: Data("{\"book\":{\"id\":\"\(id)\",\"title\":\"Book\"}}".utf8))
    }

    private func accessResult() throws -> ReaderAccessDTO {
        try JSONDecoder.ekitapligim.decode(ReaderAccessDTO.self, from: Data(#"{"user_tier":"member","can_read_online":true,"can_download":false}"#.utf8))
    }

    private func commentsResult() throws -> BookCommentsPageDTO {
        try JSONDecoder.ekitapligim.decode(BookCommentsPageDTO.self, from: Data(#"{"comments":[],"pagination":{"page":1,"pages":2,"total":0}}"#.utf8))
    }
}

private actor DetailTestGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var released = false
    func wait() async {
        if released { return }
        await withCheckedContinuation { continuations.append($0) }
    }
    func release() {
        released = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
}

private actor DetailCallCounter {
    private(set) var count = 0
    func record() { count += 1 }
}
