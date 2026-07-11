import Foundation

public struct SiteRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func stats() async throws -> SiteStatsDTO {
        try await apiClient.request(.siteStats, as: SiteStatsDTO.self)
    }
}

public struct DirectoryRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func items(kind: DirectoryKind, page: Int = 1, query: String? = nil) async throws -> DirectoryPageDTO {
        try await apiClient.request(.directory(kind: kind, page: page, query: query), as: DirectoryPageDTO.self)
    }

    public func books(kind: DirectoryKind, slug: String, page: Int = 1) async throws -> BooksPageDTO {
        try await apiClient.request(.directoryBooks(kind: kind, slug: slug, page: page), as: BooksPageDTO.self)
    }
}

public struct BookRequestsRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func requests() async throws -> BookRequestsPageDTO {
        try await apiClient.request(.bookRequests, as: BookRequestsPageDTO.self)
    }

    public func create(title: String, author: String, isbn: String) async throws -> BookRequestDTO {
        try await apiClient.request(
            .createBookRequest(title: title, author: author, isbn: isbn),
            as: BookRequestEnvelopeDTO.self
        ).request
    }

    public func toggleVote(id: String) async throws -> BookRequestVoteDTO {
        try await apiClient.request(.voteBookRequest(id: id), as: BookRequestVoteDTO.self)
    }
}

public struct ConversationsRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func conversations(page: Int = 1) async throws -> ConversationsPageDTO {
        try await apiClient.request(.conversations(page: page), as: ConversationsPageDTO.self)
    }

    public func conversation(id: String) async throws -> ConversationDetailDTO {
        try await apiClient.request(.conversation(id: id), as: ConversationDetailDTO.self)
    }

    public func reply(id: String, message: String) async throws -> ConversationReplyDTO {
        try await apiClient.request(.replyToConversation(id: id, message: message), as: ConversationReplyDTO.self)
    }

    public func create(recipient: String, title: String, message: String) async throws -> ConversationCreateDTO {
        try await apiClient.request(
            .createConversation(recipient: recipient, title: title, message: message),
            as: ConversationCreateDTO.self
        )
    }
}

public struct MembersRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func members(page: Int = 1, query: String? = nil, sort: String = "alphabetical") async throws -> MembersPageDTO {
        try await apiClient.request(.members(page: page, query: query, sort: sort), as: MembersPageDTO.self)
    }

    public func member(id: String) async throws -> MemberDTO {
        try await apiClient.request(.member(id: id), as: MemberEnvelopeDTO.self).member
    }

    public func follow(id: String) async throws -> MemberFollowDTO {
        try await apiClient.request(.followMember(id: id), as: MemberFollowDTO.self)
    }

    public func unfollow(id: String) async throws -> MemberFollowDTO {
        try await apiClient.request(.unfollowMember(id: id), as: MemberFollowDTO.self)
    }
}

public protocol BookRepositoryProtocol: Sendable {
    func books(page: Int, query: String?, category: String?, author: String?, publisher: String?, isbn: String?, order: String?, premiumOnly: Bool) async throws -> BooksPageDTO
    func book(id: Int) async throws -> BookDTO
    func bookDetail(id: Int) async throws -> BookEnvelope
    func readerAccess(bookID: Int) async throws -> ReaderAccessDTO
    func createReaderSession(bookID: Int) async throws -> ReaderSessionDTO
    func updateProgress(bookID: Int, page: Int, percent: Double) async throws
    func library() async throws -> LibraryPageDTO
    func updateLibraryItem(bookID: Int, shelfState: String, progressPercent: Int, lastReadPage: Int) async throws
    func comments(bookID: Int, page: Int) async throws -> BookCommentsPageDTO
    func createComment(bookID: Int, message: String, rating: Int) async throws -> BookCommentCreateDTO
}

