import Foundation

// MARK: - Kullanıcı rozeti

public struct UserRoleDTO: Decodable, Equatable, Sendable {
    public let roleLabel: String
    public let roleType: String
    public let showVerifiedBadge: Bool
    public let isAdmin: Bool
    public let isModerator: Bool
    public let isPremium: Bool

    public init(
        roleLabel: String = "",
        roleType: String = "member",
        showVerifiedBadge: Bool = false,
        isAdmin: Bool = false,
        isModerator: Bool = false,
        isPremium: Bool = false
    ) {
        self.roleLabel = roleLabel
        self.roleType = roleType
        self.showVerifiedBadge = showVerifiedBadge
        self.isAdmin = isAdmin
        self.isModerator = isModerator
        self.isPremium = isPremium
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.roleLabel = try container.decodeIfPresent(String.self, forKey: .roleLabel) ?? ""
        self.roleType = try container.decodeIfPresent(String.self, forKey: .roleType) ?? "member"
        self.showVerifiedBadge = container.decodeFlexibleBool(forKey: .showVerifiedBadge)
        self.isAdmin = container.decodeFlexibleBool(forKey: .isAdmin)
        self.isModerator = container.decodeFlexibleBool(forKey: .isModerator)
        self.isPremium = container.decodeFlexibleBool(forKey: .isPremium)
    }

    private enum CodingKeys: String, CodingKey {
        case roleLabel
        case roleType
        case showVerifiedBadge
        case isAdmin
        case isModerator
        case isPremium
    }
}

// MARK: - Abonelik ve günlük kotalar

public struct SubscriptionDTO: Decodable, Equatable, Sendable {
    public let isPremium: Bool
    public let planName: String
    public let userTier: String
    public let expirationTime: Int
    public let remainingDays: Int
    public let dailyRead: DailyQuotaDTO?
    public let dailyDownload: DailyQuotaDTO?

    public init(
        isPremium: Bool = false,
        planName: String = "",
        userTier: String = "member",
        expirationTime: Int = 0,
        remainingDays: Int = 0,
        dailyRead: DailyQuotaDTO? = nil,
        dailyDownload: DailyQuotaDTO? = nil
    ) {
        self.isPremium = isPremium
        self.planName = planName
        self.userTier = userTier
        self.expirationTime = expirationTime
        self.remainingDays = remainingDays
        self.dailyRead = dailyRead
        self.dailyDownload = dailyDownload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isPremium = container.decodeFlexibleBool(forKey: .isPremium)
        self.planName = try container.decodeIfPresent(String.self, forKey: .planName) ?? ""
        self.userTier = try container.decodeIfPresent(String.self, forKey: .userTier) ?? "member"
        self.expirationTime = container.decodeFlexibleInt(forKey: .expirationTime)
        self.remainingDays = container.decodeFlexibleInt(forKey: .remainingDays)
        self.dailyRead = try container.decodeIfPresent(DailyQuotaDTO.self, forKey: .dailyRead)
        self.dailyDownload = try container.decodeIfPresent(DailyQuotaDTO.self, forKey: .dailyDownload)
    }

    public var isAdminTier: Bool { userTier == "admin" }

    private enum CodingKeys: String, CodingKey {
        case isPremium
        case planName
        case userTier
        case expirationTime
        case remainingDays
        case dailyRead
        case dailyDownload
    }
}

// MARK: - Okuma istatistikleri

public struct ReadingStatsDTO: Decodable, Equatable, Sendable {
    public let dailyGoalMinutes: Int
    public let totalSeconds: Int
    public let totalPages: Int
    public let streakCount: Int
    public let todaySeconds: Int
    public let todayPages: Int
    public let goalCompleted: Bool
    public let goalProgressPercent: Int

