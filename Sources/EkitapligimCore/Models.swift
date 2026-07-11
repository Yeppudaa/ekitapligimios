import Foundation

public struct SiteStatsDTO: Decodable, Equatable, Sendable {
    public let totalBooks: Int
    public let totalAuthors: Int
    public let totalPublishers: Int
    public let totalCategories: Int
    public let totalDownloadableBooks: Int
    public let booksWithCover: Int
    public let booksWithSummary: Int
    public let lastRebuildDate: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalBooks = try container.decodeIfPresent(Int.self, forKey: .totalBooks) ?? 0
        totalAuthors = try container.decodeIfPresent(Int.self, forKey: .totalAuthors) ?? 0
        totalPublishers = try container.decodeIfPresent(Int.self, forKey: .totalPublishers) ?? 0
        totalCategories = try container.decodeIfPresent(Int.self, forKey: .totalCategories) ?? 0
        totalDownloadableBooks = try container.decodeIfPresent(Int.self, forKey: .totalDownloadableBooks) ?? 0
        booksWithCover = try container.decodeIfPresent(Int.self, forKey: .booksWithCover) ?? 0
        booksWithSummary = try container.decodeIfPresent(Int.self, forKey: .booksWithSummary) ?? 0
        lastRebuildDate = try container.decodeIfPresent(Int.self, forKey: .lastRebuildDate) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case totalBooks
        case totalAuthors
        case totalPublishers
        case totalCategories
        case totalDownloadableBooks
        case booksWithCover
        case booksWithSummary
        case lastRebuildDate
    }
}

public enum DirectoryKind: String, CaseIterable, Sendable {
    case author
    case publisher

    public var path: String {
        switch self {
        case .author: "authors"
        case .publisher: "publishers"
        }
    }
}

public struct DirectoryItemDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let slug: String
    public let bookCount: Int
    public let kind: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.slug])
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? ""
        self.slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? id
        self.bookCount = try container.decodeIfPresent(Int.self, forKey: .bookCount) ?? 0
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case slug
        case bookCount
        case kind
    }
}

public struct DirectoryPageDTO: Decodable, Equatable, Sendable {
    public let items: [DirectoryItemDTO]
    public let currentPage: Int
    public let lastPage: Int
    public let total: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decodeIfPresent([DirectoryItemDTO].self, forKey: .authors)
            ?? container.decodeIfPresent([DirectoryItemDTO].self, forKey: .publishers)
            ?? container.decodeIfPresent([DirectoryItemDTO].self, forKey: .items)
            ?? []
        let pagination = try container.decodeIfPresent(DirectoryPaginationDTO.self, forKey: .pagination)
        self.currentPage = pagination?.page ?? 1
        self.lastPage = pagination?.pages ?? 1
        self.total = pagination?.total ?? items.count
    }

    private enum CodingKeys: String, CodingKey {
        case authors
        case publishers
        case items
        case pagination
    }
}

private struct DirectoryPaginationDTO: Decodable, Equatable, Sendable {
    let page: Int?
    let pages: Int?
    let total: Int?
}

public struct BookRequestDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let requestedBy: String
    public let voteCount: Int
    public let status: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.requestId])
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        self.requestedBy = try container.decodeIfPresent(String.self, forKey: .requestedBy) ?? ""
        self.voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount) ?? 0
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "PENDING"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestId
        case title
        case author
        case requestedBy
        case voteCount
        case status
    }
}

public struct BookRequestsPageDTO: Decodable, Equatable, Sendable {
    public let items: [BookRequestDTO]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decodeIfPresent([BookRequestDTO].self, forKey: .bookRequests)
            ?? container.decodeIfPresent([BookRequestDTO].self, forKey: .items)
            ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case bookRequests
        case items
    }
}

public struct BookRequestEnvelopeDTO: Decodable, Equatable, Sendable {
    public let request: BookRequestDTO

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.request = try container.decodeIfPresent(BookRequestDTO.self, forKey: .request)
            ?? container.decode(BookRequestDTO.self, forKey: .bookRequest)
    }

    private enum CodingKeys: String, CodingKey {
        case request
        case bookRequest
    }
}

public struct BookRequestVoteDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let voted: Bool
    public let voteCount: Int
}

public struct ConversationParticipantDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let username: String
    public let avatarUrl: String
    public let isActive: Bool
}

public struct ConversationMessageDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let conversationId: Int
    public let userId: Int
    public let username: String
    public let message: String
    public let messageDate: Int
    public let avatarUrl: String
    public let isMine: Bool
}