public struct BookRepository: BookRepositoryProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func books(
        page: Int,
        query: String? = nil,
        category: String? = nil,
        author: String? = nil,
        publisher: String? = nil,
        isbn: String? = nil,
        order: String? = nil,
        premiumOnly: Bool = false
    ) async throws -> BooksPageDTO {
        try await apiClient.request(
            .books(page: page, query: query, category: category, author: author, publisher: publisher, isbn: isbn, order: order, premiumOnly: premiumOnly),
            as: BooksPageDTO.self
        )
    }

    public func book(id: Int) async throws -> BookDTO {
        (try await bookDetail(id: id)).book
    }

    public func bookDetail(id: Int) async throws -> BookEnvelope {
        try await apiClient.request(.book(id: id), as: BookEnvelope.self)
    }

    public func readerAccess(bookID: Int) async throws -> ReaderAccessDTO {
        try await apiClient.request(.readerAccess(bookID: bookID), as: ReaderAccessEnvelope.self).access
    }

    public func createReaderSession(bookID: Int) async throws -> ReaderSessionDTO {
        try await apiClient.request(.readerSession(bookID: bookID), as: ReaderSessionDTO.self)
    }

    public func updateProgress(bookID: Int, page: Int, percent: Double) async throws {
        let _: SuccessResponse = try await apiClient.request(.updateReaderProgress(bookID: bookID, page: page, percent: percent))
    }

    public func library() async throws -> LibraryPageDTO {
        try await apiClient.request(.library, as: LibraryPageDTO.self)
    }

    public func updateLibraryItem(bookID: Int, shelfState: String, progressPercent: Int, lastReadPage: Int) async throws {
        let _: SuccessResponse = try await apiClient.request(
            .updateLibraryItem(
                bookID: bookID,
                shelfState: shelfState,
                progressPercent: progressPercent,
                lastReadPage: lastReadPage
            )
        )
    }

    public func comments(bookID: Int, page: Int = 1) async throws -> BookCommentsPageDTO {
        try await apiClient.request(.bookComments(bookID: bookID, page: page), as: BookCommentsPageDTO.self)
    }

    public func createComment(bookID: Int, message: String, rating: Int) async throws -> BookCommentCreateDTO {
        try await apiClient.request(
            .createBookComment(bookID: bookID, message: message, rating: rating),
            as: BookCommentCreateDTO.self
        )
    }
}

public protocol AuthRepositoryProtocol: Sendable {
    func login(username: String, password: String) async throws -> AuthResponseDTO
    func signInWithApple(identityToken: String, authorizationCode: String, nonce: String) async throws -> AuthResponseDTO
    func register(username: String, email: String, password: String) async throws -> AuthResponseDTO
    func forgotPassword(email: String) async throws
    func logout() async throws
}

public struct AuthRepository: AuthRepositoryProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func login(username: String, password: String) async throws -> AuthResponseDTO {
        try await apiClient.request(.login(username: username, password: password), as: AuthResponseDTO.self)
    }

    public func signInWithApple(identityToken: String, authorizationCode: String, nonce: String) async throws -> AuthResponseDTO {
        try await apiClient.request(.appleAuth(identityToken: identityToken, authorizationCode: authorizationCode, nonce: nonce), as: AuthResponseDTO.self)
    }

    public func register(username: String, email: String, password: String) async throws -> AuthResponseDTO {
        try await apiClient.request(.register(username: username, email: email, password: password), as: AuthResponseDTO.self)
    }

    public func forgotPassword(email: String) async throws {
        let _: SuccessResponse = try await apiClient.request(.forgotPassword(email: email))
    }

    public func logout() async throws {
        let _: SuccessResponse = try await apiClient.request(.logout())
    }
}

public struct AccountRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func requestAccountDeletion(currentPassword: String? = nil, reason: String? = nil) async throws {
        let _: SuccessResponse = try await apiClient.request(.accountDeletion(currentPassword: currentPassword, reason: reason))
    }

    public func termsStatus() async throws -> TermsStatusDTO {
        try await apiClient.request(.termsStatus, as: TermsStatusDTO.self)
    }

    public func acceptTerms(version: String) async throws {
        let _: SuccessResponse = try await apiClient.request(.acceptTerms(version: version))
    }

    public func updateEmail(currentPassword: String, email: String) async throws -> EmailChangeResponseDTO {
        try await apiClient.request(.updateEmail(currentPassword: currentPassword, email: email), as: EmailChangeResponseDTO.self)
    }

    public func updatePassword(currentPassword: String, newPassword: String) async throws -> AuthResponseDTO {
        try await apiClient.request(.updatePassword(currentPassword: currentPassword, newPassword: newPassword), as: AuthResponseDTO.self)
    }
}

