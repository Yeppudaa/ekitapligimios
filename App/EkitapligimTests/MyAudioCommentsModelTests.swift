import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class MyAudioCommentsModelTests: XCTestCase {
    func testSignedOutModelDoesNotRequestPersonalComments() async {
        let repository = AudioCommentsTestRepository(steps: [])
        let model = MyAudioCommentsModel(repository: repository)
        model.activate(sessionID: UUID(), signedIn: false)
        await model.load(reset: true)
        let calls = await repository.requestedPages
        XCTAssertTrue(calls.isEmpty)
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertFalse(model.isLoading)
    }

    func testDelayedPreviousSessionCannotOverwriteCurrentAccount() async throws {
        let started = expectation(description: "Previous account request suspended")
        let gate = AudioCommentsTestGate(value: try Self.page([1]), started: started)
        let repository = AudioCommentsTestRepository(steps: [.gated(gate), .page(try Self.page([2]))])
        let model = MyAudioCommentsModel(repository: repository)
        model.activate(sessionID: UUID(), signedIn: true)
        let previous = Task { await model.load(reset: true) }
        await fulfillment(of: [started], timeout: 3)

        model.activate(sessionID: UUID(), signedIn: true)
        XCTAssertTrue(model.comments.isEmpty)
        await model.load(reset: true)
        await gate.release()
        await previous.value

        XCTAssertEqual(model.comments.map(\.id), ["2"])
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    func testLogoutClearsExistingCommentsAndDiscardsPendingPage() async throws {
        let started = expectation(description: "Personal pagination suspended")
        let gate = AudioCommentsTestGate(value: try Self.page([2], page: 2, pages: 2), started: started)
        let repository = AudioCommentsTestRepository(steps: [
            .page(try Self.page([1], pages: 2)), .gated(gate)
        ])
        let model = MyAudioCommentsModel(repository: repository)
        model.activate(sessionID: UUID(), signedIn: true)
        await model.load(reset: true)
        let pagination = Task { await model.load(reset: false) }
        await fulfillment(of: [started], timeout: 3)

        model.activate(sessionID: UUID(), signedIn: false)
        await gate.release()
        await pagination.value
        await model.load(reset: true)

        let calls = await repository.requestedPages
        XCTAssertEqual(calls, [1, 2])
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertFalse(model.hasMore)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    func testPaginationFailureRetriesSamePageAndPreservesLoadedComments() async throws {
        let repository = AudioCommentsTestRepository(steps: [
            .page(try Self.page([1], pages: 3)), .failure,
            .page(try Self.page([2], page: 2, pages: 3))
        ])
        let model = MyAudioCommentsModel(repository: repository)
        model.activate(sessionID: UUID(), signedIn: true)
        await model.load(reset: true)
        await model.load(reset: false)

        XCTAssertEqual(model.comments.map(\.id), ["1"])
        XCTAssertTrue(model.hasMore)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)

        await model.retry()
        let calls = await repository.requestedPages
        XCTAssertEqual(calls, [1, 2, 2])
        XCTAssertEqual(model.comments.map(\.id), ["1", "2"])
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.hasMore)
    }

    func testFailedRefreshRetryRequestsFirstPageEvenWhenMoreOldPagesExist() async throws {
        let repository = AudioCommentsTestRepository(steps: [
            .page(try Self.page([1], pages: 3)), .failure, .page(try Self.page([9]))
        ])
        let model = MyAudioCommentsModel(repository: repository)
        model.activate(sessionID: UUID(), signedIn: true)
        await model.load(reset: true)
        await model.load(reset: true)
        XCTAssertEqual(model.comments.map(\.id), ["1"])
        XCTAssertTrue(model.hasMore)
        XCTAssertNotNil(model.errorMessage)

        await model.retry()
        let calls = await repository.requestedPages
        XCTAssertEqual(calls, [1, 1, 1])
        XCTAssertEqual(model.comments.map(\.id), ["9"])
        XCTAssertFalse(model.hasMore)
        XCTAssertNil(model.errorMessage)
    }

    func testRefreshDiscardsInFlightOlderPagination() async throws {
        let started = expectation(description: "Old pagination suspended")
        let gate = AudioCommentsTestGate(value: try Self.page([2], page: 2, pages: 2), started: started)
        let repository = AudioCommentsTestRepository(steps: [
            .page(try Self.page([1], pages: 2)), .gated(gate), .page(try Self.page([3]))
        ])
        let model = MyAudioCommentsModel(repository: repository)
        model.activate(sessionID: UUID(), signedIn: true)
        await model.load(reset: true)
        let pagination = Task { await model.load(reset: false) }
        await fulfillment(of: [started], timeout: 3)
        await model.load(reset: true)
        await gate.release()
        await pagination.value

        let calls = await repository.requestedPages
        XCTAssertEqual(calls, [1, 2, 1])
        XCTAssertEqual(model.comments.map(\.id), ["3"])
        XCTAssertFalse(model.hasMore)
        XCTAssertFalse(model.isLoading)
    }

    func testDuplicateIDsWithinAndAcrossPagesAppearOnce() async throws {
        let repository = AudioCommentsTestRepository(steps: [
            .page(try Self.page([1, 1, 2], pages: 2)),
            .page(try Self.page([2, 3, 3], page: 2, pages: 2))
        ])
        let model = MyAudioCommentsModel(repository: repository)
        model.activate(sessionID: UUID(), signedIn: true)
        await model.load(reset: true)
        XCTAssertEqual(model.comments.map(\.id), ["1", "2"])
        await model.load(reset: false)
        XCTAssertEqual(model.comments.map(\.id), ["1", "2", "3"])
        XCTAssertFalse(model.hasMore)
    }

    func testUnexpectedResponsePageShowsErrorAndRetryDoesNotSkipRequestedPage() async throws {
        let repository = AudioCommentsTestRepository(steps: [
            .page(try Self.page([1], pages: 2)), .page(try Self.page([99], pages: 2)),
            .page(try Self.page([2], page: 2, pages: 2))
        ])
        let model = MyAudioCommentsModel(repository: repository)
        model.activate(sessionID: UUID(), signedIn: true)
        await model.load(reset: true)
        await model.load(reset: false)
        XCTAssertEqual(model.comments.map(\.id), ["1"])
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.hasMore)

        await model.load(reset: false)
        let calls = await repository.requestedPages
        XCTAssertEqual(calls, [1, 2, 2])
        XCTAssertEqual(model.comments.map(\.id), ["1", "2"])
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.hasMore)
    }

    nonisolated private static func page(_ ids: [Int], page: Int = 1, pages: Int = 1) throws -> MyAudioCommentsPageDTO {
        let comments = ids.map { ["id": $0, "thread_id": $0 + 1_000] }
        let data = try JSONSerialization.data(withJSONObject: [
            "scope": "audio", "comments": comments, "pagination": ["page": page, "pages": pages]
        ])
        return try JSONDecoder.ekitapligim.decode(MyAudioCommentsPageDTO.self, from: data)
    }
}

private enum AudioCommentsTestError: Error { case unavailable }

private actor AudioCommentsTestRepository: MyAudioCommentsServing {
    enum Step: Sendable {
        case page(MyAudioCommentsPageDTO)
        case failure
        case gated(AudioCommentsTestGate)
    }
    private var steps: [Step]
    private(set) var requestedPages: [Int] = []

    init(steps: [Step]) { self.steps = steps }

    func audioComments(page: Int) async throws -> MyAudioCommentsPageDTO {
        requestedPages.append(page)
        guard !steps.isEmpty else { throw AudioCommentsTestError.unavailable }
        switch steps.removeFirst() {
        case .page(let result): return result
        case .failure: throw AudioCommentsTestError.unavailable
        case .gated(let gate): return await gate.run()
        }
    }
}

private actor AudioCommentsTestGate {
    let value: MyAudioCommentsPageDTO
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<MyAudioCommentsPageDTO, Never>?

    init(value: MyAudioCommentsPageDTO, started: XCTestExpectation) {
        self.value = value
        self.started = started
    }

    func run() async -> MyAudioCommentsPageDTO {
        started.fulfill()
        return await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
