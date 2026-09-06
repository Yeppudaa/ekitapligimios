import Foundation
import Combine
import EkitapligimCore

@MainActor
final class AIAssistantModel: ObservableObject {
    @Published private(set) var bootstrap: AIBootstrapDTO?
    @Published private(set) var conversation: AIConversationDTO?
    @Published private(set) var busy = false
    @Published private(set) var sending = false
    @Published private(set) var error: String?
    @Published private(set) var notice: String?
    @Published private(set) var book: BookDTO?
    @Published private(set) var bookProfile: AIBookProfileDTO?
    @Published private(set) var collections: [AICollectionDTO] = []
    @Published private(set) var selectedCollection: AICollectionDTO?
    @Published private(set) var preferences: AIPreferencesDTO?
    @Published private(set) var confirmedActions: Set<Int> = []
    @Published var input = ""
    private let repository: any AIAssistantServing
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var identity: String?
    private var initialized = false
    private var uncertain = false
    private(set) var contextBookID: Int?
    var signedIn: Bool { identity != nil }
    var canSend: Bool {
        !uncertain && AIPolicy.canSend(bootstrap: bootstrap, signedIn: signedIn, contextBookID: contextBookID, busy: busy)
    }
    var showLauncher: Bool { bootstrap?.enabled == true && bootstrap?.features.widget == true }
    var messages: [AIMessageDTO] { conversation?.messages ?? [] }

    init(repository: any AIAssistantServing) { self.repository = repository }
    func waitUntilIdle() async { await task?.value }