    public init(
        dailyGoalMinutes: Int = 45,
        totalSeconds: Int = 0,
        totalPages: Int = 0,
        streakCount: Int = 0,
        todaySeconds: Int = 0,
        todayPages: Int = 0,
        goalCompleted: Bool = false,
        goalProgressPercent: Int = 0
    ) {
        self.dailyGoalMinutes = dailyGoalMinutes
        self.totalSeconds = totalSeconds
        self.totalPages = totalPages
        self.streakCount = streakCount
        self.todaySeconds = todaySeconds
        self.todayPages = todayPages
        self.goalCompleted = goalCompleted
        self.goalProgressPercent = goalProgressPercent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let goal = container.decodeFlexibleInt(forKey: .dailyGoalMinutes, default: 45)
        self.dailyGoalMinutes = max(goal, 1)
        self.totalSeconds = container.decodeFlexibleInt(forKey: .totalSeconds)
        self.totalPages = container.decodeFlexibleInt(forKey: .totalPages)
        self.streakCount = container.decodeFlexibleInt(forKey: .streakCount)
        self.todaySeconds = container.decodeFlexibleInt(forKey: .todaySeconds)
        self.todayPages = container.decodeFlexibleInt(forKey: .todayPages)
        self.goalCompleted = container.decodeFlexibleBool(forKey: .goalCompleted)
        let percent = container.decodeFlexibleInt(forKey: .goalProgressPercent, default: -1)
        if percent >= 0 {
            self.goalProgressPercent = min(percent, 100)
        } else {
            let target = max(self.dailyGoalMinutes * 60, 1)
            self.goalProgressPercent = min(Int((Double(self.todaySeconds) / Double(target)) * 100), 100)
        }
    }

    public var todayMinutes: Int { todaySeconds / 60 }
    public var totalMinutes: Int { totalSeconds / 60 }
    public var remainingMinutes: Int { max(dailyGoalMinutes - todayMinutes, 0) }

    private enum CodingKeys: String, CodingKey {
        case dailyGoalMinutes
        case totalSeconds
        case totalPages
        case streakCount
        case todaySeconds
        case todayPages
        case goalCompleted
        case goalProgressPercent
    }
}

public struct ProfileMediaDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let avatarUrl: String?
    public let bannerUrl: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = container.decodeFlexibleBool(forKey: .success, default: true)
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        self.bannerUrl = try container.decodeIfPresent(String.self, forKey: .bannerUrl)
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case avatarUrl
        case bannerUrl
    }
}

// MARK: - Kitap Gündemi

public struct BookAgendaActorDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let username: String
    public let avatarUrl: String?
    public let isVerified: Bool

    public init(id: String, username: String, avatarUrl: String? = nil, isVerified: Bool = false) {
        self.id = id
        self.username = username
        self.avatarUrl = avatarUrl
        self.isVerified = isVerified
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.userId])
        self.username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        self.isVerified = container.decodeFlexibleBool(forKey: .isVerified)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case username
        case avatarUrl
        case isVerified
    }
}

public struct BookAgendaBookDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let coverUrl: String?
    public let appRoute: String?
    public let targetUrl: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.threadId])
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        self.coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        self.appRoute = try container.decodeIfPresent(String.self, forKey: .appRoute)
        self.targetUrl = try container.decodeIfPresent(String.self, forKey: .targetUrl)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case threadId
        case title
        case author
        case coverUrl
        case appRoute
        case targetUrl
    }
}

public struct BookAgendaAttachmentDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let url: String
    public let thumbnailUrl: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.attachmentId])
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
            ?? container.decodeFlexibleStringIfPresent(forKey: .imageUrl)
            ?? ""
        self.thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case attachmentId
        case url
        case imageUrl
        case thumbnailUrl
    }
}

public struct BookAgendaViewerDTO: Decodable, Equatable, Sendable {
    public let canReact: Bool
    public let canComment: Bool
    public let canEdit: Bool
    public let canDelete: Bool
    public let reacted: Bool
    public let bookmarked: Bool
    public let reposted: Bool
    public let followingActor: Bool

    public init(
        canReact: Bool = false,
        canComment: Bool = false,
        canEdit: Bool = false,
        canDelete: Bool = false,
        reacted: Bool = false,
        bookmarked: Bool = false,
        reposted: Bool = false,
        followingActor: Bool = false
    ) {
        self.canReact = canReact
        self.canComment = canComment
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.reacted = reacted
        self.bookmarked = bookmarked
        self.reposted = reposted
        self.followingActor = followingActor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canReact = container.decodeFlexibleBool(forKey: .canReact)
        self.canComment = container.decodeFlexibleBool(forKey: .canComment)
        self.canEdit = container.decodeFlexibleBool(forKey: .canEdit)
        self.canDelete = container.decodeFlexibleBool(forKey: .canDelete)
        self.reacted = container.decodeFlexibleBool(forKey: .reacted)
        self.bookmarked = container.decodeFlexibleBool(forKey: .bookmarked)
        self.reposted = container.decodeFlexibleBool(forKey: .reposted)
        self.followingActor = container.decodeFlexibleBool(forKey: .followingActor)
    }

