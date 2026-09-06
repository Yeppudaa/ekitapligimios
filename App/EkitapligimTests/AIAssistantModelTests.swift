import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class AIAssistantModelTests: XCTestCase {
    func testDoubleTapDoesNotSendTwice() async throws {
        let service = AIFixtureService()
        await service.configure(delay: true)
        let model = AIAssistantModel(repository: service)
        model.activate(account: nil); await model.waitUntilIdle()
        model.input = "Bir kitap öner"
        model.send(); model.send()
        await model.waitUntilIdle()
        let count = await service.sendCount()
        XCTAssertEqual(count, 1); XCTAssertEqual(model.messages.count, 2)
    }
    func testQuotaAndUnavailableServiceBlockSuggestionsAndComposer() async throws {
        for mode in ["quota", "error"] {
            let service = AIFixtureService(mode: mode)
            let model = AIAssistantModel(repository: service)
            model.activate(account: nil); await model.waitUntilIdle()
            model.send("Bir kitap öner"); await model.waitUntilIdle()
            let count = await service.sendCount()
            XCTAssertEqual(count, 0); XCTAssertFalse(model.canSend)
        }
    }
    func testLateResponseCannotCrossAccounts() async throws {
        let service = AIFixtureService()
        await service.configure(delay: true)
        let model = AIAssistantModel(repository: service)
        model.activate(account: "first"); await model.waitUntilIdle()
        model.send("Bir kitap öner")
        for _ in 0..<100 {
            if await service.sendCount() > 0 { break }
            await Task.yield()
        }
        model.activate(account: "second"); await model.waitUntilIdle()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(model.messages.isEmpty); XCTAssertTrue(model.input.isEmpty)
        XCTAssertNil(model.error)
    }
    func testDeletingHistoryNeverRestoresQuotaAndFailureKeepsConversation() async throws {
        let service = AIFixtureService()
        let model = AIAssistantModel(repository: service)
        model.activate(account: nil); await model.waitUntilIdle()
        model.send("Bir kitap öner"); await model.waitUntilIdle()
        await service.configure(failDelete: true)
        model.deleteConversation(nil); await model.waitUntilIdle()
        XCTAssertFalse(model.messages.isEmpty); XCTAssertNotNil(model.error)
        await service.configure(failDelete: false)
        model.deleteConversation(nil); await model.waitUntilIdle()
        XCTAssertTrue(model.messages.isEmpty); XCTAssertEqual(model.bootstrap?.usage.remaining, 1)
    }
    func testTimeoutDoesNotAutomaticallyReplayMessage() async throws {
        let service = AIFixtureService(mode: "uncertain")
        let model = AIAssistantModel(repository: service)
        model.activate(account: nil); await model.waitUntilIdle()
        model.send("Bir kitap öner"); await model.waitUntilIdle()
        let count = await service.sendCount()
        XCTAssertEqual(count, 1); XCTAssertNotNil(model.error)
    }
    func testBookContextChangeStartsEmptyConversation() async throws {
        let service = AIFixtureService()
        let model = AIAssistantModel(repository: service)
        model.activate(account: nil); await model.waitUntilIdle()
        model.send("Bir kitap öner"); await model.waitUntilIdle()
        model.open(bookID: 20); await model.waitUntilIdle()
        XCTAssertNil(model.conversation); XCTAssertEqual(model.contextBookID, 20)
    }
}