public struct ProfileRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func profile() async throws -> ProfileDTO {
        try await apiClient.request(.profile, as: ProfileDTO.self)
    }

    public func updateProfile(about: String, location: String, website: String, activityVisible: Bool) async throws -> ProfileDTO {
        try await apiClient.request(
            .updateProfile(about: about, location: location, website: website, activityVisible: activityVisible),
            as: ProfileDTO.self
        )
    }
}

public struct NotificationsRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func notifications() async throws -> NotificationsPageDTO {
        try await apiClient.request(.notifications, as: NotificationsPageDTO.self)
    }

    public func counts() async throws -> NotificationCountsDTO {
        try await apiClient.request(.notificationCounts, as: NotificationCountsDTO.self)
    }

    public func markRead(id: Int) async throws {
        let _: SuccessResponse = try await apiClient.request(.markNotificationRead(id: id))
    }

    public func markAllRead() async throws {
        let _: SuccessResponse = try await apiClient.request(.markAllNotificationsRead())
    }
}

public struct SafetyRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func reportBookIssue(bookID: Int, type: String, message: String) async throws {
        let _: SuccessResponse = try await apiClient.request(.reportBookIssue(bookID: bookID, type: type, message: message))
    }

    public func reportForumPost(postID: Int, message: String) async throws {
        let _: SuccessResponse = try await apiClient.request(.reportForumPost(postID: postID, message: message))
    }

    public func blockMember(userID: Int) async throws {
        let _: SuccessResponse = try await apiClient.request(.blockMember(userID: userID))
    }

    public func unblockMember(userID: Int) async throws {
        let _: SuccessResponse = try await apiClient.request(.unblockMember(userID: userID))
    }

    public func blockedMembers() async throws -> BlockedMembersPageDTO {
        try await apiClient.request(.blockedMembers, as: BlockedMembersPageDTO.self)
    }
}

public struct PurchaseRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func verifyAppStorePurchase(
        signedTransaction: String,
        productID: String,
        originalTransactionID: String?
    ) async throws -> BillingResponseDTO {
        try await apiClient.request(
            .verifyAppStorePurchase(
                signedTransaction: signedTransaction,
                productID: productID,
                originalTransactionID: originalTransactionID
            ),
            as: BillingResponseDTO.self
        )
    }
}

public struct CommunityRepository: Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func forums() async throws -> ForumsPageDTO {
        try await apiClient.request(.forums, as: ForumsPageDTO.self)
    }

    public func threads(forumID: Int, page: Int = 1) async throws -> ForumThreadsPageDTO {
        try await apiClient.request(.forumThreads(forumID: forumID, page: page), as: ForumThreadsPageDTO.self)
    }

    public func posts(threadID: Int, page: Int = 1) async throws -> ForumPostsPageDTO {
        try await apiClient.request(.threadPosts(threadID: threadID, page: page), as: ForumPostsPageDTO.self)
    }

    public func reply(threadID: Int, message: String) async throws -> ForumPostDTO {
        try await apiClient.request(.replyToThread(threadID: threadID, message: message), as: ForumPostEnvelope.self).post
    }
}

public struct ForumsPageDTO: Decodable, Equatable, Sendable {
    public let forums: [ForumDTO]
}

public struct ForumThreadsPageDTO: Decodable, Equatable, Sendable {
    public let threads: [ForumThreadDTO]
    public let currentPage: Int?
    public let lastPage: Int?
    public let total: Int?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.threads = try container.decodeIfPresent([ForumThreadDTO].self, forKey: .threads)
            ?? container.decodeIfPresent([ForumThreadDTO].self, forKey: .items)
            ?? []
        let pagination = try container.decodeIfPresent(PaginationDTO.self, forKey: .pagination)
        self.currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage) ?? pagination?.currentPage
        self.lastPage = try container.decodeIfPresent(Int.self, forKey: .lastPage) ?? pagination?.pages
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? pagination?.total
    }

    private enum CodingKeys: String, CodingKey {
        case threads
        case items
        case currentPage
        case lastPage
        case total
        case pagination
    }
}