    private enum CodingKeys: String, CodingKey {
        case canReact
        case canComment
        case canEdit
        case canDelete
        case reacted
        case bookmarked
        case reposted
        case followingActor
    }
}

public struct BookAgendaQuotedPostDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let username: String
    public let message: String
    public let bookTitle: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.postId])
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.bookTitle = try container.decodeIfPresent(String.self, forKey: .bookTitle)
        if let username = try container.decodeIfPresent(String.self, forKey: .username) {
            self.username = username
        } else if let actor = try container.decodeIfPresent(BookAgendaActorDTO.self, forKey: .actor) {
            self.username = actor.username
        } else {
            self.username = ""
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case postId
        case username
        case actor
        case message
        case bookTitle
    }
}

public struct BookAgendaPostDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let message: String
    public let createdAt: Int
    public let editedAt: Int
    public let visibility: String
    public let isPinned: Bool
    public let isFeatured: Bool
    public let isSensitive: Bool
    public let reviewTitle: String
    public let rating: Int
    public let pageNumber: Int
    public let progressCurrent: Int
    public let progressTotal: Int
    public let progressPercent: Int
    public let commentCount: Int
    public let reactionScore: Int
    public let repostCount: Int
    public let bookmarkCount: Int
    public let viewCount: Int
    public let actor: BookAgendaActorDTO
    public let book: BookAgendaBookDTO?
    public let attachments: [BookAgendaAttachmentDTO]
    public let quotedPost: BookAgendaQuotedPostDTO?
    public let viewer: BookAgendaViewerDTO
    public let appRoute: String?
    public let targetUrl: String?
    public let comments: [BookAgendaCommentDTO]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.postId])
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "standard"
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.createdAt = container.decodeFlexibleInt(forKey: .createdAt)
        self.editedAt = container.decodeFlexibleInt(forKey: .editedAt)
        self.visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? "public"
        self.isPinned = container.decodeFlexibleBool(forKey: .isPinned)
        self.isFeatured = container.decodeFlexibleBool(forKey: .isFeatured)
        self.isSensitive = container.decodeFlexibleBool(forKey: .isSensitive)
        self.reviewTitle = try container.decodeIfPresent(String.self, forKey: .reviewTitle) ?? ""
        self.rating = container.decodeFlexibleInt(forKey: .rating)
        self.pageNumber = container.decodeFlexibleInt(forKey: .pageNumber)
        self.progressCurrent = container.decodeFlexibleInt(forKey: .progressCurrent)
        self.progressTotal = container.decodeFlexibleInt(forKey: .progressTotal)
        self.progressPercent = container.decodeFlexibleInt(forKey: .progressPercent)
        self.commentCount = container.decodeFlexibleInt(forKey: .commentCount)
        self.reactionScore = container.decodeFlexibleInt(forKey: .reactionScore)
        self.repostCount = container.decodeFlexibleInt(forKey: .repostCount)
        self.bookmarkCount = container.decodeFlexibleInt(forKey: .bookmarkCount)
        self.viewCount = container.decodeFlexibleInt(forKey: .viewCount)
        self.actor = try container.decodeIfPresent(BookAgendaActorDTO.self, forKey: .actor)
            ?? BookAgendaActorDTO(id: "", username: "")
        self.book = try container.decodeIfPresent(BookAgendaBookDTO.self, forKey: .book)
        self.attachments = try container.decodeIfPresent([BookAgendaAttachmentDTO].self, forKey: .attachments) ?? []
        self.quotedPost = try container.decodeIfPresent(BookAgendaQuotedPostDTO.self, forKey: .quotedPost)
        self.viewer = try container.decodeIfPresent(BookAgendaViewerDTO.self, forKey: .viewer) ?? BookAgendaViewerDTO()
        self.appRoute = try container.decodeIfPresent(String.self, forKey: .appRoute)
        self.targetUrl = try container.decodeIfPresent(String.self, forKey: .targetUrl)
        self.comments = try container.decodeIfPresent([BookAgendaCommentDTO].self, forKey: .comments) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case postId
        case type
        case message
        case createdAt
        case editedAt
        case visibility
        case isPinned
        case isFeatured
        case isSensitive
        case reviewTitle
        case rating
        case pageNumber
        case progressCurrent
        case progressTotal
        case progressPercent
        case commentCount
        case reactionScore
        case repostCount
        case bookmarkCount
        case viewCount
        case actor
        case book
        case attachments
        case quotedPost
        case viewer
        case appRoute
        case targetUrl
        case comments
    }
}

