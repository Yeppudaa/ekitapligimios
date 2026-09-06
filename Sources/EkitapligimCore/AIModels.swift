import Foundation

// AI payloads contain optional, feature-gated blocks and several legacy Android aliases.
// Decode those blocks tolerantly; authorization and quota values always default to denied.
private struct AIKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}
private struct AIFields {
    let values: KeyedDecodingContainer<AIKey>
    init(_ decoder: Decoder) throws { values = try decoder.container(keyedBy: AIKey.self) }
    func get<T: Decodable>(_ key: String, as: T.Type = T.self) -> T? { try? values.decode(T.self, forKey: AIKey(key)) }
    func text(_ key: String, _ alias: String = "") -> String {
        get(key, as: String.self) ?? get(alias, as: String.self) ?? ""
    }
    func number(_ key: String, _ alias: String = "") -> Int {
        get(key, as: Int.self) ?? Int(text(key, alias)) ?? get(alias, as: Int.self) ?? 0
    }
    func flag(_ key: String) -> Bool { get(key, as: Bool.self) ?? false }
    func list<T: Decodable>(_ key: String) -> [T] { get(key) ?? [] }
}

public struct AIUsageDTO: Decodable, Equatable, Sendable {
    public var limit = 0
    public var used = 0
    public var remaining = 0
    public var tier = "guest"
    public init() {}
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        limit = max(0, f.number("limit")); used = max(0, f.number("used"))
        remaining = min(limit, max(0, f.number("remaining")))
        tier = f.text("tier")
    }
}
public struct AIFeaturesDTO: Decodable, Equatable, Sendable {
    public var widget = false, advancedDiscovery = false, contextBook = false, bookProfiles = false
    public var bookAccess = false, evidence = false, collections = false, weeklyDigest = false
    public var suitability = false, personalAdvisor = false, comparison = false
    public init() {}
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        widget = f.flag("widget"); advancedDiscovery = f.flag("advancedDiscovery")
        contextBook = f.flag("contextBook"); bookProfiles = f.flag("bookProfiles")
        bookAccess = f.flag("bookAccess"); evidence = f.flag("evidence")
        collections = f.flag("collections"); weeklyDigest = f.flag("weeklyDigest")
        suitability = f.flag("suitability"); personalAdvisor = f.flag("personalAdvisor")
        comparison = f.flag("comparison")
    }
}
public struct AIConstraintsDTO: Decodable, Equatable, Sendable {
    public var maxMessageLength = 0
    public var guestRetentionSeconds = 0, memberRetentionSeconds = 0, actionConfirmationSeconds = 0
    public init() {}
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        maxMessageLength = max(0, f.number("maxMessageLength"))
        guestRetentionSeconds = max(0, f.number("guestRetentionSeconds"))
        memberRetentionSeconds = max(0, f.number("memberRetentionSeconds"))
        actionConfirmationSeconds = max(0, f.number("actionConfirmationSeconds"))
    }
}
public struct AIDigestPreferenceDTO: Decodable, Equatable, Sendable {
    public var enabled = false, siteAlert = false, email = false, push = false
    public var frequency = "weekly"
    public var categoryIds: [Int] = []
    public init() {}
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        enabled = f.flag("enabled"); siteAlert = f.flag("siteAlert")
        email = f.flag("email"); push = f.flag("push"); frequency = f.text("frequency")
        categoryIds = f.get("categoryIds") ?? f.text("categoryIds").split(separator: ",").compactMap { Int($0) }
    }
}
public struct AIBookCardDTO: Decodable, Equatable, Sendable, Identifiable {
    public let threadId: Int
    public let title: String, author: String, publisher: String, category: String
    public let coverUrl: String, detailUrl: String, description: String, recommendationReason: String
    public let pageCount: Int
    public var id: Int { threadId }
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        threadId = f.number("threadId", "bookId"); title = f.text("title", "bookTitle")
        author = f.text("author", "bookAuthor"); publisher = f.text("publisher", "bookPublisher")
        category = f.text("category"); coverUrl = f.text("coverUrl")
        detailUrl = f.text("detailUrl", "viewUrl"); description = f.text("description")
        recommendationReason = f.text("recommendationReason", "rationale")
        pageCount = f.number("pageCount", "bookPages")
    }
}
public struct AIFactDTO: Decodable, Equatable, Sendable { public let label: String; public let value: String }
public struct AIFollowUpDTO: Decodable, Equatable, Sendable {
    public let label: String, prompt: String
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder); label = f.text("label", "prompt"); prompt = f.text("prompt", "label")
    }
}
public struct AIPresentationDTO: Decodable, Equatable, Sendable {
    public let type: String, title: String, summary: String
    public let facts: [AIFactDTO], comparison: [[String: String]], followUps: [AIFollowUpDTO]
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        type = f.text("type"); title = f.text("title"); summary = f.text("summary")
        facts = f.list("facts"); comparison = f.list("comparison"); followUps = f.list("followUps")
    }
}
public struct AIEvidenceDTO: Decodable, Equatable, Sendable {
    public let label: String, source: String, url: String
    public let verified: Bool
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        label = f.text("label", "title"); source = f.text("source"); url = f.text("url"); verified = f.flag("verified")
    }
}
public struct AIPendingActionDTO: Decodable, Equatable, Sendable, Identifiable {
    public let actionId: Int, type: String, preview: String, confirmationToken: String, expiresAt: Int
    public var id: Int { actionId }
    public func canConfirm(at date: Date) -> Bool {
        actionId > 0 && !preview.isEmpty && !confirmationToken.isEmpty && Double(expiresAt) > date.timeIntervalSince1970
    }
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        actionId = f.number("actionId"); type = f.text("actionType", "type")
        preview = f.text("preview"); confirmationToken = f.text("confirmationToken")
        expiresAt = f.number("expiresDate", "expiresAt")
    }
}
public struct AIMessageDTO: Decodable, Equatable, Sendable, Identifiable {
    public let messageId: Int, role: String, content: String
    public var presentation: AIPresentationDTO?
    public var bookCards: [AIBookCardDTO] = [], evidence: [AIEvidenceDTO] = []
    public var pendingAction: AIPendingActionDTO?
    public var scopeNotice = ""
    public var id: Int { messageId }
    public init(id: Int, role: String, content: String) {
        messageId = id; self.role = role; self.content = content
    }
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        messageId = f.number("messageId"); role = f.text("role"); content = f.text("content")
        let payload: AIPayloadDTO? = f.get("payload")
        presentation = payload?.presentation; bookCards = payload?.bookCards ?? []
        evidence = payload?.evidence ?? []; pendingAction = payload?.pendingAction
        scopeNotice = payload?.scopeNotice ?? ""
    }
}
private struct AIPayloadDTO: Decodable {
    let presentation: AIPresentationDTO?, bookCards: [AIBookCardDTO], evidence: [AIEvidenceDTO]
    let pendingAction: AIPendingActionDTO?, scopeNotice: String
    init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        presentation = f.get("presentation"); bookCards = f.list("bookCards"); evidence = f.list("evidence")
        pendingAction = f.get("pendingAction"); scopeNotice = f.text("scopeNotice")
    }
}
public struct AIConversationSummaryDTO: Decodable, Equatable, Sendable, Identifiable {
    public let conversationId: Int, title: String, personalized: Bool, expiresDate: Int
    public var id: Int { conversationId }
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        conversationId = f.number("conversationId"); title = f.text("title")
        personalized = f.flag("personalized"); expiresDate = f.number("expiresDate")
    }
}
public struct AIConversationDTO: Decodable, Equatable, Sendable {
    public let conversationId: Int, title: String, personalized: Bool, contextThreadId: Int
    public var messages: [AIMessageDTO]
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        conversationId = f.number("conversationId"); title = f.text("title"); personalized = f.flag("personalized")
        messages = f.list("messages")
        contextThreadId = f.get("context", as: AIContextDTO.self)?.threadId ?? 0
    }
}
private struct AIContextDTO: Decodable { let threadId: Int? }
public struct AICollectionDTO: Decodable, Equatable, Sendable, Identifiable {
    public let collectionId: Int, title: String, slug: String, description: String, books: [AIBookCardDTO]
    public var id: Int { collectionId }
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        collectionId = f.number("collectionId"); title = f.text("title"); slug = f.text("slug")
        description = f.text("description"); books = f.list("books")
    }
}
public struct AIBootstrapDTO: Decodable, Equatable, Sendable {
    public let enabled: Bool, authenticated: Bool, personalizationEnabled: Bool
    public let features: AIFeaturesDTO, constraints: AIConstraintsDTO, usage: AIUsageDTO
    public let digest: AIDigestPreferenceDTO?, conversations: [AIConversationSummaryDTO]
    public let latest: [AIBookCardDTO], popular: [AIBookCardDTO], collections: [AICollectionDTO]
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        enabled = f.flag("enabled"); authenticated = f.flag("authenticated")
        personalizationEnabled = f.flag("personalizationEnabled")
        features = f.get("features") ?? AIFeaturesDTO(); constraints = f.get("constraints") ?? AIConstraintsDTO()
        usage = f.get("usage") ?? AIUsageDTO(); digest = f.get("digest"); conversations = f.list("conversations")
        let discovery: AIDiscoveryDTO? = f.get("discovery")
        latest = discovery?.latest ?? []; popular = discovery?.popular ?? []; collections = f.list("collections")
    }
}
private struct AIDiscoveryDTO: Decodable {
    let latest: [AIBookCardDTO], popular: [AIBookCardDTO]
    init(from decoder: Decoder) throws { let f = try AIFields(decoder); latest = f.list("latest"); popular = f.list("popular") }
}
public struct AIAskResponseDTO: Decodable, Equatable, Sendable {
    public let conversationId: Int, messageId: Int, answer: String, usage: AIUsageDTO
    public let presentation: AIPresentationDTO?, bookCards: [AIBookCardDTO], evidence: [AIEvidenceDTO]
    public let pendingAction: AIPendingActionDTO?, scopeNotice: String
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        conversationId = f.number("conversationId"); messageId = f.number("messageId"); answer = f.text("answer")
        usage = f.get("usage") ?? AIUsageDTO(); presentation = f.get("presentation")
        bookCards = f.list("bookCards"); evidence = f.list("evidence")
        pendingAction = f.get("pendingAction"); scopeNotice = f.text("scopeNotice")
    }
    public var message: AIMessageDTO {
        var result = AIMessageDTO(id: messageId, role: "assistant", content: answer)
        result.presentation = presentation; result.bookCards = bookCards; result.evidence = evidence
        result.pendingAction = pendingAction; result.scopeNotice = scopeNotice
        return result
    }
}
public struct AIPreferencesDTO: Decodable, Equatable, Sendable {
    public let personalizationEnabled: Bool, digest: AIDigestPreferenceDTO?
}
public struct AIBookProfileDTO: Decodable, Equatable, Sendable {
    public let themes: [String], mood: String, pace: String, difficulty: String, audience: String
    public let contentWarnings: [String], readingMinutes: Int
    public init(from decoder: Decoder) throws {
        let f = try AIFields(decoder)
        themes = f.list("themes"); mood = f.text("mood"); pace = f.text("pace")
        difficulty = f.text("difficulty"); audience = f.text("audience")
        contentWarnings = f.list("contentWarnings"); readingMinutes = f.number("readingMinutes")
    }
}

public enum AIPolicy {
    public static func canSend(bootstrap: AIBootstrapDTO?, signedIn: Bool, contextBookID: Int?, busy: Bool) -> Bool {
        guard let b = bootstrap, b.enabled, b.authenticated == signedIn,
              b.usage.remaining > 0, b.constraints.maxMessageLength > 0, !busy else { return false }
        return contextBookID == nil || b.features.contextBook
    }
    public static func validSlug(_ slug: String) -> Bool {
        !slug.isEmpty && slug.count <= 150 && slug.allSatisfy { "abcdefghijklmnopqrstuvwxyz0123456789-".contains($0) }
    }
    public static func secureSource(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https",
              url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
}
