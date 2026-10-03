import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class ChatModelTests: XCTestCase {
    func testVisibleHistoryReceivesWebReactionChangesAndRemovalsWithoutMovingCursor() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        await model.loadOlder()
        model.setMessageVisible("20", visible: true)
        await service.setExternalReaction(7)
        await model.pollNewMessages(refreshInteractions: true)
        XCTAssertEqual(model.messages.first(where: { $0.id == "20" })?.visitorReactionId, 7)
        let historyBefore = await service.lastBeforeID
        XCTAssertEqual(historyBefore, "21")
        await service.setExternalReaction(0)
        await model.pollNewMessages(refreshInteractions: true)
        XCTAssertEqual(model.messages.first(where: { $0.id == "20" })?.visitorReactionId, 0)
        await model.pollNewMessages()
        let cursor = await service.lastAfterID
        XCTAssertEqual(cursor, "81")
        model.disconnect()
    }

    func testConcurrentPollsDoNotOverwriteRemoteReactionWithOlderResponse() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        let started = expectation(description: "poll waiting")
        await service.holdPoll(started: started)
        let first = Task { await model.pollNewMessages(refreshInteractions: true) }
        await fulfillment(of: [started], timeout: 3)
        let before = await service.messageCalls
        await model.pollNewMessages(refreshInteractions: true)
        let after = await service.messageCalls
        XCTAssertEqual(after, before)
        await service.setExternalReaction(7)
        await service.releasePoll()
        await first.value
        XCTAssertEqual(model.messages.first(where: { $0.id == "81" })?.visitorReactionId, 7)
        model.disconnect()
    }
    func testHiddenViewDoesNotResumeWhenApplicationBecomesActive() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        model.disconnect()
        let before = await service.messageCalls
        await model.resume(visible: false)
        let after = await service.messageCalls
        XCTAssertEqual(after, before)
        model.disconnect()
    }

    func testMismatchedPollPageDoesNotAdvanceRoomCursor() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        await service.setWrongPage(true)
        await model.pollNewMessages()
        XCTAssertEqual(model.messages.map(\.id), ["81"])
        await service.setWrongPage(false)
        await model.pollNewMessages()
        let cursor = await service.lastAfterID
        XCTAssertEqual(cursor, "81")
        model.disconnect()
    }
    func testAccountReloadRevokesOldTranscriptAndWritesBeforeWaiting() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        model.draft = "Old account draft"
        model.quote(try ChatTestService.message())
        let started = expectation(description: "rooms reload waiting")
        await service.holdRooms(started: started)
        let reload = Task { await model.reloadRooms(signedIn: true) }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertTrue(model.rooms.isEmpty)
        XCTAssertEqual(model.draft, "")
        XCTAssertNil(model.quotedMessage)
        XCTAssertFalse(model.canSend)
        await service.releaseRooms()
        await reload.value
        model.disconnect()
    }

    func testSendRetainsPollCursorSoConcurrentMessagesAreNotSkipped() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        model.draft = "Yanıt"
        model.quote(try ChatTestService.message())
        await model.send()
        await model.pollNewMessages()
        let request = await service.lastSend
        let cursor = await service.lastAfterID
        XCTAssertEqual(request?.quoteID, "81")
        XCTAssertEqual(cursor, "81")
        XCTAssertEqual(model.messages.map(\.id), ["81", "82", "83"])
        XCTAssertEqual(model.draft, "")
        XCTAssertNil(model.quotedMessage)
        model.disconnect()
    }

    func testOlderPollCannotUndoCompletedReaction() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        let started = expectation(description: "old poll snapshot waiting")
        await service.holdPoll(started: started, tail: true)
        let poll = Task { await model.pollNewMessages(refreshInteractions: true) }
        await fulfillment(of: [started], timeout: 3)
        await model.setReaction(messageID: "81", reactionID: 7)
        XCTAssertEqual(model.messages.first?.visitorReactionId, 7)
        await service.releasePoll()
        await poll.value
        XCTAssertEqual(model.messages.first?.visitorReactionId, 7)
        model.disconnect()
    }

    func testBlockedUserDoesNotReappearInPollingAndUnblockingRestoresEligibility() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        model.quote(try ChatTestService.message())
        model.removeBlockedUser("9")
        await model.pollNewMessages(refreshInteractions: true)
        XCTAssertFalse(model.messages.contains { $0.userId == "9" })
        XCTAssertNil(model.quotedMessage)
        model.setBlockedUsers([])
        await model.pollNewMessages(refreshInteractions: true)
        XCTAssertTrue(model.messages.contains { $0.userId == "9" })
        model.disconnect()
    }

    func testGuestPermissionsPreventSendingAndReacting() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: false, initialRoomID: "4")
        model.draft = "Guest draft"
        model.quote(try ChatTestService.message())
        await model.send()
        await model.setReaction(messageID: "81", reactionID: 7)
        let send = await service.lastSend
        let mutations = await service.reactionCalls
        XCTAssertNil(send)
        XCTAssertEqual(mutations, 0)
        XCTAssertNil(model.quotedMessage)
        model.disconnect()
    }

    func testFailedAndMismatchedSendPreserveComposer() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        model.draft = "Keep this reply"
        model.quote(try ChatTestService.message())
        await service.setWrongRoom(true)
        await model.send()
        XCTAssertEqual(model.draft, "Keep this reply")
        XCTAssertEqual(model.quotedMessage?.id, "81")
        XCTAssertNotNil(model.sendError)
        XCTAssertEqual(model.messages.map(\.id), ["81"])
        await service.setWrongRoom(false)
        await service.setFailSend(true)
        await model.send()
        XCTAssertEqual(model.draft, "Keep this reply")
        XCTAssertEqual(model.quotedMessage?.id, "81")
        XCTAssertNotNil(model.sendError)
        model.disconnect()
    }

    func testDuplicateSendTapsProduceOneRequestAndPreserveNewTyping() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        model.draft = "First reply"
        let started = expectation(description: "send waiting")
        await service.holdSend(started: started)
        let first = Task { await model.send() }
        await fulfillment(of: [started], timeout: 3)
        model.draft = "Next reply being typed"
        await model.send()
        let requestCount = await service.sendCalls
        XCTAssertEqual(requestCount, 1)
        await service.releaseSend()
        await first.value
        XCTAssertEqual(model.draft, "Next reply being typed")
        model.disconnect()
    }

    func testTailRefreshCannotAdvancePastUnfetchedMessages() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        await service.setFutureTail(true)
        await model.pollNewMessages(refreshInteractions: true)
        XCTAssertEqual(model.messages.map(\.id), ["81"])
        await model.pollNewMessages()
        let cursor = await service.lastAfterID
        XCTAssertEqual(cursor, "81")
        model.disconnect()
    }

    func testRoomChangeDiscardsDelayedPageFromOldRoom() async throws {
        let service = ChatTestService()
        let model = ChatModel()
        await model.connect(service: service, signedIn: true, initialRoomID: "4")
        let started = expectation(description: "old room poll waiting")
        await service.holdPoll(started: started)
        let poll = Task { await model.pollNewMessages() }
        await fulfillment(of: [started], timeout: 3)
        await model.selectRoom("5")
        await service.releasePoll()
        await poll.value
        XCTAssertEqual(model.selectedRoomID, "5")
        XCTAssertTrue(model.messages.allSatisfy { $0.roomId == "5" })
        model.disconnect()
    }
}