public struct BookAgendaCommentDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let message: String
    public let createdAt: Int
    public let editedAt: Int
    public let reactionScore: Int
    public let actor: BookAgendaActorDTO
    public let viewer: BookAgendaViewerDTO

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.commentId])
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.createdAt = container.decodeFlexibleInt(forKey: .createdAt)
        self.editedAt = container.decodeFlexibleInt(forKey: .editedAt)
        self.reactionScore = container.decodeFlexibleInt(forKey: .reactionScore)
        self.actor = try container.decodeIfPresent(BookAgendaActorDTO.self, forKey: .actor)
            ?? BookAgendaActorDTO(id: "", username: "")
        self.viewer = try container.decodeIfPresent(BookAgendaViewerDTO.self, forKey: .viewer) ?? BookAgendaViewerDTO()
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case commentId
        case message
        case createdAt
        case editedAt
        case reactionScore
        case actor
        case viewer
    }
}

public struct BookAgendaPageDTO: Decodable, Equatable, Sendable {
    public let items: [BookAgendaPostDTO]
    public let tab: String
    public let filter: String
    public let page: Int
    public let hasMore: Bool
    public let canCreate: Bool
    public let authenticated: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decodeIfPresent([BookAgendaPostDTO].self, forKey: .items)
            ?? container.decodeIfPresent([BookAgendaPostDTO].self, forKey: .posts)
            ?? []
        self.tab = try container.decodeIfPresent(String.self, forKey: .tab) ?? "agenda"
        self.filter = try container.decodeIfPresent(String.self, forKey: .filter) ?? ""
        let pagination = try container.decodeIfPresent(BookAgendaPaginationDTO.self, forKey: .pagination)
        self.page = pagination?.page ?? 1
        self.hasMore = pagination?.hasMore ?? false
        let capabilities = try container.decodeIfPresent(BookAgendaCapabilitiesDTO.self, forKey: .capabilities)
        self.canCreate = capabilities?.canCreate ?? false
        self.authenticated = capabilities?.authenticated ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case posts
        case tab
        case filter
        case pagination
        case capabilities
    }
}

private struct BookAgendaPaginationDTO: Decodable, Equatable, Sendable {
    let page: Int
    let hasMore: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.page = container.decodeFlexibleInt(forKey: .page, default: 1)
        self.hasMore = container.decodeFlexibleBool(forKey: .hasMore)
    }

    private enum CodingKeys: String, CodingKey {
        case page
        case hasMore
    }
}

private struct BookAgendaCapabilitiesDTO: Decodable, Equatable, Sendable {
    let authenticated: Bool
    let canCreate: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.authenticated = container.decodeFlexibleBool(forKey: .authenticated)
        self.canCreate = container.decodeFlexibleBool(forKey: .canCreate)
    }

    private enum CodingKeys: String, CodingKey {
        case authenticated
        case canCreate
    }
}

public struct BookAgendaPostEnvelopeDTO: Decodable, Equatable, Sendable {
    public let post: BookAgendaPostDTO
}

public struct BookAgendaCommentEnvelopeDTO: Decodable, Equatable, Sendable {
    public let comment: BookAgendaCommentDTO
}

public struct BookAgendaCommentsPageDTO: Decodable, Equatable, Sendable {
    public let comments: [BookAgendaCommentDTO]

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let direct = try? container.decode([BookAgendaCommentDTO].self) {
            self.comments = direct
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.comments = try keyed.decodeIfPresent([BookAgendaCommentDTO].self, forKey: .comments)
            ?? keyed.decodeIfPresent([BookAgendaCommentDTO].self, forKey: .items)
            ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case comments
        case items
    }
}