public struct ConversationDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let starterUsername: String
    public let lastMessageDate: Int
    public let lastMessageUsername: String
    public let replyCount: Int
    public let isUnread: Bool
    public let isStarred: Bool
    public let canReply: Bool
    public let participants: [ConversationParticipantDTO]
    public let preview: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.conversationId])
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.starterUsername = try container.decodeIfPresent(String.self, forKey: .starterUsername) ?? ""
        self.lastMessageDate = try container.decodeIfPresent(Int.self, forKey: .lastMessageDate) ?? 0
        self.lastMessageUsername = try container.decodeIfPresent(String.self, forKey: .lastMessageUsername) ?? ""
        self.replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        self.isUnread = try container.decodeIfPresent(Bool.self, forKey: .isUnread) ?? false
        self.isStarred = try container.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
        self.canReply = try container.decodeIfPresent(Bool.self, forKey: .canReply) ?? false
        self.participants = try container.decodeIfPresent([ConversationParticipantDTO].self, forKey: .participants) ?? []
        self.preview = try container.decodeIfPresent(String.self, forKey: .preview) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case title
        case starterUsername
        case lastMessageDate
        case lastMessageUsername
        case replyCount
        case isUnread
        case isStarred
        case canReply
        case participants
        case preview
    }
}

public struct ConversationsPageDTO: Decodable, Equatable, Sendable {
    public let items: [ConversationDTO]
    public let currentPage: Int
    public let lastPage: Int
    public let total: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decodeIfPresent([ConversationDTO].self, forKey: .conversations)
            ?? container.decodeIfPresent([ConversationDTO].self, forKey: .items)
            ?? []
        let pagination = try container.decodeIfPresent(DirectoryPaginationDTO.self, forKey: .pagination)
        self.currentPage = pagination?.page ?? 1
        self.lastPage = pagination?.pages ?? 1
        self.total = pagination?.total ?? items.count
    }

    private enum CodingKeys: String, CodingKey {
        case conversations
        case items
        case pagination
    }
}

public struct ConversationDetailDTO: Decodable, Equatable, Sendable {
    public let conversation: ConversationDTO
    public let messages: [ConversationMessageDTO]
}

public struct ConversationReplyDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let conversation: ConversationDTO
    public let message: ConversationMessageDTO
}

public struct ConversationCreateDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let conversation: ConversationDTO
    public let messages: [ConversationMessageDTO]
}

public struct MemberDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let username: String
    public let userTitle: String
    public let messageCount: Int
    public let reactionScore: Int
    public let registerDate: Int
    public let lastActivity: Int
    public let avatarUrl: String
    public let isStaff: Bool
    public let isFollowed: Bool
    public let canFollow: Bool
    public let roleLabel: String
    public let showVerifiedBadge: Bool
    public let about: String
    public let location: String
    public let website: String
    public let canConverse: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.userId])
        self.username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.userTitle = try container.decodeIfPresent(String.self, forKey: .userTitle) ?? ""
        self.messageCount = try container.decodeIfPresent(Int.self, forKey: .messageCount) ?? 0
        self.reactionScore = try container.decodeIfPresent(Int.self, forKey: .reactionScore) ?? 0
        self.registerDate = try container.decodeIfPresent(Int.self, forKey: .registerDate) ?? 0
        self.lastActivity = try container.decodeIfPresent(Int.self, forKey: .lastActivity) ?? 0
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl) ?? ""
        self.isStaff = try container.decodeIfPresent(Bool.self, forKey: .isStaff) ?? false
        self.isFollowed = try container.decodeIfPresent(Bool.self, forKey: .isFollowed) ?? false
        self.canFollow = try container.decodeIfPresent(Bool.self, forKey: .canFollow) ?? false
        self.roleLabel = try container.decodeIfPresent(String.self, forKey: .roleLabel) ?? ""
        self.showVerifiedBadge = try container.decodeIfPresent(Bool.self, forKey: .showVerifiedBadge) ?? false
        self.about = try container.decodeIfPresent(String.self, forKey: .about) ?? ""
        self.location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        self.website = try container.decodeIfPresent(String.self, forKey: .website) ?? ""
        self.canConverse = try container.decodeIfPresent(Bool.self, forKey: .canConverse) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case username
        case userTitle
        case messageCount
        case reactionScore
        case registerDate
        case lastActivity
        case avatarUrl
        case isStaff
        case isFollowed
        case canFollow
        case roleLabel
        case showVerifiedBadge
        case about
        case location
        case website
        case canConverse
    }
}

