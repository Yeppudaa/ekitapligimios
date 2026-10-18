import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class BookAgendaDetailModelTests: XCTestCase {
    func testSecondaryCommentsFailureKeepsPostAndExposesRetryError() async throws {
        let model = BookAgendaDetailModel()
        let post = try Self.post(commentCount: 2)
        await model.load(fetchPost: { post }, fetchComments: { throw AgendaDetailTestError.unavailable })

        XCTAssertEqual(model.post?.id, post.id)
        XCTAssertNil(model.errorMessage)
        XCTAssertNotNil(model.commentsError)
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.isLoadingComments)

        let comment = try Self.comment()
        await model.loadComments(fetch: { [comment] })
        XCTAssertEqual(model.comments.map(\.id), [comment.id])
        XCTAssertNil(model.commentsError)
    }

    func testConcurrentSendTapsProduceOneMutation() async throws {
        let model = BookAgendaDetailModel()
        model.updatePost(try Self.post())
        model.draft = "İlk yorum"
        let created = try Self.comment()
        let started = expectation(description: "First comment request suspended")
        let request = AgendaDetailSuspendedRequest(value: created, started: started)
        let duplicate = AgendaDetailMutationCounter()

        let first = Task { await model.submitComment(create: { _ in await request.run() }) }
        await fulfillment(of: [started], timeout: 3)
        let secondResult = await model.submitComment(create: { _ in
            await duplicate.record()
            return created
        })
        let duplicateCalls = await duplicate.calls
        XCTAssertFalse(secondResult)
        XCTAssertEqual(duplicateCalls, 0)
        XCTAssertTrue(model.isSubmitting)

        await request.release()
        let firstResult = await first.value
        XCTAssertTrue(firstResult)
        XCTAssertEqual(model.comments.map(\.id), [created.id])
        XCTAssertFalse(model.isSubmitting)
    }

    func testDelayedSendPreservesLatestPostAndItsServerCommentTotal() async throws {
        let model = BookAgendaDetailModel()
        model.updatePost(try Self.post(message: "Eski metin", reactionScore: 1, commentCount: 8))
        model.draft = "Yeni yorum"
        let created = try Self.comment()
        let started = expectation(description: "Comment request suspended before post update")
        let request = AgendaDetailSuspendedRequest(value: created, started: started)
        let send = Task { await model.submitComment(create: { _ in await request.run() }) }
        await fulfillment(of: [started], timeout: 3)

        model.updatePost(try Self.post(message: "Düzenlenmiş metin", reactionScore: 9, commentCount: 11))
        await request.release()
        _ = await send.value

        XCTAssertEqual(model.post?.message, "Düzenlenmiş metin")
        XCTAssertEqual(model.post?.reactionScore, 9)
        XCTAssertEqual(model.post?.commentCount, 12)
        XCTAssertEqual(model.comments.map(\.id), [created.id])
    }

    func testFailedActionRefreshRetainsLoadedPost() async throws {
        let model = BookAgendaDetailModel()
        let original = try Self.post(reactionScore: 4)
        model.updatePost(original)
        let mutations = AgendaDetailMutationCounter()

        await model.performAction(mutate: { await mutations.record() }, refresh: {
            throw AgendaDetailTestError.unavailable
        })

        let mutationCount = await mutations.calls
        XCTAssertEqual(mutationCount, 1)
        XCTAssertEqual(model.post, original)
        XCTAssertNotNil(model.actionMessage)
        XCTAssertFalse(model.isPerformingAction)
    }

    func testInvalidationDiscardsDelayedPostFromPreviousSession() async throws {
        let model = BookAgendaDetailModel()
        let oldPost = try Self.post(id: "19", message: "Eski oturum")
        let newPost = try Self.post(id: "20", message: "Yeni oturum")
        let started = expectation(description: "Old session post request suspended")
        let request = AgendaDetailSuspendedRequest(value: oldPost, started: started)
        let oldLoad = Task { await model.load(fetchPost: { await request.run() }, fetchComments: { [] }) }
        await fulfillment(of: [started], timeout: 3)

        model.invalidate()
        await model.load(fetchPost: { newPost }, fetchComments: { [] })
        await request.release()
        await oldLoad.value

        XCTAssertEqual(model.post?.id, newPost.id)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    func testInvalidationDiscardsDelayedCommentsFromPreviousSession() async throws {
        let model = BookAgendaDetailModel()
        let oldPost = try Self.post(commentCount: 1)
        let oldComment = try Self.comment()
        let started = expectation(description: "Old session comments request suspended")
        let request = AgendaDetailSuspendedRequest(value: [oldComment], started: started)
        let oldLoad = Task {
            await model.load(fetchPost: { oldPost }, fetchComments: { await request.run() })
        }
        await fulfillment(of: [started], timeout: 3)

        model.invalidate()
        await request.release()
        await oldLoad.value

        XCTAssertNil(model.post)
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertNil(model.commentsError)
        XCTAssertFalse(model.isLoadingComments)
    }

    func testInvalidationDiscardsDelayedSendWithoutChangingNextSessionDraft() async throws {
        let model = BookAgendaDetailModel()
        model.updatePost(try Self.post())
        model.draft = "Eski hesabın yorumu"
        let created = try Self.comment()
        let started = expectation(description: "Old session comment mutation suspended")
        let request = AgendaDetailSuspendedRequest(value: created, started: started)
        let send = Task { await model.submitComment(create: { _ in await request.run() }) }
        await fulfillment(of: [started], timeout: 3)

        model.invalidate()
        model.updatePost(try Self.post(id: "20", commentCount: 3))
        model.draft = "Yeni hesabın taslağı"
        await request.release()
        let result = await send.value

        XCTAssertFalse(result)
        XCTAssertEqual(model.post?.id, "20")
        XCTAssertEqual(model.post?.commentCount, 3)
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertEqual(model.draft, "Yeni hesabın taslağı")
        XCTAssertFalse(model.isSubmitting)
    }

    func testTypingDuringSendPreservesNewDraft() async throws {
        let model = BookAgendaDetailModel()
        model.updatePost(try Self.post())
        model.draft = "Gönderilen yorum"
        let created = try Self.comment()
        let started = expectation(description: "Comment request suspended while typing")
        let request = AgendaDetailSuspendedRequest(value: created, started: started)
        let send = Task { await model.submitComment(create: { _ in await request.run() }) }
        await fulfillment(of: [started], timeout: 3)

        model.draft = "Sıradaki yorumun taslağı"
        await request.release()
        let result = await send.value

        XCTAssertTrue(result)
        XCTAssertEqual(model.draft, "Sıradaki yorumun taslağı")
    }

    func testPermissionDeniedPreventsMutationAndRetainsDraft() async throws {
        let model = BookAgendaDetailModel()
        model.updatePost(try Self.post(canComment: false))
        model.draft = "Gönderilmeyecek yorum"
        let created = try Self.comment()
        let mutations = AgendaDetailMutationCounter()

        let result = await model.submitComment(create: { _ in
            await mutations.record()
            return created
        })

        let mutationCount = await mutations.calls
        XCTAssertFalse(result)
        XCTAssertEqual(mutationCount, 0)
        XCTAssertEqual(model.draft, "Gönderilmeyecek yorum")
        XCTAssertTrue(model.comments.isEmpty)
    }

    func testCommentCreationIncrementsServerTotalWithOnlySomeCommentsLoaded() async throws {
        let model = BookAgendaDetailModel()
        let originalComment = try Self.comment(id: "5")
        let loaded = try Self.post(commentCount: 12, comments: [originalComment])
        await model.load(fetchPost: { loaded }, fetchComments: { [originalComment] })
        model.draft = "Yeni yorum"
        let created = try Self.comment(id: "6")

        let result = await model.submitComment(create: { _ in created })

        XCTAssertTrue(result)
        XCTAssertEqual(model.comments.map(\.id), ["5", "6"])
        XCTAssertEqual(model.post?.commentCount, 13)
        XCTAssertEqual(model.post?.comments.map(\.id), ["5", "6"])
        XCTAssertEqual(model.draft, "")
    }

    func testCommentDeletionDecrementsServerTotalWithOnlySomeCommentsLoaded() async throws {
        let model = BookAgendaDetailModel()
        let deleted = try Self.comment(id: "5")
        let retained = try Self.comment(id: "6")
        let loaded = try Self.post(commentCount: 12, comments: [deleted, retained])
        await model.load(fetchPost: { loaded }, fetchComments: { [deleted, retained] })
        let mutations = AgendaDetailMutationCounter()

        await model.deleteComment(deleted, delete: { await mutations.record() })

        let mutationCount = await mutations.calls
        XCTAssertEqual(mutationCount, 1)
        XCTAssertEqual(model.comments.map(\.id), [retained.id])
        XCTAssertEqual(model.post?.commentCount, 11)
        XCTAssertEqual(model.post?.comments.map(\.id), [retained.id])
    }

    func testFailedCommentSubmissionRetainsDraftAndLoadedComments() async throws {
        let model = BookAgendaDetailModel()
        let existing = try Self.comment()
        let loaded = try Self.post(commentCount: 3, comments: [existing])
        await model.load(fetchPost: { loaded }, fetchComments: { [existing] })
        model.draft = "Yeniden denenecek yorum"

        let result = await model.submitComment(create: { _ in throw AgendaDetailTestError.unavailable })

        XCTAssertFalse(result)
        XCTAssertEqual(model.draft, "Yeniden denenecek yorum")
        XCTAssertEqual(model.comments.map(\.id), [existing.id])
        XCTAssertEqual(model.post?.commentCount, 3)
        XCTAssertNotNil(model.actionMessage)
        XCTAssertFalse(model.isSubmitting)
    }

    nonisolated private static func post(
        id: String = "19",
        message: String = "Kitap hakkında bir paylaşım",
        reactionScore: Int = 0,
        commentCount: Int = 0,
        canComment: Bool = true,
        comments: [BookAgendaCommentDTO] = []
    ) throws -> BookAgendaPostDTO {
        let data = try JSONSerialization.data(withJSONObject: [
            "id": id,
            "type": "review",
            "message": message,
            "reaction_score": reactionScore,
            "comment_count": commentCount,
            "actor": ["id": "31", "username": "Astraea"],
            "viewer": ["can_comment": canComment, "can_react": true]
        ])
        return try JSONDecoder.ekitapligim.decode(BookAgendaPostDTO.self, from: data)
            .updating(comments: comments)
    }

    nonisolated private static func comment(id: String = "6") throws -> BookAgendaCommentDTO {
        let data = try JSONSerialization.data(withJSONObject: [
            "id": id,
            "message": "Bu kitabı okudum.",
            "actor": ["id": "7", "username": "Okur"],
            "viewer": ["can_edit": true, "can_delete": true]
        ])
        return try JSONDecoder.ekitapligim.decode(BookAgendaCommentDTO.self, from: data)
    }
}

private enum AgendaDetailTestError: Error {
    case unavailable
}

private actor AgendaDetailMutationCounter {
    private(set) var calls = 0

    func record() { calls += 1 }
}

private actor AgendaDetailSuspendedRequest<Value: Sendable> {
    private let value: Value
    private let started: XCTestExpectation
    private var continuation: CheckedContinuation<Value, Never>?

    init(value: Value, started: XCTestExpectation) {
        self.value = value
        self.started = started
    }

    func run() async -> Value {
        started.fulfill()
        return await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