private actor ChatTestService: ChatServing {
    struct Sent: Sendable { let text: String; let quoteID: String? }
    private(set) var lastSend: Sent?
    private(set) var lastAfterID: String?
    private(set) var lastBeforeID: String?
    private(set) var reactionCalls = 0
    private(set) var sendCalls = 0
    private(set) var messageCalls = 0
    private var roomsStarted: XCTestExpectation?
    private var pollStarted: XCTestExpectation?
    private var roomsGate: CheckedContinuation<Void, Never>?
    private var pollGate: CheckedContinuation<Void, Never>?
    private var sendStarted: XCTestExpectation?
    private var sendGate: CheckedContinuation<Void, Never>?
    private var wrongRoom = false
    private var reacted = false
    private var holdTail = false
    private var failSend = false
    private var futureTail = false
    private var wrongPage = false

    func holdRooms(started: XCTestExpectation) { roomsStarted = started }
    func holdPoll(started: XCTestExpectation, tail: Bool = false) { pollStarted = started; holdTail = tail }
    func releaseRooms() { roomsGate?.resume(); roomsGate = nil }
    func releasePoll() { pollGate?.resume(); pollGate = nil }
    func holdSend(started: XCTestExpectation) { sendStarted = started }
    func releaseSend() { sendGate?.resume(); sendGate = nil }
    func setWrongRoom(_ value: Bool) { wrongRoom = value }
    func setFailSend(_ value: Bool) { failSend = value }
    func setFutureTail(_ value: Bool) { futureTail = value }
    func setWrongPage(_ value: Bool) { wrongPage = value }
    func setExternalReaction(_ id: Int) { reacted = id > 0 }

    func rooms() async throws -> ChatRoomsDTO {
        if let started = roomsStarted {
            roomsStarted = nil
            started.fulfill()
            await withCheckedContinuation { roomsGate = $0 }
        }
        let payload = "{\"items\":[\(Self.room("4")),\(Self.room("5"))],\"capabilities\":{\"authenticated\":true,\"can_use\":true},\"reaction_options\":[\(Self.reaction)]}"
        return try JSONDecoder.ekitapligim.decode(ChatRoomsDTO.self, from: Data(payload.utf8))
    }

    func messages(roomID: String, limit: Int, beforeID: String?, afterID: String?) async throws -> ChatMessagesPageDTO {
        messageCalls += 1
        lastAfterID = afterID
        lastBeforeID = beforeID
        if let beforeID, let before = Int(beforeID), before <= 81 {
            let payload = "{\"room\":\(Self.room(roomID)),\"items\":[\(Self.messageJSON(id: "20", room: roomID, reaction: reacted ? 7 : 0))],\"pagination\":{\"oldest_id\":20,\"newest_id\":20}}"
            return try JSONDecoder.ekitapligim.decode(ChatMessagesPageDTO.self, from: Data(payload.utf8))
        }
        if wrongPage {
            let payload = "{\"room\":\(Self.room("99")),\"items\":[\(Self.messageJSON(id: "900", room: "99"))],\"pagination\":{\"newest_id\":900}}"
            return try JSONDecoder.ekitapligim.decode(ChatMessagesPageDTO.self, from: Data(payload.utf8))
        }
        let oldSnapshot = Self.messageJSON(id: "81", room: roomID, reaction: reacted ? 7 : 0)
        if (holdTail ? afterID == nil : afterID != nil), let started = pollStarted {
            pollStarted = nil
            started.fulfill()
            await withCheckedContinuation { pollGate = $0 }
        }
        let items: [String]
        if lastSend != nil, afterID != nil {
            items = [oldSnapshot, Self.messageJSON(id: "82", room: roomID), Self.messageJSON(id: "83", room: roomID)]
        } else { items = [oldSnapshot] }
        let actualItems = futureTail && afterID == nil ? [Self.messageJSON(id: "99", room: roomID)] : items
        let newest = futureTail && afterID == nil ? 99 : (lastSend == nil ? 81 : 83)
        let payload = "{\"room\":\(Self.room(roomID)),\"items\":[\(actualItems.joined(separator: ","))],\"pagination\":{\"oldest_id\":81,\"newest_id\":\(newest),\"has_more\":false},\"reaction_options\":[\(Self.reaction)]}"
        return try JSONDecoder.ekitapligim.decode(ChatMessagesPageDTO.self, from: Data(payload.utf8))
    }

    func send(roomID: String, message: String, quoteMessageID: String?) async throws -> ChatMessageDTO {
        sendCalls += 1
        if let started = sendStarted {
            sendStarted = nil
            started.fulfill()
            await withCheckedContinuation { sendGate = $0 }
        }
        if failSend { throw APIClientError.invalidResponse }
        lastSend = Sent(text: message, quoteID: quoteMessageID)
        return try Self.message(id: "83", room: wrongRoom ? "99" : roomID)
    }

    func setReaction(roomID: String, messageID: String, reactionID: Int) async throws -> ChatMessageDTO {
        reactionCalls += 1
        reacted = reactionID > 0
        return try Self.message(id: messageID, room: roomID, reaction: reactionID)
    }

    static func message(id: String = "81", room: String = "4", reaction: Int = 0) throws -> ChatMessageDTO {
        try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self, from: Data(messageJSON(id: id, room: room, reaction: reaction).utf8))
    }
    private static func room(_ id: String) -> String {
        "{\"id\":\"\(id)\",\"name\":\"Room\",\"can_send\":true}"
    }
    private static let reaction = #"{"reaction_id":7,"title":"Love","emoji":"❤️"}"#
    private static func messageJSON(id: String, room: String, reaction: Int = 0) -> String {
        "{\"id\":\"\(id)\",\"room_id\":\"\(room)\",\"user_id\":9,\"username\":\"Ada\",\"message\":\"Message\",\"can_quote\":true,\"can_react\":true,\"visitor_reaction_id\":\(reaction)}"
    }
}