public struct MembersPageDTO: Decodable, Equatable, Sendable {
    public let members: [MemberDTO]
    public let currentPage: Int
    public let lastPage: Int
    public let total: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.members = try container.decodeIfPresent([MemberDTO].self, forKey: .members)
            ?? container.decodeIfPresent([MemberDTO].self, forKey: .items)
            ?? []
        let pagination = try container.decodeIfPresent(DirectoryPaginationDTO.self, forKey: .pagination)
        self.currentPage = pagination?.page ?? 1
        self.lastPage = pagination?.pages ?? 1
        self.total = pagination?.total ?? members.count
    }

    private enum CodingKeys: String, CodingKey {
        case members
        case items
        case pagination
    }
}

public struct MemberEnvelopeDTO: Decodable, Equatable, Sendable {
    public let member: MemberDTO

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.member = try container.decodeIfPresent(MemberDTO.self, forKey: .member)
            ?? container.decode(MemberDTO.self, forKey: .profile)
    }

    private enum CodingKeys: String, CodingKey {
        case member
        case profile
    }
}

public struct MemberFollowDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let followed: Bool
    public let member: MemberDTO
}

public struct BookDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let publisher: String
    public let isbn: String
    public let category: String
    public let language: String
    public let publishYear: String
    public let description: String
    public let coverUrl: String
    public let pdfUrl: String
    public let pageCount: Int
    public let isPremiumOnly: Bool
    public let viewCount: Int?
    public let reactionScore: Int?
    public let rating: Double?
}

public struct BookCommentDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let bookId: String
    public let username: String
    public let message: String
    public let imageUrls: [String]
    public let rating: Int
    public let createdAt: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.postId])
        self.bookId = try container.decodeFlexibleStringIfPresent(forKey: .bookId) ?? ""
        self.username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        self.rating = try container.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        self.createdAt = try container.decodeIfPresent(Int.self, forKey: .createdAt)
            ?? container.decodeIfPresent(Int.self, forKey: .timestamp)
            ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case postId
        case bookId
        case username
        case message
        case imageUrls
        case rating
        case createdAt
        case timestamp
    }
}

public struct BookCommentsPageDTO: Decodable, Equatable, Sendable {
    public let comments: [BookCommentDTO]
    public let currentPage: Int
    public let lastPage: Int
    public let total: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.comments = try container.decodeIfPresent([BookCommentDTO].self, forKey: .comments)
            ?? container.decodeIfPresent([BookCommentDTO].self, forKey: .items)
            ?? []
        let pagination = try container.decodeIfPresent(DirectoryPaginationDTO.self, forKey: .pagination)
        self.currentPage = pagination?.page ?? 1
        self.lastPage = pagination?.pages ?? 1
        self.total = pagination?.total ?? comments.count
    }

    private enum CodingKeys: String, CodingKey {
        case comments
        case items
        case pagination
    }
}

public struct BookCommentCreateDTO: Decodable, Equatable, Sendable {
    public let comment: BookCommentDTO?
    public let success: Bool
}

public struct BooksPageDTO: Decodable, Equatable, Sendable {
    public let books: [BookDTO]
    public let currentPage: Int
    public let lastPage: Int
    public let totalBooks: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.books = try container.decodeIfPresent([BookDTO].self, forKey: .books)
            ?? container.decodeIfPresent([BookDTO].self, forKey: .items)
            ?? []

        let pagination = try container.decodeIfPresent(BooksPaginationDTO.self, forKey: .pagination)
        self.currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage)
            ?? pagination?.page
            ?? 1
        self.lastPage = try container.decodeIfPresent(Int.self, forKey: .lastPage)
            ?? pagination?.pages
            ?? 1
        self.totalBooks = try container.decodeIfPresent(Int.self, forKey: .totalBooks)
            ?? container.decodeIfPresent(Int.self, forKey: .total)
            ?? pagination?.total
            ?? self.books.count
    }

    private enum CodingKeys: String, CodingKey {
        case books
        case items
        case currentPage
        case lastPage
        case totalBooks
        case total
        case pagination
    }
}

private struct BooksPaginationDTO: Decodable, Equatable, Sendable {
    let page: Int?
    let pages: Int?
    let total: Int?
}