    func activate(account: String?) {
        guard !initialized || identity != account else { return }
        initialized = true; identity = account
        invalidate()
        bootstrap = nil; conversation = nil; input = ""; book = nil; contextBookID = nil
        bookProfile = nil; collections = []; selectedCollection = nil; preferences = nil
        confirmedActions = []; uncertain = false
        refresh()
    }
    func open(book: BookDTO? = nil, bookID: Int? = nil) {
        let id = bookID ?? book.flatMap { Int($0.id) }
        if contextBookID != id {
            invalidate(); conversation = nil; input = ""; uncertain = false; bookProfile = nil
        }
        contextBookID = id; self.book = book
        refresh()
    }
    func resolveBook(_ id: Int, repository: BookRepository) async {
        let stamp = generation
        guard let value = try? await repository.book(id: id), current(stamp), contextBookID == id else { return }
        book = value
    }
    func refresh() {
        guard !busy else { return }
        run { model, stamp in
            let b = try await model.repository.bootstrap(signedIn: model.signedIn)
            guard model.current(stamp) else { return }
            model.bootstrap = b
            if let id = model.conversation?.conversationId {
                do {
                    let conversation = try await model.repository.conversation(id)
                    guard model.current(stamp) else { return }
                    model.conversation = conversation; model.uncertain = false
                } catch {
                    guard model.current(stamp) else { return }
                    if case APIClientError.httpStatus(404, _) = error {
                        model.conversation = nil; model.uncertain = false
                    } else { throw error }
                }
            }
            if let id = model.contextBookID, b.enabled, b.features.bookProfiles {
                let profile = try await model.repository.bookProfile(id)
                guard model.current(stamp) else { return }; model.bookProfile = profile
            }
        }
    }
    func newConversation() {
        guard !busy else { return }
        conversation = nil; input = ""; uncertain = false; confirmedActions = []; error = nil; notice = nil
        refresh()
    }
    func send(_ prompt: String? = nil) {
        let text = (prompt ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        guard !text.isEmpty, text.unicodeScalars.count <= (bootstrap?.constraints.maxMessageLength ?? 0) else {
            error = AIL10n.invalidInput; return
        }
        run(sending: true) { model, stamp in
            // Recheck server quota and bearer identity immediately before every new message.
            let b = try await model.repository.bootstrap(signedIn: model.signedIn)
            guard model.current(stamp) else { return }
            model.bootstrap = b
            guard AIPolicy.canSend(bootstrap: b, signedIn: model.signedIn, contextBookID: model.contextBookID, busy: false),
                  text.unicodeScalars.count <= b.constraints.maxMessageLength else {
                throw AIAssistantError.unavailable
            }
            if model.conversation == nil {
                let created = try await model.repository.createConversation(bookID: model.contextBookID)
                guard model.current(stamp) else { return }; model.conversation = created
            }
            guard let id = model.conversation?.conversationId else { throw APIClientError.invalidResponse }
            model.input = ""
            let optimisticID = -Int.random(in: 1...Int.max)
            model.conversation?.messages.append(AIMessageDTO(id: optimisticID, role: "user", content: text))
            do {
                let response = try await model.repository.send(text, conversationID: id, bookID: model.contextBookID)
                guard model.current(stamp) else { return }
                guard response.conversationId == id, response.messageId > 0 else { throw APIClientError.invalidResponse }
                model.conversation?.messages.append(response.message)
                model.bootstrap = nil // Never keep a stale quota after a committed mutation.
                let updated = try await model.repository.bootstrap(signedIn: model.signedIn)
                guard model.current(stamp) else { return }; model.bootstrap = updated
            } catch {
                guard model.current(stamp) else { return }
                model.uncertain = true; model.bootstrap = nil
                // Read-only reconciliation. Never automatically issue the message a second time.
                do {
                    let updatedConversation = try await model.repository.conversation(id)
                    let updatedBootstrap = try await model.repository.bootstrap(signedIn: model.signedIn)
                    guard model.current(stamp) else { return }
                    model.conversation = updatedConversation; model.bootstrap = updatedBootstrap; model.uncertain = false
                } catch { /* A manual refresh is required before another send. */ }
                if model.current(stamp) { model.error = model.uncertain ? AIL10n.uncertainSend : AIErrorMessage.text(error) }
            }
        }
    }
    func loadConversation(_ id: Int) {
        run { model, stamp in
            let value = try await model.repository.conversation(id)
            guard model.current(stamp) else { return }
            model.conversation = value; model.contextBookID = value.contextThreadId > 0 ? value.contextThreadId : nil
            model.book = nil; model.bookProfile = nil; model.input = ""; model.uncertain = false
            let b = try await model.repository.bootstrap(signedIn: model.signedIn)
            guard model.current(stamp) else { return }; model.bootstrap = b
        }
    }
    func deleteConversation(_ id: Int?) {
        run { model, stamp in
            try await model.repository.deleteConversation(id)
            guard model.current(stamp) else { return }
            if id == nil || model.conversation?.conversationId == id {
                model.conversation = nil; model.uncertain = false; model.input = ""
            }
            let b = try await model.repository.bootstrap(signedIn: model.signedIn)
            guard model.current(stamp) else { return }; model.bootstrap = b
        }
    }
    func loadPreferences() {
        guard signedIn, bootstrap?.enabled == true else { return }
        preferences = nil
        run { model, stamp in
            let result = try await model.repository.preferences()
            guard model.current(stamp) else { return }; model.preferences = result
        }
    }
    func savePreferences(personalized: Bool, digest: AIDigestPreferenceDTO?) {
        guard signedIn, bootstrap?.enabled == true else { return }
        run { model, stamp in
            try await model.repository.savePreferences(personalized: personalized, digest: model.bootstrap?.features.weeklyDigest == true ? digest : nil)
            guard model.current(stamp) else { return }
            let b = try await model.repository.bootstrap(signedIn: model.signedIn)
            guard model.current(stamp) else { return }; model.bootstrap = b; model.notice = AIL10n.text("saved")
        }
    }
    func confirm(_ action: AIPendingActionDTO) {
        guard signedIn, bootstrap?.enabled == true, !confirmedActions.contains(action.id) else { return }
        run { model, stamp in
            try await model.repository.confirm(action)
            guard model.current(stamp) else { return }
            model.confirmedActions.insert(action.id); model.notice = AIL10n.text("actionDone")
        }
    }
    func loadCollections(slug: String? = nil) {
        if slug != nil { selectedCollection = nil }
        run { model, stamp in
            let b = try await model.repository.bootstrap(signedIn: model.signedIn)
            guard model.current(stamp) else { return }; model.bootstrap = b
            guard b.enabled, b.features.collections else { throw AIAssistantError.unavailable }
            if let slug {
                let result = try await model.repository.collection(slug)
                guard model.current(stamp) else { return }; model.selectedCollection = result
            } else {
                let result = try await model.repository.collections()
                guard model.current(stamp) else { return }; model.collections = result
            }
        }
    }
    private func invalidate() {
        generation = UUID(); task?.cancel(); task = nil; busy = false; sending = false; error = nil; notice = nil
    }
    private func current(_ stamp: UUID) -> Bool { generation == stamp && !Task.isCancelled }
    private func run(sending: Bool = false, _ operation: @escaping @MainActor (AIAssistantModel, UUID) async throws -> Void) {
        guard !busy else { return }
        busy = true; self.sending = sending; error = nil; notice = nil
        let stamp = generation
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.current(stamp) { self.busy = false; self.sending = false; self.task = nil } }
            do { try await operation(self, stamp) }
            catch {
                guard self.current(stamp) else { return }
                self.error = AIErrorMessage.text(error)
                if error as? APIClientError == .authenticationRequired { self.bootstrap = nil }
            }
        }
    }
}
