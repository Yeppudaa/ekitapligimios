#if DEBUG
import SwiftUI
import EkitapligimCore

/// Local fixtures exercise the actual chat view without authentication or production writes.
@MainActor
struct ChatUITestHost: View {
    private let service = ChatFixtureService()
    private let narrow = ProcessInfo.processInfo.arguments.contains("-chat-narrow")
    private let largeText = ProcessInfo.processInfo.arguments.contains("-chat-large-text")
    @StateObject private var fixtureContainer: AppContainer

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChatFixtureProtocol.self]
        _fixtureContainer = StateObject(wrappedValue: AppContainer(apiSession: URLSession(configuration: configuration)))
    }

    var body: some View {
        NavigationStack {
            ChatView(initialRoomID: "4", service: service, signedIn: true)
        }
        .frame(maxWidth: narrow ? 320 : .infinity)
        .dynamicTypeSize(largeText ? .accessibility3 : .large)
        .environmentObject(fixtureContainer)
    }
}

private actor ChatFixtureService: ChatServing {
    private var reacted = false

    func rooms() async throws -> ChatRoomsDTO {
        try JSONDecoder.ekitapligim.decode(ChatRoomsDTO.self,
            from: Data("{\"items\":[\(Self.room)],\"capabilities\":{\"authenticated\":true,\"can_use\":true}}".utf8))
    }
    func messages(roomID: String, limit: Int, beforeID: String?, afterID: String?) async throws -> ChatMessagesPageDTO {
        let items = afterID == nil ? [Self.message(reaction: reacted ? 7 : 0)] : []
        let payload = "{\"room\":\(Self.room),\"items\":[\(items.joined(separator: ","))],\"pagination\":{\"oldest_id\":81,\"newest_id\":81},\"reaction_options\":\(Self.options)}"
        return try JSONDecoder.ekitapligim.decode(ChatMessagesPageDTO.self, from: Data(payload.utf8))
    }
    func send(roomID: String, message: String, quoteMessageID: String?) async throws -> ChatMessageDTO {
        return try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self,
            from: Data(#"{"id":82,"room_id":4,"user_id":1,"username":"Ben","message":"Gönderilen yanıt","is_mine":true,"can_quote":true,"can_react":true,"quoted_message":{"message_id":81,"user_id":9,"username":"Ada","message":"Uzun mesaj"}}"#.utf8))
    }
    func setReaction(roomID: String, messageID: String, reactionID: Int) async throws -> ChatMessageDTO {
        reacted = reactionID > 0
        return try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self, from: Data(Self.message(reaction: reactionID).utf8))
    }
    private static let room = #"{"id":4,"name":"Okur Sohbeti","can_send":true}"#
    private static let options = #"[{"reaction_id":1,"title":"Like","emoji":"👍"},{"reaction_id":7,"title":"Love","emoji":"❤️"},{"reaction_id":6,"title":"Angry","emoji":"😡"}]"#
    private static func message(reaction: Int) -> String {
        "{\"id\":81,\"room_id\":4,\"user_id\":9,\"username\":\"Ada\",\"message\":\"Merhaba herkese, yeni katılmama rağmen uygulamada kitapları keşfetmek çok hoşuma gitti. Bu uzun mesajın tamamı dar ekranda da okunabilmeli. İkinci cümle ve mesajın SONU burada.\",\"can_quote\":true,\"can_react\":true,\"visitor_reaction_id\":\(reaction),\"reactions\":\(reaction > 0 ? "[{\"reaction_id\":7,\"title\":\"Love\",\"emoji\":\"❤️\",\"count\":1}]" : "[]")}"
    }
}

private final class ChatFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]) else { return }
        let body = #"{"member":{"id":9,"username":"Ada","can_view_profile":true},"items":[]}"#
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
#endif
