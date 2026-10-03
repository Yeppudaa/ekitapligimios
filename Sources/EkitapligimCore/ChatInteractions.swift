import Foundation

public protocol ChatServing: Sendable {
    func rooms() async throws -> ChatRoomsDTO
    func messages(roomID: String, limit: Int, beforeID: String?, afterID: String?) async throws -> ChatMessagesPageDTO
    func send(roomID: String, message: String, quoteMessageID: String?) async throws -> ChatMessageDTO
    func setReaction(roomID: String, messageID: String, reactionID: Int) async throws -> ChatMessageDTO
}

extension ChatRepository: ChatServing {}

/// Uses the forum's configured reaction IDs; zero is reserved for removing a reaction.
public struct ChatReactionDTO: Decodable, Equatable, Identifiable, Sendable {
    public let reactionId: Int
    public let title: String
    public let emoji: String
    public let imageUrl: String?
    public let spriteMode: Bool
    public let spriteParams: ChatReactionSpriteDTO?
    public let count: Int
    public var id: Int { reactionId }

    public init(reactionId: Int, title: String, emoji: String = "", imageUrl: String? = nil, count: Int = 0,
                spriteMode: Bool = false, spriteParams: ChatReactionSpriteDTO? = nil) {
        self.reactionId = reactionId
        self.title = title
        self.emoji = emoji
        self.imageUrl = imageUrl
        self.spriteMode = spriteMode
        self.spriteParams = spriteParams
        self.count = max(count, 0)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.reactionId = container.decodeFlexibleInt(forKey: .reactionId)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        self.spriteMode = container.decodeFlexibleBool(forKey: .spriteMode)
        self.spriteParams = try? container.decodeIfPresent(ChatReactionSpriteDTO.self, forKey: .spriteParams)
        self.count = max(container.decodeFlexibleInt(forKey: .count), 0)
    }

    private enum CodingKeys: String, CodingKey {
        case reactionId, title, emoji, imageUrl, count, spriteMode, spriteParams
    }
}

public struct ChatQuotedMessageDTO: Decodable, Equatable, Sendable {
    public let messageId: String
    public let userId: String
    public let username: String
    public let message: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Historical web quotes can legitimately have no resolvable message or user ID.
        self.messageId = try container.decodeFlexibleStringIfPresent(forKey: .messageId) ?? "0"
        self.userId = try container.decodeFlexibleStringIfPresent(forKey: .userId) ?? "0"
        self.username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case messageId, userId, username, message
    }
}
