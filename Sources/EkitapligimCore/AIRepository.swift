import Foundation

public protocol AIGuestKeyProviding: Sendable { func guestKey() async throws -> String }

public protocol AIAssistantServing: Sendable {
    func bootstrap(signedIn: Bool) async throws -> AIBootstrapDTO
    func createConversation(bookID: Int?) async throws -> AIConversationDTO
    func conversation(_ id: Int) async throws -> AIConversationDTO
    func send(_ message: String, conversationID: Int, bookID: Int?) async throws -> AIAskResponseDTO
    func deleteConversation(_ id: Int?) async throws
    func preferences() async throws -> AIPreferencesDTO
    func savePreferences(personalized: Bool, digest: AIDigestPreferenceDTO?) async throws
    func confirm(_ action: AIPendingActionDTO) async throws
    func collections() async throws -> [AICollectionDTO]
    func collection(_ slug: String) async throws -> AICollectionDTO
    func bookProfile(_ bookID: Int) async throws -> AIBookProfileDTO?
}

public struct AIAssistantRepository: AIAssistantServing {
    private let client: APIClient
    private let guestKeys: any AIGuestKeyProviding
    public init(client: APIClient, guestKeys: any AIGuestKeyProviding) { self.client = client; self.guestKeys = guestKeys }

    private func endpoint(_ path: String, method: HTTPMethod = .get, fields: [String: String]? = nil,
                          authenticated: Bool = false, message: Bool = false) async throws -> APIEndpoint {
        APIEndpoint(method: method, path: path, body: fields.map(RequestBody.form),
                    requiresAuthentication: authenticated, service: .assistant,
                    guestKey: try await guestKeys.guestKey(), timeout: message ? 180 : 30)
    }
    public func bootstrap(signedIn: Bool) async throws -> AIBootstrapDTO {
        let request = try await endpoint("bootstrap", authenticated: signedIn)
        var result: AIBootstrapDTO = try await client.request(request)
        if signedIn && !result.authenticated {
            try await client.refreshAssistantIdentity()
            result = try await client.request(request)
        }
        guard result.authenticated == signedIn else { throw APIClientError.authenticationRequired }
        return result
    }
    public func createConversation(bookID: Int?) async throws -> AIConversationDTO {
        var fields = context(bookID); fields["title"] = AIL10n.newConversation
        let result: AIConversationEnvelope = try await client.request(try await endpoint("conversations", method: .post, fields: fields))
        guard result.conversation.conversationId > 0 else { throw APIClientError.invalidResponse }
        return result.conversation
    }
    public func conversation(_ id: Int) async throws -> AIConversationDTO {
        guard id > 0 else { throw APIClientError.invalidURL }
        let result: AIConversationEnvelope = try await client.request(try await endpoint("conversations/\(id)"))
        guard result.conversation.conversationId == id else { throw APIClientError.invalidResponse }
        return result.conversation
    }
    public func send(_ message: String, conversationID: Int, bookID: Int?) async throws -> AIAskResponseDTO {
        guard conversationID > 0 else { throw APIClientError.invalidURL }
        var fields = context(bookID); fields["message"] = message
        return try await client.request(try await endpoint("conversations/\(conversationID)", method: .post, fields: fields, message: true))
    }
    public func deleteConversation(_ id: Int?) async throws {
        if let id, id <= 0 { throw APIClientError.invalidURL }
        let _: AISuccessDTO = try await client.request(try await endpoint(id.map { "conversations/\($0)" } ?? "conversations", method: .delete))
    }
    public func preferences() async throws -> AIPreferencesDTO {
        try await client.request(try await endpoint("preferences", authenticated: true))
    }
    public func savePreferences(personalized: Bool, digest: AIDigestPreferenceDTO?) async throws {
        var fields = ["personalization_enabled": personalized ? "1" : "0"]
        if let digest {
            fields["digest_enabled"] = digest.enabled ? "1" : "0"
            fields["site_alert"] = digest.siteAlert ? "1" : "0"
            fields["email"] = digest.email ? "1" : "0"
            fields["push"] = digest.push ? "1" : "0"
            for (index, id) in digest.categoryIds.enumerated() { fields["category_ids[\(index)]"] = String(id) }
        }
        let _: AISuccessDTO = try await client.request(try await endpoint("preferences", method: .post, fields: fields, authenticated: true))
    }
    public func confirm(_ action: AIPendingActionDTO) async throws {
        guard action.canConfirm(at: Date()) else { throw AIAssistantError.expiredAction }
        let _: AISuccessDTO = try await client.request(try await endpoint("actions/\(action.actionId)/confirm", method: .post,
            fields: ["confirmation_token": action.confirmationToken], authenticated: true))
    }
    public func collections() async throws -> [AICollectionDTO] {
        let result: AICollectionsEnvelope = try await client.request(try await endpoint("collections")); return result.collections
    }
    public func collection(_ slug: String) async throws -> AICollectionDTO {
        guard AIPolicy.validSlug(slug) else { throw APIClientError.invalidURL }
        let result: AICollectionEnvelope = try await client.request(try await endpoint("collections/\(slug)")); return result.collection
    }
    public func bookProfile(_ bookID: Int) async throws -> AIBookProfileDTO? {
        guard bookID > 0 else { throw APIClientError.invalidURL }
        let result: AIProfileEnvelope = try await client.request(try await endpoint("books/\(bookID)/profile")); return result.profile
    }
    private func context(_ bookID: Int?) -> [String: String] {
        var fields = ["entry_point": bookID == nil ? "ios" : "book_detail"]
        if let bookID, bookID > 0 { fields["context_thread_id"] = String(bookID) }
        return fields
    }
}
private struct AIConversationEnvelope: Decodable { let conversation: AIConversationDTO }
private struct AICollectionsEnvelope: Decodable { let collections: [AICollectionDTO] }
private struct AICollectionEnvelope: Decodable { let collection: AICollectionDTO }
private struct AIProfileEnvelope: Decodable { let profile: AIBookProfileDTO? }
private struct AISuccessDTO: Decodable {
    let success: Bool
    private enum CodingKeys: String, CodingKey { case success }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        guard success else { throw APIClientError.invalidResponse }
    }
}

public enum AIAssistantError: Error { case expiredAction, unavailable, invalidInput, uncertainSend }

public enum AIErrorMessage {
    public static func text(_ error: Error) -> String {
        if let ai = error as? AIAssistantError {
            switch ai {
            case .expiredAction: return AIL10n.expiredAction
            case .invalidInput: return AIL10n.invalidInput
            case .uncertainSend: return AIL10n.uncertainSend
            case .unavailable: return AIL10n.unavailable
            }
        }
        if let api = error as? APIClientError {
            if api == .authenticationRequired { return AIL10n.sessionRequired }
            if case .httpStatus(let status, _) = api {
                switch status {
                case 401: return AIL10n.sessionRequired
                case 403: return AIL10n.permissionDenied
                case 404: return AIL10n.notFound
                case 422: return AIL10n.invalidInput
                case 429: return AIL10n.limitReached
                case 503: return AIL10n.unavailable
                default: break
                }
            }
        }
        return AIL10n.connectionError
    }
}
