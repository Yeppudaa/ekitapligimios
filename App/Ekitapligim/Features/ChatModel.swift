import Foundation
import Combine
import EkitapligimCore

/// Owns room-scoped requests and composer state. The injected service also permits offline tests.
@MainActor
final class ChatModel: ObservableObject {
    @Published private(set) var rooms: [ChatRoomDTO] = []
    @Published private(set) var capabilities = ChatCapabilitiesDTO()
    @Published private(set) var selectedRoomID: String?
    @Published private(set) var messages: [ChatMessageDTO] = []
    @Published private(set) var reactionOptions: [ChatReactionDTO] = []
    @Published private(set) var hasOlder = false
    @Published var draft = "" {
        didSet {
            if draft.count > Self.draftCharacterLimit { draft = String(draft.prefix(Self.draftCharacterLimit)) }
        }
    }
    @Published private(set) var quotedMessage: ChatMessageDTO?
    @Published private(set) var isLoadingRooms = false
    @Published private(set) var isLoadingMessages = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var isSending = false
    @Published private(set) var reactingMessageIDs: Set<String> = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var sendError: String?
    @Published private(set) var scrollRequest = 0
    @Published private(set) var isSignedIn = false

    static let draftCharacterLimit = 1_000
    private var service: (any ChatServing)?
    private var oldestID: String?
    private var newestID: String?
    private var generation = 0
    private var pollTask: Task<Void, Never>?
    private var interactionRevisions: [String: Int] = [:]
    private var blockedUserIDs: Set<String> = []
    private var isActive = false
    private var visibleMessageIDs: Set<String> = []
    private var pollingGeneration: Int?

    init(service: (any ChatServing)? = nil) { self.service = service }

    var selectedRoom: ChatRoomDTO? { rooms.first { $0.id == selectedRoomID } }
    var sessionReady: Bool { isSignedIn && capabilities.authenticated }
    var canSend: Bool {
        sessionReady && capabilities.canUse && selectedRoom?.canSend == true
            && selectedRoom?.isReadOnly != true && selectedRoom?.isLocked != true
            && !isLoadingRooms && !isLoadingMessages
    }

    func connect(service: any ChatServing, signedIn: Bool, initialRoomID: String?) async {
        isActive = true
        self.service = service
        await reloadRooms(signedIn: signedIn, initialRoomID: initialRoomID)
    }

    func reloadRooms(signedIn: Bool, initialRoomID: String? = nil) async {
        guard let service else { return }
        invalidateRequests()
        isSignedIn = signedIn
        // Account changes must revoke the previous transcript and write permissions
        // before awaiting the next account's room response.
        draft = ""
        quotedMessage = nil
        capabilities = ChatCapabilitiesDTO()
        messages = []
        rooms = []
        reactionOptions = []
        oldestID = nil
        newestID = nil
        hasOlder = false
        let requestGeneration = generation
        isLoadingRooms = true
        errorMessage = nil
        defer { if generation == requestGeneration { isLoadingRooms = false } }
        do {
            let response = try await service.rooms()
            guard generation == requestGeneration, !Task.isCancelled else { return }
            rooms = response.rooms
            capabilities = response.capabilities
            reactionOptions = response.reactionOptions
            selectedRoomID = rooms.first { $0.id == selectedRoomID }?.id
                ?? initialRoomID.flatMap { id in rooms.first { $0.id == id }?.id }
                ?? rooms.first?.id
            quotedMessage = nil
            if selectedRoomID != nil { await loadMessages() }
            else { messages = []; hasOlder = false }
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            errorMessage = L10n.chatRoomsFailed
        }
    }

    func selectRoom(_ id: String) async {
        guard id != selectedRoomID, rooms.contains(where: { $0.id == id }) else { return }
        selectedRoomID = id
        quotedMessage = nil
        draft = ""
        await loadMessages()
    }

    func loadMessages() async {
        guard let service, let roomID = selectedRoomID else { return }
        invalidateRequests()
        let requestGeneration = generation
        messages = []
        oldestID = nil
        newestID = nil
        hasOlder = false
        isLoadingMessages = true
        errorMessage = nil
        defer { if generation == requestGeneration { isLoadingMessages = false } }
        do {
            let page = try await service.messages(roomID: roomID, limit: 40, beforeID: nil, afterID: nil)
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
            guard pageBelongsToRoom(page, roomID: roomID) else { throw APIClientError.invalidResponse }
            messages = unique(page.messages)
            oldestID = page.oldestId
            newestID = page.newestId ?? messages.last?.id
            hasOlder = page.hasMore
            updateRoom(page)
            scrollRequest += 1
            startPolling()
        } catch {
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
            errorMessage = L10n.chatMessagesFailed
        }
    }

