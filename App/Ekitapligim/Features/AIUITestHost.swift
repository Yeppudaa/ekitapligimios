#if DEBUG
import SwiftUI
import EkitapligimCore

/// Offline, deterministic rendering data. This entire file is excluded from Production compilation.
actor AIFixtureService: AIAssistantServing {
    let mode: String
    var sent = 0
    var delaySend = false
    var failDelete = false
    var signedIn = false
    var messages: [AIMessageDTO] = []
    init(mode: String = "welcome") { self.mode = mode }
    func configure(delay: Bool = false, failDelete: Bool = false) { delaySend = delay; self.failDelete = failDelete }
    func sendCount() -> Int { sent }
    private func decode<T: Decodable>(_ value: String) throws -> T {
        try JSONDecoder.ekitapligim.decode(T.self, from: Data(value.utf8))
    }
    func bootstrap(signedIn: Bool) async throws -> AIBootstrapDTO {
        self.signedIn = signedIn
        if mode == "error" { throw URLError(.notConnectedToInternet) }
        let remaining = mode == "quota" ? 0 : max(0, 2 - sent)
        return try decode("""
        {"enabled":true,"authenticated":\(signedIn),"features":{"widget":true,"context_book":true,"evidence":true,"comparison":true,"suitability":true,"weekly_digest":true},
        "constraints":{"max_message_length":1000},"usage":{"limit":2,"remaining":\(remaining),"used":\(sent),"tier":"guest"},
        "conversations":[{"conversation_id":1,"title":"Bir sonraki favorim"}],
        "discovery":{"latest":[{"thread_id":1,"title":"Küçük Prens","author":"Antoine de Saint-Exupéry"},{"thread_id":2,"title":"Bir Bilim Adamının Romanı","author":"Oğuz Atay"}]}}
        """)
    }
    func createConversation(bookID: Int?) async throws -> AIConversationDTO { try await conversation(1) }
    func conversation(_ id: Int) async throws -> AIConversationDTO {
        var result: AIConversationDTO = try decode("{\"conversation_id\":1,\"title\":\"Bir sonraki favorim\",\"messages\":[]}")
        result.messages = messages; return result
    }
    func send(_ message: String, conversationID: Int, bookID: Int?) async throws -> AIAskResponseDTO {
        sent += 1
        if delaySend { try? await Task.sleep(for: .milliseconds(200)) }
        if mode == "uncertain" { throw URLError(.timedOut) }
        let answer = "Sana umut veren ve okuduktan sonra düşünmeye devam edeceğin bir kitap önerebilirim. Küçük Prens, dostluk ve hayata farklı gözlerle bakmak üzerine sıcak bir başlangıç. "
        let response: AIAskResponseDTO = try decode("""
        {"conversation_id":1,"message_id":\(sent * 2),"answer":"\(String(repeating: answer, count: mode == "long" ? 8 : 1))",
        "usage":{"limit":2,"used":\(sent),"remaining":\(max(0,2-sent))},"book_cards":[{"thread_id":1,"title":"Küçük Prens","author":"Antoine de Saint-Exupéry","recommendation_reason":"Kısa, sıcak ve düşündürücü."}],
        "presentation":{"title":"Okuma yolculuğuna bir öneri","facts":[{"label":"Ruh hali","value":"Umut veren"}],"follow_ups":[{"label":"Benzer kitaplar bul","prompt":"Benzer kitaplar öner."}]}}
        """)
        messages.append(AIMessageDTO(id: sent * 2 - 1, role: "user", content: message)); messages.append(response.message)
        return response
    }
    func deleteConversation(_ id: Int?) async throws {
        if failDelete { throw URLError(.notConnectedToInternet) }; messages = []
    }
    func preferences() async throws -> AIPreferencesDTO { try decode("{\"personalization_enabled\":false,\"digest\":null}") }
    func savePreferences(personalized: Bool, digest: AIDigestPreferenceDTO?) async throws {}
    func confirm(_ action: AIPendingActionDTO) async throws {}
    func collections() async throws -> [AICollectionDTO] { [] }
    func collection(_ slug: String) async throws -> AICollectionDTO { throw AIAssistantError.unavailable }
    func bookProfile(_ bookID: Int) async throws -> AIBookProfileDTO? { nil }
}

@MainActor
struct AIUITestHost: View {
    @StateObject private var model: AIAssistantModel
    @State private var collapsed = false
    @State private var showAssistant = false
    @State private var selection: AppTab = .home
    private var layoutMode: Bool { ProcessInfo.processInfo.environment["AI_FIXTURE_MODE"] == "layout" }
    init() {
        let mode = ProcessInfo.processInfo.environment["AI_FIXTURE_MODE"] ?? "welcome"
        _model = StateObject(wrappedValue: AIAssistantModel(repository: AIFixtureService(mode: mode)))
    }
    var body: some View {
        Group {
            if layoutMode {
                VStack(spacing: 0) {
                    NavigationStack {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(layoutPosts) { post in
                                    HomeAgendaCard(post: post) { showAssistant = true }
                                        .frame(width: 270)
                                        .accessibilityIdentifier("layout-card-\(post.id)")
                                }
                            }
                            .padding(16)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        AIAssistantLauncher(model: model, isCollapsed: $collapsed) { showAssistant = true }
                            .padding(16)
                    }
                    PrimaryTabBar(selection: $selection)
                }
                .sheet(isPresented: $showAssistant) {
                    NavigationStack {
                        AIAssistantView(model: model)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(L10n.commonClose) { showAssistant = false }
                                        .accessibilityIdentifier("layout-close-assistant")
                                }
                            }
                    }
                }
            } else {
                NavigationStack { AIAssistantView(model: model) }
            }
        }
        .task { model.activate(account: nil) }
    }

    private var layoutPosts: [BookAgendaPostDTO] {
        let json = #"[{"id":"1","type":"standard","message":"Bugün yeni bir kitaba başladım.","actor":{"id":"1","username":"Okur"}},{"id":"2","type":"quotation","message":"Bir kitabın sayfaları arasında yeni dünyalar buluruz. Her okuma başka bir yolculuk, her satır başka bir keşif. Okumak hayatın içindeki küçük güzellikleri fark etmemizi sağlar.","actor":{"id":"1","username":"Okur"}},{"id":"3","type":"review","message":"Sürükleyici bir kitap.","actor":{"id":"1","username":"Okur"}},{"id":"4","type":"progress","message":"Yarısını bitirdim.","actor":{"id":"1","username":"Okur"}}]"#
        return (try? JSONDecoder.ekitapligim.decode([BookAgendaPostDTO].self, from: Data(json.utf8))) ?? []
    }
}
#endif