public struct LibraryItemDTO: Decodable, Equatable, Sendable {
    public let bookId: String
    public let shelfState: String
    public let progressPercent: Int
    public let lastReadPage: Int
    public let isDownloaded: Bool
    public let isFavorite: Bool
    public let title: String
    public let author: String
    public let coverUrl: String
    public let pageCount: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bookId = try container.decodeFlexibleString(forKey: .bookId, fallbackKeys: [.id, .threadId])
        self.shelfState = try container.decodeIfPresent(String.self, forKey: .shelfState) ?? ""
        self.progressPercent = try container.decodeIfPresent(Int.self, forKey: .progressPercent) ?? 0
        self.lastReadPage = try container.decodeIfPresent(Int.self, forKey: .lastReadPage) ?? 0
        self.isDownloaded = try container.decodeIfPresent(Bool.self, forKey: .isDownloaded) ?? false
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        self.coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl) ?? ""
        self.pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case bookId
        case threadId
        case shelfState
        case progressPercent
        case lastReadPage
        case isDownloaded
        case isFavorite
        case title
        case author
        case coverUrl
        case pageCount
    }
}

public struct ReaderAccessDTO: Decodable, Equatable, Sendable {
    public let userTier: String
    public let canReadOnline: Bool
    public let canDownload: Bool
    public let denialCode: String?
    public let denialMessage: String?
    public let dailyRead: DailyQuotaDTO?
    public let dailyDownload: DailyQuotaDTO?
}

public struct DailyQuotaDTO: Decodable, Equatable, Sendable {
    public let limit: Int
    public let used: Int
    public let remaining: Int
    public let isUnlimited: Bool
    public let isAllowed: Bool
    public let usagePercent: Int?
}

public struct ReaderSessionDTO: Decodable, Equatable, Sendable {
    public let token: String
    public let sourceUrl: String
    public let fileType: String
}

public struct AuthResponseDTO: Decodable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let user: UserProfileDTO
}

public struct EmailChangeResponseDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let email: String
    public let confirmationRequired: Bool
}

public struct UserProfileDTO: Decodable, Equatable, Sendable {
    public let username: String
    public let email: String
    public let isPremium: Bool
    public let premiumPlanName: String
}

public struct ForumDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let url: String
    public let stats: String?
    public let threadCount: Int?
    public let isBookForum: Bool?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.nodeId])
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        self.stats = try container.decodeIfPresent(String.self, forKey: .stats)
        self.threadCount = try container.decodeIfPresent(Int.self, forKey: .threadCount)
        self.isBookForum = try container.decodeIfPresent(Bool.self, forKey: .isBookForum)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case nodeId
        case title
        case description
        case url
        case stats
        case threadCount
        case isBookForum
    }
}

public struct ForumThreadDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let username: String
    public let replyCount: Int
    public let viewCount: Int
    public let postDate: Int
    public let canReply: Bool
    public let isSticky: Bool
    public let discussionType: String?
}

public struct ForumPostDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let threadId: String
    public let username: String
    public let message: String
    public let postDate: Int
    public let canEdit: Bool
    public let canReply: Bool
    public let threadTitle: String?
    public let imageUrls: [String]?
    public let userId: Int?
    public let avatarUrl: String?
    public let isAdmin: Bool?
    public let isModerator: Bool?
    public let isPremium: Bool?
}

public struct ProfileDTO: Decodable, Equatable, Sendable {
    public let id: String
    public let username: String
    public let email: String
    public let title: String?
    public let avatarUrl: String?
    public let messageCount: Int?
    public let reactionScore: Int?
    public let registerDate: Int?
    public let isStaff: Bool?
    public let canEdit: Bool?
    public let about: String?
    public let location: String?
    public let website: String?
    public let activityVisible: Bool?
}

public struct NotificationDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let title: String
    public let message: String
    public let actorUsername: String?
    public let targetUrl: String?
    public let appRoute: String?
    public let eventDate: Int?
    public let isRead: Bool?
    public let isViewed: Bool?
}

public struct NotificationCountsDTO: Decodable, Equatable, Sendable {
    public let unread: Int
    public let unviewed: Int?
    public let conversationsUnread: Int?
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        return nil
    }

    func decodeFlexibleString(forKey key: Key, fallbackKeys: [Key] = []) throws -> String {
        for candidate in [key] + fallbackKeys {
            if let value = try? decodeIfPresent(String.self, forKey: candidate) {
                return value
            }
            if let intValue = try? decodeIfPresent(Int.self, forKey: candidate) {
                return String(intValue)
            }
        }
        return ""
    }
}