public struct BookAgendaActionDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let reacted: Bool
    public let bookmarked: Bool
    public let reposted: Bool
    public let reactionScore: Int?
    public let repostCount: Int?
    public let bookmarkCount: Int?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = container.decodeFlexibleBool(forKey: .success, default: true)
        self.reacted = container.decodeFlexibleBool(forKey: .reacted)
        self.bookmarked = container.decodeFlexibleBool(forKey: .bookmarked)
        self.reposted = container.decodeFlexibleBool(forKey: .reposted)
        self.reactionScore = try container.decodeIfPresent(Int.self, forKey: .reactionScore)
        self.repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount)
        self.bookmarkCount = try container.decodeIfPresent(Int.self, forKey: .bookmarkCount)
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case reacted
        case bookmarked
        case reposted
        case reactionScore
        case repostCount
        case bookmarkCount
    }
}

public struct BookAgendaFollowDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let following: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = container.decodeFlexibleBool(forKey: .success, default: true)
        self.following = container.decodeFlexibleBool(forKey: .following)
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case following
    }
}

// MARK: - Canlı Aktivite

public struct LiveActivityActorDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let username: String
    public let avatarUrl: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.userId])
        self.username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case username
        case avatarUrl
    }
}

public struct LiveActivityBookDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let coverUrl: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.threadId])
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        self.coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case threadId
        case title
        case author
        case coverUrl
    }
}

public struct LiveActivityItemDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let message: String
    public let eventDate: Int
    public let actor: LiveActivityActorDTO?
    public let book: LiveActivityBookDTO?
    public let appRoute: String?
    public let targetUrl: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.eventDate = container.decodeFlexibleInt(forKey: .eventDate)
        self.actor = try container.decodeIfPresent(LiveActivityActorDTO.self, forKey: .actor)
        self.book = try container.decodeIfPresent(LiveActivityBookDTO.self, forKey: .book)
        self.appRoute = try container.decodeIfPresent(String.self, forKey: .appRoute)
        self.targetUrl = try container.decodeIfPresent(String.self, forKey: .targetUrl)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case message
        case eventDate
        case actor
        case book
        case appRoute
        case targetUrl
    }
}

public struct LiveActivityPageDTO: Decodable, Equatable, Sendable {
    public let items: [LiveActivityItemDTO]
    public let nextBefore: Int?
    public let hasMore: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decodeIfPresent([LiveActivityItemDTO].self, forKey: .items) ?? []
        let pagination = try container.decodeIfPresent(LiveActivityPaginationDTO.self, forKey: .pagination)
        self.nextBefore = pagination?.nextBefore
        self.hasMore = pagination?.hasMore ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case pagination
    }
}

private struct LiveActivityPaginationDTO: Decodable, Equatable, Sendable {
    let nextBefore: Int?
    let hasMore: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let next = container.decodeFlexibleInt(forKey: .nextBefore)
        self.nextBefore = next > 0 ? next : nil
        self.hasMore = container.decodeFlexibleBool(forKey: .hasMore)
    }

    private enum CodingKeys: String, CodingKey {
        case nextBefore
        case hasMore
    }
}

// MARK: - Okur Sohbeti

public struct ChatRoomDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let userCount: Int
    public let isReadOnly: Bool
    public let isLocked: Bool
    public let isPrivate: Bool
    public let isJoined: Bool
    public let canSend: Bool
    public let appRoute: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.roomId])
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.userCount = container.decodeFlexibleInt(forKey: .userCount)
        self.isReadOnly = container.decodeFlexibleBool(forKey: .isReadOnly)
        self.isLocked = container.decodeFlexibleBool(forKey: .isLocked)
        self.isPrivate = container.decodeFlexibleBool(forKey: .isPrivate)
        self.isJoined = container.decodeFlexibleBool(forKey: .isJoined)
        self.canSend = container.decodeFlexibleBool(forKey: .canSend)
        self.appRoute = try container.decodeIfPresent(String.self, forKey: .appRoute)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case roomId
        case name
        case description
        case userCount
        case isReadOnly
        case isLocked
        case isPrivate
        case isJoined
        case canSend
        case appRoute
    }
}

public struct ChatCapabilitiesDTO: Decodable, Equatable, Sendable {
    public let authenticated: Bool
    public let canUse: Bool
    public let pushAvailable: Bool