public struct ForumPostsPageDTO: Decodable, Equatable, Sendable {
    public let posts: [ForumPostDTO]
    public let currentPage: Int?
    public let lastPage: Int?
    public let total: Int?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.posts = try container.decodeIfPresent([ForumPostDTO].self, forKey: .posts)
            ?? container.decodeIfPresent([ForumPostDTO].self, forKey: .items)
            ?? []
        let pagination = try container.decodeIfPresent(PaginationDTO.self, forKey: .pagination)
        self.currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage) ?? pagination?.currentPage
        self.lastPage = try container.decodeIfPresent(Int.self, forKey: .lastPage) ?? pagination?.pages
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? pagination?.total
    }

    private enum CodingKeys: String, CodingKey {
        case posts
        case items
        case currentPage
        case lastPage
        case total
        case pagination
    }
}

public struct ForumPostEnvelope: Decodable, Equatable, Sendable {
    public let post: ForumPostDTO
}

private struct PaginationDTO: Decodable, Equatable, Sendable {
    let currentPage: Int?
    let total: Int?
    let pages: Int?

    private enum CodingKeys: String, CodingKey {
        case currentPage
        case page
        case total
        case pages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage)
            ?? container.decodeIfPresent(Int.self, forKey: .page)
        self.total = try container.decodeIfPresent(Int.self, forKey: .total)
        self.pages = try container.decodeIfPresent(Int.self, forKey: .pages)
    }
}

public struct NotificationsPageDTO: Decodable, Equatable, Sendable {
    public let items: [NotificationDTO]
    public let counts: NotificationCountsDTO?
    public let currentPage: Int?
    public let lastPage: Int?
    public let total: Int?
}

public struct TermsStatusDTO: Decodable, Equatable, Sendable {
    public let requiredVersion: String
    public let acceptedVersion: String?
    public let acceptedAt: Int?
    public let requiresAcceptance: Bool
}

public struct BlockedMembersPageDTO: Decodable, Equatable, Sendable {
    public let members: [BlockedMemberDTO]
}

public struct BlockedMemberDTO: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let username: String
    public let avatarUrl: String?
    public let blockedAt: Int?
}

public struct BillingResponseDTO: Decodable, Equatable, Sendable {
    public let success: Bool
    public let isPremium: Bool
    public let expirationTime: Int?
    public let remainingDays: Int?
    public let planName: String?
    public let userTier: String?
}

public protocol EmptyDataDecodable {
    static var emptyValue: Any { get }
}

public struct SuccessResponse: Decodable, Equatable, Sendable, EmptyDataDecodable {
    public let success: Bool
    public let message: String?
    public let requestId: Int?

    public static var emptyValue: Any {
        SuccessResponse(success: true, message: nil, requestId: nil)
    }

    public init(success: Bool = true, message: String? = nil, requestId: Int? = nil) {
        self.success = success
        self.message = message
        self.requestId = requestId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.requestId = try container.decodeIfPresent(Int.self, forKey: .requestId)
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case requestId
    }
}

public struct LibraryPageDTO: Decodable, Equatable, Sendable {
    public let items: [LibraryItemDTO]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let directItems = try? container.decode([LibraryItemDTO].self) {
            self.items = directItems
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try keyed.decodeIfPresent([LibraryItemDTO].self, forKey: .items)
            ?? keyed.decodeIfPresent([LibraryItemDTO].self, forKey: .library)
            ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case library
    }
}

public struct BookEnvelope: Decodable, Equatable, Sendable {
    public let book: BookDTO
    public let similarBooks: [BookDTO]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.book = try container.decode(BookDTO.self, forKey: .book)
        let bookContainer = try container.nestedContainer(keyedBy: BookCodingKeys.self, forKey: .book)
        self.similarBooks = try bookContainer.decodeIfPresent([BookDTO].self, forKey: .similarBooks)
            ?? bookContainer.decodeIfPresent([BookDTO].self, forKey: .similarBooksCamel)
            ?? []
    }

    private enum CodingKeys: String, CodingKey { case book }

    private enum BookCodingKeys: String, CodingKey {
        case similarBooks = "similar_books"
        case similarBooksCamel = "similarBooks"
    }
}

public struct ReaderAccessEnvelope: Decodable, Equatable, Sendable {
    public let access: ReaderAccessDTO
}

public struct EmptyResponse: Decodable, Equatable, Sendable {
    public init() {}
}
