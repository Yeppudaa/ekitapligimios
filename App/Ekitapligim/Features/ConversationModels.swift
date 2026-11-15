import Foundation
import Combine
import EkitapligimCore

@MainActor
final class ConversationInboxModel: ObservableObject {
    @Published private(set) var conversations: [ConversationDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = false
    @Published private(set) var errorMessage: String?
    private var page = 0
    private var generation = UUID()

    func invalidate() {
        generation = UUID(); conversations = []; page = 0
        isLoading = false; hasMore = false; errorMessage = nil
    }

    func load(reset: Bool, fetch: @Sendable (Int) async throws -> ConversationsPageDTO) async {
        guard !Task.isCancelled, reset || (!isLoading && hasMore) else { return }
        if reset { generation = UUID() }
        let generation = self.generation
        let target = reset ? 1 : page + 1
        isLoading = true; errorMessage = nil
        defer { if generation == self.generation { isLoading = false } }
        do {
            let result = try await fetch(target)
            guard generation == self.generation, !Task.isCancelled else { return }
            var ids = Set<String>()
            conversations = ((reset ? [] : conversations) + result.items).filter { ids.insert($0.id).inserted }
            page = result.currentPage
            hasMore = page >= target && page < result.lastPage
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return }
            errorMessage = L10n.conversationsLoadFailed
        }
    }

    func removeParticipant(_ id: Int) {
        conversations.removeAll { $0.participants.contains { Int($0.id) == id } }
    }
}

@MainActor
final class ConversationDetailModel: ObservableObject {
    @Published private(set) var detail: ConversationDetailDTO?
    @Published var draft = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingEarlier = false
    @Published private(set) var isSending = false
    @Published var errorMessage: String?
    private var generation = UUID()
    private var loadRevision = UUID()
    var hasEarlier: Bool { (detail?.currentPage ?? 1) > 1 }

    func invalidate() {
        generation = UUID(); loadRevision = UUID()
        detail = nil; draft = ""; isLoading = false
        isLoadingEarlier = false; isSending = false; errorMessage = nil
    }

    @discardableResult
    func load(id: String, earlier: Bool = false,
              fetch: @Sendable (Int?) async throws -> ConversationDetailDTO) async -> Bool {
        guard !Task.isCancelled, !isSending, !earlier || (!isLoading && !isLoadingEarlier && hasEarlier) else { return false }
        let generation = self.generation
        let revision = UUID(); loadRevision = revision
        let target = earlier ? max(1, (detail?.currentPage ?? 1) - 1) : nil
        isLoading = !earlier; isLoadingEarlier = earlier; errorMessage = nil
        defer {
            if generation == self.generation, revision == loadRevision { isLoading = false; isLoadingEarlier = false }
        }
        do {
            let result = try await fetch(target)
            guard generation == self.generation, revision == loadRevision, !Task.isCancelled else { return false }
            guard result.conversation.id == id,
                  result.messages.allSatisfy({ String($0.conversationId) == id }),
                  target == nil || result.currentPage == target else { throw APIClientError.invalidResponse }
            let messages = Self.unique((earlier ? (detail?.messages ?? []) : []) + result.messages)
            detail = ConversationDetailDTO(conversation: result.conversation, messages: messages,
                                           currentPage: result.currentPage, lastPage: result.lastPage)
            return true
        } catch {
            guard generation == self.generation, revision == loadRevision, !Task.isCancelled else { return false }
            errorMessage = L10n.conversationsLoadFailed
            return false
        }
    }

    func send(id: String, reply: @Sendable (String) async throws -> ConversationReplyDTO) async {
        let submitted = draft
        let text = submitted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !Task.isCancelled, !isSending, !text.isEmpty, detail?.conversation.canReply == true else { return }
        let generation = self.generation
        // A read started before this write cannot overwrite the acknowledged message.
        loadRevision = UUID(); isLoading = false; isLoadingEarlier = false
        isSending = true; errorMessage = nil
        defer { if generation == self.generation { isSending = false } }
        do {
            let result = try await reply(text)
            guard generation == self.generation, !Task.isCancelled else { return }
            guard result.success, result.conversation.id == id, String(result.message.conversationId) == id else {
                throw APIClientError.invalidResponse
            }
            detail = ConversationDetailDTO(conversation: result.conversation,
                messages: Self.unique((detail?.messages ?? []) + [result.message]),
                currentPage: detail?.currentPage ?? 1, lastPage: detail?.lastPage ?? 1)
            if draft == submitted { draft = "" }
        } catch {
            guard generation == self.generation, !Task.isCancelled else { return }
            errorMessage = L10n.conversationsSendFailed
        }
    }

    private static func unique(_ messages: [ConversationMessageDTO]) -> [ConversationMessageDTO] {
        var byID: [String: ConversationMessageDTO] = [:]
        for message in messages { byID[message.id] = message }
        return byID.values.sorted {
            if $0.messageDate != $1.messageDate { return $0.messageDate < $1.messageDate }
            if let left = Int($0.id), let right = Int($1.id) { return left < right }
            return $0.id < $1.id
        }
    }
}