    public init(authenticated: Bool = false, canUse: Bool = false, pushAvailable: Bool = false) {
        self.authenticated = authenticated
        self.canUse = canUse
        self.pushAvailable = pushAvailable
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.authenticated = container.decodeFlexibleBool(forKey: .authenticated)
        self.canUse = container.decodeFlexibleBool(forKey: .canUse)
        self.pushAvailable = container.decodeFlexibleBool(forKey: .pushAvailable)
    }

    private enum CodingKeys: String, CodingKey {
        case authenticated
        case canUse
        case pushAvailable
    }
}

public struct ChatRoomsDTO: Decodable, Equatable, Sendable {
    public let rooms: [ChatRoomDTO]
    public let capabilities: ChatCapabilitiesDTO

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rooms = try container.decodeIfPresent([ChatRoomDTO].self, forKey: .items)
            ?? container.decodeIfPresent([ChatRoomDTO].self, forKey: .rooms)
            ?? []
        self.capabilities = try container.decodeIfPresent(ChatCapabilitiesDTO.self, forKey: .capabilities)
            ?? ChatCapabilitiesDTO()
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case rooms
        case capabilities
    }
}

public struct ChatMessageDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let roomId: String
    public let userId: String
    public let username: String
    public let message: String
    public let messageDate: Int
    public let avatarUrl: String?
    public let isMine: Bool
    public let isBot: Bool
    public let isAnnouncement: Bool
    public let isEdited: Bool
    public let isAdmin: Bool
    public let isModerator: Bool
    public let isStaff: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id, fallbackKeys: [.messageId])
        self.roomId = try container.decodeFlexibleString(forKey: .roomId)
        self.userId = try container.decodeFlexibleString(forKey: .userId)
        self.username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.messageDate = container.decodeFlexibleInt(forKey: .messageDate)
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        self.isMine = container.decodeFlexibleBool(forKey: .isMine)
        self.isBot = container.decodeFlexibleBool(forKey: .isBot)
        self.isAnnouncement = container.decodeFlexibleBool(forKey: .isAnnouncement)
        self.isEdited = container.decodeFlexibleBool(forKey: .isEdited)
        self.isAdmin = container.decodeFlexibleBool(forKey: .isAdmin)
        self.isModerator = container.decodeFlexibleBool(forKey: .isModerator)
        self.isStaff = container.decodeFlexibleBool(forKey: .isStaff)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case messageId
        case roomId
        case userId
        case username
        case message
        case messageDate
        case avatarUrl
        case isMine
        case isBot
        case isAnnouncement
        case isEdited
        case isAdmin
        case isModerator
        case isStaff
    }
}

public struct ChatMessagesPageDTO: Decodable, Equatable, Sendable {
    public let room: ChatRoomDTO?
    public let messages: [ChatMessageDTO]
    public let oldestId: String?
    public let newestId: String?
    public let hasMore: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.room = try container.decodeIfPresent(ChatRoomDTO.self, forKey: .room)
        self.messages = try container.decodeIfPresent([ChatMessageDTO].self, forKey: .items)
            ?? container.decodeIfPresent([ChatMessageDTO].self, forKey: .messages)
            ?? []
        let pagination = try container.decodeIfPresent(ChatPaginationDTO.self, forKey: .pagination)
        self.oldestId = pagination?.oldestId
        self.newestId = pagination?.newestId
        self.hasMore = pagination?.hasMore ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case room
        case items
        case messages
        case pagination
    }
}

private struct ChatPaginationDTO: Decodable, Equatable, Sendable {
    let oldestId: String?
    let newestId: String?
    let hasMore: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let oldest = container.decodeFlexibleInt(forKey: .oldestId)
        let newest = container.decodeFlexibleInt(forKey: .newestId)
        self.oldestId = oldest > 0 ? String(oldest) : nil
        self.newestId = newest > 0 ? String(newest) : nil
        self.hasMore = container.decodeFlexibleBool(forKey: .hasMore)
    }

    private enum CodingKeys: String, CodingKey {
        case oldestId
        case newestId
        case hasMore
    }
}

public struct ChatMessageEnvelopeDTO: Decodable, Equatable, Sendable {
    public let message: ChatMessageDTO

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let direct = try? container.decode(ChatMessageDTO.self) {
            self.message = direct
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try keyed.decode(ChatMessageDTO.self, forKey: .message)
    }

    private enum CodingKeys: String, CodingKey {
        case message
    }
}
