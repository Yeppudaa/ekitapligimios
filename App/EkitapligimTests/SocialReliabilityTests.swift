import Foundation
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class SocialReliabilityTests: XCTestCase {
    func testRequestRefreshRejectsOlderResponseAndDeduplicatesIDs() async throws {
        let old = try Self.requests(title: "Old")
        let fresh = try Self.requests(title: "New", duplicate: true)
        let started = expectation(description: "Old request started")
        let pending = SocialPending(value: old, started: started)
        let model = BookRequestsModel(); let account = UUID()
        model.configure(Self.dependencies(fetch: { await pending.run() }), session: account, signedIn: true)
        let first = Task { await model.load() }
        await fulfillment(of: [started], timeout: 3)
        model.configure(Self.dependencies(fetch: { fresh }), session: account, signedIn: true)
        await model.load()
        await pending.release(); await first.value
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items.first?.title, "New")
        XCTAssertFalse(model.isLoading)
    }

    func testRequestSubmissionIsSingleFlightAndPreservesNewDraft() async throws {
        let created = try Self.requests().items[0]
        let started = expectation(description: "Create started")
        let pending = SocialPending(value: created, started: started)
        let count = SocialCounter()
        let model = BookRequestsModel()
        model.configure(Self.dependencies(create: { _, _, _ in await count.record(); return await pending.run() }), session: UUID(), signedIn: true)
        model.draftTitle = "Book"; model.draftAuthor = "Author"
        let first = Task { await model.submit() }
        await fulfillment(of: [started], timeout: 3)
        model.draftTitle = "Next book"
        let duplicate = await model.submit()
        XCTAssertFalse(duplicate)
        let calls = await count.value; XCTAssertEqual(calls, 1)
        await pending.release(); let success = await first.value
        XCTAssertTrue(success); XCTAssertEqual(model.draftTitle, "Next book")
        XCTAssertFalse(model.isSubmitting)
    }

    func testOldAccountRequestCannotClearNewAccountDraft() async throws {
        let started = expectation(description: "Old account create")
        let pending = SocialPending(value: try Self.requests().items[0], started: started)
        let model = BookRequestsModel()
        model.configure(Self.dependencies(create: { _, _, _ in await pending.run() }), session: UUID(), signedIn: true)
        model.draftTitle = "Old"; model.draftAuthor = "Author"
        let task = Task { await model.submit() }
        await fulfillment(of: [started], timeout: 3)
        model.configure(Self.dependencies(), session: UUID(), signedIn: true)
        model.draftTitle = "New account"
        await pending.release(); let success = await task.value
        XCTAssertFalse(success); XCTAssertEqual(model.draftTitle, "New account")
        XCTAssertNil(model.statusMessage); XCTAssertTrue(model.items.isEmpty)
    }

    func testMonthlyRejectionRefreshesActualQuotaAndKeepsDraft() async throws {
        let exhausted = try Self.requests(quota: true)
        let error = try JSONDecoder.ekitapligim.decode(APIErrorEnvelope.self, from: Data(#"{"errors":[{"code":"book_request_monthly_limit","message":"Limit","params":{"remaining":0}}]}"#.utf8))
        let model = BookRequestsModel()
        model.configure(Self.dependencies(fetch: { exhausted }, create: { _, _, _ in throw APIClientError.httpStatus(429, error) }), session: UUID(), signedIn: true)
        model.draftTitle = "Book"; model.draftAuthor = "Author"
        let success = await model.submit()
        XCTAssertFalse(success); XCTAssertEqual(model.draftTitle, "Book")
        XCTAssertEqual(model.accessExplanation?.quota?.remaining, 0)
        XCTAssertEqual(model.accessExplanation?.quota?.resetsAt, 1796072400)
        XCTAssertNil(model.statusMessage)
    }

    func testRejectedVoteNeverShowsSuccess() async throws {
        let response = try JSONDecoder.ekitapligim.decode(BookRequestVoteDTO.self, from: Data(#"{"success":false,"voted":false,"vote_count":0}"#.utf8))
        let item = try Self.requests().items[0]
        let model = BookRequestsModel()
        model.configure(Self.dependencies(vote: { _ in response }), session: UUID(), signedIn: true)
        await model.vote(item)
        XCTAssertNil(model.statusMessage); XCTAssertNotNil(model.operationError); XCTAssertNil(model.votingID)
    }

    func testMonthlyQuotaDoesNotOpenCreateOrSpendAnotherSlot() async throws {
        let page = try Self.requests(quota: true); let count = SocialCounter()
        let item = page.items[0]
        let model = BookRequestsModel()
        model.configure(Self.dependencies(fetch: { page }, create: { _, _, _ in await count.record(); return item }), session: UUID(), signedIn: true)
        await model.load(); model.draftTitle = "Book"; model.draftAuthor = "Author"
        XCTAssertNotNil(model.prepareCreation())
        let success = await model.submit(); let calls = await count.value
        XCTAssertFalse(success); XCTAssertEqual(calls, 0)
    }

    func testInboxResetDuringPaginationCannotBeOverwritten() async throws {
        let old = try Self.inbox(title: "Old"); let fresh = try Self.inbox(title: "Fresh")
        let started = expectation(description: "Old inbox")
        let pending = SocialPending(value: old, started: started)
        let model = ConversationInboxModel()
        let task = Task { await model.load(reset: true) { _ in await pending.run() } }
        await fulfillment(of: [started], timeout: 3)
        await model.load(reset: true) { _ in fresh }
        await pending.release(); await task.value
        XCTAssertEqual(model.conversations.first?.title, "Fresh")
        XCTAssertFalse(model.isLoading)
    }

    func testReplyAcknowledgementPreservesEditsAndBlocksDuplicateSend() async throws {
        let model = ConversationDetailModel(); let detail = try Self.detail()
        await model.load(id: "7") { _ in detail }
        model.draft = "First draft"
        let started = expectation(description: "Reply started")
        let pending = SocialPending(value: try Self.reply(), started: started)
        let count = SocialCounter()
        let task = Task { await model.send(id: "7") { _ in await count.record(); return await pending.run() } }
        await fulfillment(of: [started], timeout: 3)
        model.draft = "Next draft"
        await model.send(id: "7") { _ in await count.record(); return try Self.reply() }
        await pending.release(); await task.value
        let calls = await count.value
        XCTAssertEqual(calls, 1); XCTAssertEqual(model.draft, "Next draft")
        XCTAssertEqual(model.detail?.messages.map(\.id), ["1", "2"])
    }

    func testReplySuccessFalsePreservesDraftAndDoesNotAppend() async throws {
        let model = ConversationDetailModel(); let detail = try Self.detail()
        await model.load(id: "7") { _ in detail }; model.draft = "Keep this"
        await model.send(id: "7") { _ in try Self.reply(success: false) }
        XCTAssertEqual(model.draft, "Keep this"); XCTAssertEqual(model.detail?.messages.count, 1)
        XCTAssertNotNil(model.errorMessage)
    }

    func testOlderPagesAreMergedInChronologicalOrderWithoutDuplicates() async throws {
        let model = ConversationDetailModel()
        let latest = try Self.detail(page: 2, ids: [3, 4])
        await model.load(id: "7") { page in XCTAssertNil(page); return latest }
        XCTAssertTrue(model.hasEarlier)
        let earlier = try Self.detail(page: 1, ids: [1, 2, 3])
        await model.load(id: "7", earlier: true) { page in XCTAssertEqual(page, 1); return earlier }
        XCTAssertEqual(model.detail?.messages.map(\.id), ["1", "2", "3", "4"])
        XCTAssertFalse(model.hasEarlier)
    }

    func testOlderServerIgnoringPageDoesNotPretendAllMessagesAreLoaded() async throws {
        let model = ConversationDetailModel(); let latest = try Self.detail(page: 2)
        await model.load(id: "7") { _ in latest }
        await model.load(id: "7", earlier: true) { _ in latest }
        XCTAssertTrue(model.hasEarlier); XCTAssertNotNil(model.errorMessage)
    }

    func testDelayedRefreshCannotRemoveAcknowledgedReply() async throws {
        let model = ConversationDetailModel(); let original = try Self.detail()
        await model.load(id: "7") { _ in original }
        let started = expectation(description: "Refresh started")
        let pending = SocialPending(value: original, started: started)
        let refresh = Task { await model.load(id: "7") { _ in await pending.run() } }
        await fulfillment(of: [started], timeout: 3)
        model.draft = "New reply"; await model.send(id: "7") { _ in try Self.reply() }
        await pending.release(); _ = await refresh.value
        XCTAssertEqual(model.detail?.messages.map(\.id), ["1", "2"])
        XCTAssertEqual(model.draft, "")
    }

    func testAccountChangeDiscardsPendingMessageReply() async throws {
        let model = ConversationDetailModel(); let original = try Self.detail()
        await model.load(id: "7") { _ in original }; model.draft = "Old account"
        let started = expectation(description: "Old reply")
        let pending = SocialPending(value: try Self.reply(), started: started)
        let send = Task { await model.send(id: "7") { _ in await pending.run() } }
        await fulfillment(of: [started], timeout: 3)
        model.invalidate(); model.draft = "New account draft"
        await pending.release(); await send.value
        XCTAssertNil(model.detail); XCTAssertEqual(model.draft, "New account draft")
        XCTAssertFalse(model.isSending)
    }

    nonisolated private static func dependencies(
        fetch: @escaping @Sendable () async throws -> BookRequestsPageDTO = { try requests() },
        create: @escaping @Sendable (String, String, String) async throws -> BookRequestDTO = { _, _, _ in try requests().items[0] },
        vote: @escaping @Sendable (String) async throws -> BookRequestVoteDTO = { _ in throw URLError(.badServerResponse) }
    ) -> BookRequestsDependencies { BookRequestsDependencies(fetch: { _ in try await fetch() }, create: create, vote: vote) }

    nonisolated private static func requests(title: String = "Book", duplicate: Bool = false, quota: Bool = false) throws -> BookRequestsPageDTO {
        let item: [String: Any] = ["id": "1", "title": title, "author": "Author", "status": "PENDING"]
        var payload: [String: Any] = ["items": duplicate ? [item, item] : [item]]
        if quota { payload["request_quota"] = ["is_premium": true, "limit": 5, "used": 5, "remaining": 0, "can_request": false, "resets_at": 1796072400, "timezone": "Europe/Istanbul"] }
        return try JSONDecoder.ekitapligim.decode(BookRequestsPageDTO.self, from: JSONSerialization.data(withJSONObject: payload))
    }

    nonisolated private static func inbox(title: String) throws -> ConversationsPageDTO {
        try JSONDecoder.ekitapligim.decode(ConversationsPageDTO.self, from: JSONSerialization.data(withJSONObject: ["items": [["id": "7", "title": title]], "pagination": ["page": 1, "pages": 1]]))
    }

    nonisolated private static func message(_ id: Int) -> [String: Any] {
        ["id": String(id), "conversation_id": 7, "user_id": 8, "message_date": id, "message": "Message \(id)"]
    }
    nonisolated private static func detail(page: Int = 1, ids: [Int] = [1]) throws -> ConversationDetailDTO {
        try JSONDecoder.ekitapligim.decode(ConversationDetailDTO.self, from: JSONSerialization.data(withJSONObject: [
            "conversation": ["id": "7", "can_reply": true], "messages": ids.map(message), "pagination": ["page": page, "pages": 2]
        ]))
    }
    nonisolated private static func reply(success: Bool = true) throws -> ConversationReplyDTO {
        try JSONDecoder.ekitapligim.decode(ConversationReplyDTO.self, from: JSONSerialization.data(withJSONObject: [
            "success": success, "conversation": ["id": "7", "can_reply": true], "message": message(2)
        ]))
    }
}

private actor SocialCounter { private(set) var value = 0; func record() { value += 1 } }
private actor SocialPending<Value: Sendable> {
    let value: Value
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<Value, Never>?
    init(value: Value, started: XCTestExpectation) { self.value = value; self.started = started }
    func run() async -> Value {
        await withCheckedContinuation { continuation = $0; started.fulfill() }
    }
    func release() { continuation?.resume(returning: value); continuation = nil }
}