    func loadOlder() async {
        guard let service, let roomID = selectedRoomID, let beforeID = oldestID,
              !isLoadingOlder, !isLoadingMessages else { return }
        let requestGeneration = generation
        isLoadingOlder = true
        defer { if generation == requestGeneration { isLoadingOlder = false } }
        do {
            let page = try await service.messages(roomID: roomID, limit: 40, beforeID: beforeID, afterID: nil)
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
            guard pageBelongsToRoom(page, roomID: roomID) else { throw APIClientError.invalidResponse }
            let existing = Set(messages.map(\.id))
            messages.insert(contentsOf: unique(page.messages).filter { !existing.contains($0.id) }, at: 0)
            oldestID = page.oldestId ?? oldestID
            hasOlder = page.hasMore
        } catch {
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
            sendError = L10n.chatMessagesFailed
        }
    }

    func quote(_ message: ChatMessageDTO) {
        guard canSend, message.canQuote, message.roomId == selectedRoomID,
              !isSending, messages.contains(where: { $0.id == message.id }) else { return }
        quotedMessage = message
        sendError = nil
    }

    func cancelQuote() { quotedMessage = nil }

    func setMessageVisible(_ id: String, visible: Bool) {
        if visible { visibleMessageIDs.insert(id) }
        else { visibleMessageIDs.remove(id) }
    }

    func removeBlockedUser(_ id: String) {
        blockedUserIDs.insert(id)
        messages.removeAll { $0.userId == id }
        if quotedMessage?.userId == id { quotedMessage = nil }
    }

    func setBlockedUsers(_ ids: Set<String>) {
        blockedUserIDs = ids
        messages.removeAll { ids.contains($0.userId) }
        if let quotedMessage, ids.contains(quotedMessage.userId) { self.quotedMessage = nil }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let service, canSend, !isSending, !text.isEmpty,
              let roomID = selectedRoomID else { return }
        let requestGeneration = generation
        let originalDraft = draft
        let quoteID = quotedMessage?.id
        isSending = true
        sendError = nil
        defer { if generation == requestGeneration { isSending = false } }
        do {
            let sent = try await service.send(roomID: roomID, message: text, quoteMessageID: quoteID)
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
            guard sent.roomId == roomID else { sendError = L10n.chatSendFailed; return }
            if draft == originalDraft { draft = "" }
            if quotedMessage?.id == quoteID { quotedMessage = nil }
            merge([sent])
            // Leave the server poll cursor at the last fetched page. Concurrent
            // messages before this reply must still be fetched on the next poll.
            scrollRequest += 1
        } catch {
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
            sendError = (error as? APIClientError)?.serverMessage ?? L10n.chatSendFailed
        }
    }

    func setReaction(messageID: String, reactionID: Int) async {
        guard let service, canSend, let roomID = selectedRoomID,
              let message = messages.first(where: { $0.id == messageID }), message.canReact,
              !reactingMessageIDs.contains(messageID),
              reactionID == 0 || reactionOptions.contains(where: { $0.reactionId == reactionID }) else { return }
        let requestGeneration = generation
        interactionRevisions[messageID, default: 0] += 1
        reactingMessageIDs.insert(messageID)
        sendError = nil
        defer { if generation == requestGeneration { reactingMessageIDs.remove(messageID) } }
        do {
            let updated = try await service.setReaction(roomID: roomID, messageID: messageID, reactionID: reactionID)
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled,
                  let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
            guard updated.id == messageID, updated.roomId == roomID else {
                sendError = L10n.chatReactionFailed
                return
            }
            interactionRevisions[messageID, default: 0] += 1
            messages[index] = updated
        } catch {
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
            sendError = (error as? APIClientError)?.serverMessage ?? L10n.chatReactionFailed
        }
    }

    /// Refresh the visible window as edits/reactions don't change the after_id cursor.
    func pollNewMessages(refreshInteractions: Bool = false) async {
        guard let service, let roomID = selectedRoomID, !isLoadingMessages,
              pollingGeneration != generation else { return }
        let requestGeneration = generation
        pollingGeneration = requestGeneration
        defer { if pollingGeneration == requestGeneration { pollingGeneration = nil } }
        let interactionSnapshot = interactionRevisions
        do {
            let page = try await service.messages(roomID: roomID, limit: 40, beforeID: nil, afterID: newestID)
            guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
            guard pageBelongsToRoom(page, roomID: roomID) else { throw APIClientError.invalidResponse }
            merge(page.messages, interactionSnapshot: interactionSnapshot)
            if let id = page.newestId { advanceNewestID(id) }
            updateRoom(page)
            if refreshInteractions {
                let tailSnapshot = interactionRevisions
                // Refresh the visible history window too: web/Android reactions on
                // an older message do not change IDs and are absent from the tail.
                let visibleNewest = messages.filter { visibleMessageIDs.contains($0.id) }
                    .compactMap { Int($0.id) }.max()
                let beforeVisible = visibleNewest.flatMap { $0 < Int.max ? String($0 + 1) : nil }
                let tail = try await service.messages(roomID: roomID, limit: 40, beforeID: beforeVisible, afterID: nil)
                guard isCurrent(requestGeneration, roomID: roomID), !Task.isCancelled else { return }
                guard pageBelongsToRoom(tail, roomID: roomID) else { throw APIClientError.invalidResponse }
                // The tail is for edits and reactions, not the pagination cursor.
                // Advancing to its newest ID during a busy room would skip the
                // intermediate messages not yet fetched by the after_id pages.
                let knownIDs = Set(messages.map(\.id))
                merge(tail.messages.filter { knownIDs.contains($0.id) }, interactionSnapshot: tailSnapshot)
                updateRoom(tail)
            }
        } catch {
            // A transient polling failure preserves the transcript; the next poll retries.
        }
    }

    func disconnect() {
        isActive = false
        pollTask?.cancel()
        pollTask = nil
    }

    func resume(visible: Bool = true) async {
        guard visible else { return }
        isActive = true
        guard selectedRoomID != nil, !isLoadingMessages, !isLoadingRooms else { return }
        if newestID == nil {
            await loadMessages()
            return
        }
        await pollNewMessages(refreshInteractions: true)
        if !Task.isCancelled { startPolling() }
    }

    private func invalidateRequests() {
        generation += 1
        pollTask?.cancel()
        pollTask = nil
        isLoadingRooms = false
        isLoadingMessages = false
        isLoadingOlder = false
        isSending = false
        reactingMessageIDs = []
        interactionRevisions = [:]
        visibleMessageIDs = []
        pollingGeneration = nil
        sendError = nil
    }

    private func isCurrent(_ requestGeneration: Int, roomID: String) -> Bool {
        requestGeneration == generation && selectedRoomID == roomID
    }

    private func pageBelongsToRoom(_ page: ChatMessagesPageDTO, roomID: String) -> Bool {
        (page.room == nil || page.room?.id == roomID)
            && page.messages.allSatisfy { $0.roomId == roomID }
    }

    private func unique(_ incoming: [ChatMessageDTO]) -> [ChatMessageDTO] {
        var seen = Set<String>()
        return incoming.filter {
            $0.roomId == selectedRoomID && !blockedUserIDs.contains($0.userId) && seen.insert($0.id).inserted
        }
    }

    private func merge(_ incoming: [ChatMessageDTO], interactionSnapshot: [String: Int]? = nil) {
        for message in unique(incoming) {
            if let interactionSnapshot,
               reactingMessageIDs.contains(message.id)
                || interactionSnapshot[message.id, default: 0] != interactionRevisions[message.id, default: 0] { continue }
            if let index = messages.firstIndex(where: { $0.id == message.id }) { messages[index] = message }
            else { messages.append(message) }
        }
        messages.sort { (Int($0.id) ?? $0.messageDate) < (Int($1.id) ?? $1.messageDate) }
    }

    private func advanceNewestID(_ id: String) {
        if let current = newestID, let currentNumber = Int(current), let incomingNumber = Int(id),
           incomingNumber < currentNumber { return }
        newestID = id
    }

    private func updateRoom(_ page: ChatMessagesPageDTO) {
        reactionOptions = page.reactionOptions
        if let room = page.room, room.id == selectedRoomID {
            if let index = rooms.firstIndex(where: { $0.id == room.id }) { rooms[index] = room }
        }
        if !canSend { quotedMessage = nil }
    }

    private func startPolling() {
        guard isActive else { return }
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard !Task.isCancelled, let self else { return }
                await self.pollNewMessages(refreshInteractions: true)
            }
        }
    }
}
