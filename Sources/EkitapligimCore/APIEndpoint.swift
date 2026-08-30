import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public struct APIEndpoint: Sendable, Equatable {
    public let method: HTTPMethod
    public let path: String
    public let queryItems: [URLQueryItem]
    public let body: RequestBody?
    public let requiresAuthentication: Bool

    public init(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: RequestBody? = nil,
        requiresAuthentication: Bool = false
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
        self.requiresAuthentication = requiresAuthentication
    }

    public func url(relativeTo baseURL: URL) throws -> URL {
        let cleanBase = baseURL.absoluteString.hasSuffix("/") ? baseURL : baseURL.appendingPathComponent("")
        var components = URLComponents(url: cleanBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw APIClientError.invalidURL }
        return url
    }
}

public enum RequestBody: Equatable, Sendable {
    case json(Data)
    case form([String: String])
    case multipart(MultipartFile)
}

public struct MultipartFile: Equatable, Sendable {
    public let field: String
    public let fileName: String
    public let mimeType: String
    public let data: Data

    public init(field: String, fileName: String, mimeType: String, data: Data) {
        self.field = field
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }
}

public enum ProfileImageKind: String, Equatable, Sendable, CaseIterable {
    case avatar
    case banner
}

public enum BookAgendaTab: String, Equatable, Sendable, CaseIterable {
    case personal
    case following
    case agenda
}

public enum BookAgendaPostType: String, Equatable, Sendable, CaseIterable {
    case standard
    case book
    case quotation
    case review
    case progress
}

public enum BookAgendaComposerRules: Sendable {
    /// Android AgendaComposerDialog treats blank page fields as 0, so current=5/total empty is invalid.
    public static func isProgressCurrentExceedingTotal(_ current: String, total: String) -> Bool {
        (Int(current) ?? 0) > (Int(total) ?? 0)
    }
}

public enum BookAgendaVisibility: String, Equatable, Sendable, CaseIterable {
    case `public`
    case members
    case followers
    case `private`
}

public enum ReaderSessionPurpose: String, Equatable, Sendable {
    case read
    case download
}

public enum UGCContentType: String, CaseIterable, Equatable, Hashable, Sendable {
    case forumPost = "forum_post"
    case bookComment = "book_comment"
    case agendaPost = "agenda_post"
    case agendaComment = "agenda_comment"
    case chatMessage = "chat_message"
    case conversationMessage = "conversation_message"
    case bookRequest = "book_request"
}

public enum UGCReportReason: String, CaseIterable, Equatable, Hashable, Sendable {
    case spam
    case harassment
    case hate
    case sexual
    case violence
    case privacy
    case copyright
    case other
}

public extension APIEndpoint {
    static let siteStats = APIEndpoint(method: .get, path: "book-stats")

    static func directory(kind: DirectoryKind, page: Int = 1, query: String? = nil) -> APIEndpoint {
        var items = [URLQueryItem(name: "page", value: String(page))]
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        return APIEndpoint(method: .get, path: kind.path, queryItems: items)
    }

    static func directoryBooks(kind: DirectoryKind, slug: String, page: Int = 1) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "\(kind.path)/\(slug)/books",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
        )
    }

    static let bookRequests = APIEndpoint(method: .get, path: "book-requests")

    static func createBookRequest(title: String, author: String, isbn: String) -> APIEndpoint {
        var fields = ["title": title, "author": author]
        if !isbn.isEmpty { fields["isbn"] = isbn }
        return APIEndpoint(
            method: .post,
            path: "book-requests",
            body: .form(fields),
            requiresAuthentication: true
        )
    }

    static func voteBookRequest(id: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "book-requests/\(id)/vote", requiresAuthentication: true)
    }

    static func conversations(page: Int = 1) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "conversations",
            queryItems: [URLQueryItem(name: "page", value: String(page))],
            requiresAuthentication: true
        )
    }

    static func conversation(id: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "conversation-detail/\(id)", requiresAuthentication: true)
    }

    static func replyToConversation(id: String, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "conversation-reply/\(id)",
            body: .form(["message": message]),
            requiresAuthentication: true
        )
    }

    static func createConversation(recipient: String, title: String, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "conversations",
            body: .form(["recipient": recipient, "title": title, "message": message]),
            requiresAuthentication: true
        )
    }

    static func members(page: Int = 1, query: String? = nil, sort: String = "alphabetical") -> APIEndpoint {
        var items = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sort", value: sort)
        ]
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        return APIEndpoint(method: .get, path: "members", queryItems: items)
    }

    static func member(id: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "member-detail/\(id)")
    }

    static func followMember(id: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "member-follow/\(id)", requiresAuthentication: true)
    }

    static func unfollowMember(id: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "member-unfollow/\(id)", requiresAuthentication: true)
    }

    static func books(
        page: Int = 1,
        query: String? = nil,
        category: String? = nil,
        author: String? = nil,
        publisher: String? = nil,
        isbn: String? = nil,
        order: String? = nil,
        premiumOnly: Bool = false
    ) -> APIEndpoint {
        var items = [URLQueryItem(name: "page", value: String(page))]
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        if let category, !category.isEmpty { items.append(URLQueryItem(name: "category", value: category)) }
        if let author, !author.isEmpty { items.append(URLQueryItem(name: "author", value: author)) }
        if let publisher, !publisher.isEmpty { items.append(URLQueryItem(name: "publisher", value: publisher)) }
        if let isbn, !isbn.isEmpty { items.append(URLQueryItem(name: "isbn", value: isbn)) }
        if let order, !order.isEmpty { items.append(URLQueryItem(name: "order", value: order)) }
        if premiumOnly { items.append(URLQueryItem(name: "premium_only", value: "1")) }
        return APIEndpoint(method: .get, path: "books", queryItems: items)
    }

    static func book(id: Int) -> APIEndpoint {
        APIEndpoint(method: .get, path: "book-detail/\(id)")
    }

    static func bookComments(bookID: Int, page: Int = 1) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "books/\(bookID)/comments",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
        )
    }

    static func createBookComment(bookID: Int, message: String, rating: Int) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "books/\(bookID)/comments",
            body: .form(["message": message, "rating": String(rating)]),
            requiresAuthentication: true
        )
    }

    static func readerAccess(bookID: Int) -> APIEndpoint {
        APIEndpoint(method: .get, path: "books/\(bookID)/reader/access", requiresAuthentication: true)
    }

    static func readerSession(bookID: Int, purpose: ReaderSessionPurpose) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "books/\(bookID)/reader/session",
            body: .form(["purpose": purpose.rawValue]),
            requiresAuthentication: true
        )
    }

    static func readerSource(bookID: Int, token: String) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "books/\(bookID)/reader/source",
            queryItems: [URLQueryItem(name: "t", value: token)],
            requiresAuthentication: true
        )
    }

    static func updateReaderProgress(bookID: Int, page: Int, percent: Double) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "books/\(bookID)/reader/progress",
            queryItems: [
                URLQueryItem(name: "position_type", value: "page"),
                URLQueryItem(name: "position_value", value: String(page)),
                URLQueryItem(name: "progress_percent", value: String(percent))
            ],
            requiresAuthentication: true
        )
    }

    static let library = APIEndpoint(method: .get, path: "me/library", requiresAuthentication: true)
    static func myComments(page: Int = 1) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "me/comments",
            queryItems: [URLQueryItem(name: "page", value: String(page))],
            requiresAuthentication: true
        )
    }
    static let subscription = APIEndpoint(method: .get, path: "me/subscription", requiresAuthentication: true)
    static let profile = APIEndpoint(method: .get, path: "me", requiresAuthentication: true)

    static func updateProfile(about: String, location: String, website: String, activityVisible: Bool) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "me",
            body: .form([
                "about": about,
                "location": location,
                "website": website,
                "activity_visible": activityVisible ? "1" : "0"
            ]),
            requiresAuthentication: true
        )
    }

    static func updateEmail(currentPassword: String, email: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "me/email",
            body: .form(["current_password": currentPassword, "email": email]),
            requiresAuthentication: true
        )
    }

    static func updatePassword(currentPassword: String, newPassword: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "me/password",
            body: .form(["current_password": currentPassword, "new_password": newPassword]),
            requiresAuthentication: true
        )
    }
    static let notifications = APIEndpoint(method: .get, path: "me/notifications", requiresAuthentication: true)
    static let notificationCounts = APIEndpoint(method: .get, path: "me/notifications/counts", requiresAuthentication: true)
    static let termsStatus = APIEndpoint(method: .get, path: "me/terms", requiresAuthentication: true)

    static func updateLibraryItem(bookID: Int, shelfState: String, progressPercent: Int, lastReadPage: Int) -> APIEndpoint {
        APIEndpoint(
            method: .put,
            path: "me/library/\(bookID)",
            body: .form([
                "shelf_state": shelfState,
                "progress_percent": String(progressPercent),
                "last_read_page": String(lastReadPage)
            ]),
            requiresAuthentication: true
        )
    }

    static func accountDeletion(currentPassword: String?, reason: String?) -> APIEndpoint {
        var fields: [String: String] = [:]
        if let currentPassword, !currentPassword.isEmpty {
            fields["current_password"] = currentPassword
        }
        if let reason, !reason.isEmpty {
            fields["reason"] = reason
        }
        return APIEndpoint(
            method: .post,
            path: "me/account-deletion-request",
            body: fields.isEmpty ? nil : .form(fields),
            requiresAuthentication: true
        )
    }

    static func markNotificationRead(id: Int, unread: Bool = false) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "me/notifications/\(id)/mark",
            body: .form(["unread": unread ? "1" : "0"]),
            requiresAuthentication: true
        )
    }

    static func markAllNotificationsRead() -> APIEndpoint {
        APIEndpoint(method: .post, path: "me/notifications/mark-all", requiresAuthentication: true)
    }

    static func acceptTerms(version: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "me/terms/accept",
            body: .form(["version": version]),
            requiresAuthentication: true
        )
    }

    static let legalTerms = APIEndpoint(method: .get, path: "legal/terms")

    static func login(username: String, password: String, acceptedTermsVersion: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "auth/login",
            body: .form([
                "login": username,
                "password": password,
                "accepted_terms_version": acceptedTermsVersion
            ])
        )
    }

    static func register(username: String, email: String, password: String, acceptedTermsVersion: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "auth/register",
            body: .form([
                "username": username,
                "email": email,
                "password": password,
                "accepted_terms_version": acceptedTermsVersion
            ])
        )
    }

    static func forgotPassword(email: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "auth/forgot-password", body: .form(["email": email]))
    }

    static func appleAuth(identityToken: String, authorizationCode: String, nonce: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "auth/apple",
            body: .form([
                "identity_token": identityToken,
                "authorization_code": authorizationCode,
                "nonce": nonce
            ])
        )
    }

    static func logout() -> APIEndpoint {
        APIEndpoint(method: .post, path: "auth/logout", requiresAuthentication: true)
    }

    static func refreshSession(refreshToken: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "auth/refresh",
            body: .form(["refresh_token": refreshToken])
        )
    }

    static func reportBookIssue(bookID: Int, type: String, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "books/\(bookID)/issue-report",
            body: .form(["type": type, "message": message]),
            requiresAuthentication: true
        )
    }

    static func reportForumPost(postID: Int, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "posts/\(postID)/report",
            body: .form(["message": message]),
            requiresAuthentication: true
        )
    }

    static func reportContent(
        type: UGCContentType,
        contentID: Int,
        reason: UGCReportReason,
        details: String = ""
    ) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "safety/reports",
            body: .form([
                "content_type": type.rawValue,
                "content_id": String(contentID),
                "reason_code": reason.rawValue,
                "details": details
            ]),
            requiresAuthentication: true
        )
    }

    static func blockMember(
        userID: Int,
        sourceType: UGCContentType? = nil,
        sourceID: Int? = nil,
        reason: UGCReportReason = .harassment,
        details: String = ""
    ) -> APIEndpoint {
        var fields = ["reason_code": reason.rawValue, "details": details]
        if let sourceType { fields["source_type"] = sourceType.rawValue }
        if let sourceID { fields["source_id"] = String(sourceID) }
        return APIEndpoint(
            method: .post,
            path: "members/\(userID)/block",
            body: .form(fields),
            requiresAuthentication: true
        )
    }

    static func unblockMember(userID: Int) -> APIEndpoint {
        APIEndpoint(method: .post, path: "members/\(userID)/unblock", requiresAuthentication: true)
    }

    static let blockedMembers = APIEndpoint(method: .get, path: "me/blocked-members", requiresAuthentication: true)

    static let forums = APIEndpoint(method: .get, path: "forums")

    static func forumThreads(forumID: Int, page: Int = 1) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "forums/\(forumID)/threads",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
        )
    }

    static func createForumThread(forumID: Int, title: String, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "forums/\(forumID)/threads",
            body: .form([
                "title": title,
                "message": message
            ]),
            requiresAuthentication: true
        )
    }

    static func threadPosts(threadID: Int, page: Int = 1) -> APIEndpoint {
        APIEndpoint(
            method: .get,
            path: "threads/\(threadID)/posts",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
        )
    }

    static func replyToThread(threadID: Int, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "threads/\(threadID)/posts",
            body: .form(["message": message]),
            requiresAuthentication: true
        )
    }

    static func editForumPost(postID: Int, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "posts/\(postID)/edit",
            body: .form(["message": message]),
            requiresAuthentication: true
        )
    }

    static func deleteForumPost(postID: Int) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "posts/\(postID)/delete",
            requiresAuthentication: true
        )
    }

    static func verifyAppStorePurchase(
        signedTransaction: String,
        productID: String,
        originalTransactionID: String?,
        signedRenewalInfo: String? = nil
    ) -> APIEndpoint {
        var fields = [
            "signed_transaction": signedTransaction,
            "product_id": productID
        ]
        if let originalTransactionID, !originalTransactionID.isEmpty {
            fields["original_transaction_id"] = originalTransactionID
        }
        if let signedRenewalInfo, !signedRenewalInfo.isEmpty {
            fields["signed_renewal_info"] = signedRenewalInfo
        }
        return APIEndpoint(
            method: .post,
            path: "billing/app-store/verify",
            body: .form(fields),
            requiresAuthentication: true
        )
    }
}

// MARK: - Kitap Gündemi

public extension APIEndpoint {
    static func bookAgenda(
        tab: BookAgendaTab = .agenda,
        filter: String? = nil,
        page: Int = 1,
        perPage: Int = 15
    ) -> APIEndpoint {
        var items = [
            URLQueryItem(name: "tab", value: tab.rawValue),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(min(max(perPage, 5), 30)))
        ]
        if let filter, !filter.isEmpty { items.append(URLQueryItem(name: "filter", value: filter)) }
        return APIEndpoint(method: .get, path: "book-agenda", queryItems: items, requiresAuthentication: tab != .agenda)
    }

    static func bookAgendaPost(id: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "book-agenda/\(id)")
    }

    static func createBookAgendaPost(
        message: String,
        postType: BookAgendaPostType,
        visibility: BookAgendaVisibility = .public,
        bookThreadID: String? = nil,
        quotePostID: String? = nil,
        reviewTitle: String? = nil,
        rating: Int? = nil,
        pageNumber: Int? = nil,
        progressCurrent: Int? = nil,
        progressTotal: Int? = nil
    ) -> APIEndpoint {
        var fields = [
            "message": message,
            "post_type": postType.rawValue,
            "visibility": visibility.rawValue
        ]
        if let bookThreadID, !bookThreadID.isEmpty { fields["book_thread_id"] = bookThreadID }
        if let quotePostID, !quotePostID.isEmpty { fields["quote_post_id"] = quotePostID }
        if let reviewTitle, !reviewTitle.isEmpty { fields["review_title"] = reviewTitle }
        if let rating, rating > 0 { fields["rating"] = String(rating) }
        if let pageNumber, pageNumber > 0 { fields["page_number"] = String(pageNumber) }
        if let progressCurrent, progressCurrent > 0 { fields["progress_current"] = String(progressCurrent) }
        if let progressTotal, progressTotal > 0 { fields["progress_total"] = String(progressTotal) }
        return APIEndpoint(method: .post, path: "book-agenda", body: .form(fields), requiresAuthentication: true)
    }

    static func updateBookAgendaPost(id: String, message: String, visibility: BookAgendaVisibility) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "book-agenda/\(id)",
            body: .form(["message": message, "visibility": visibility.rawValue]),
            requiresAuthentication: true
        )
    }

    static func deleteBookAgendaPost(id: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "book-agenda/\(id)", requiresAuthentication: true)
    }

    static func bookAgendaComments(postID: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "book-agenda/\(postID)/comments")
    }

    static func createBookAgendaComment(postID: String, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "book-agenda/\(postID)/comments",
            body: .form(["message": message]),
            requiresAuthentication: true
        )
    }

    static func updateBookAgendaComment(commentID: String, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "book-agenda-comments/\(commentID)",
            body: .form(["message": message]),
            requiresAuthentication: true
        )
    }

    static func deleteBookAgendaComment(commentID: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "book-agenda-comments/\(commentID)", requiresAuthentication: true)
    }

    static func toggleBookAgendaReaction(postID: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "book-agenda/\(postID)/reaction",
            body: .form(["reaction_id": "1"]),
            requiresAuthentication: true
        )
    }

    static func toggleBookAgendaBookmark(postID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "book-agenda/\(postID)/bookmark", requiresAuthentication: true)
    }

    static func toggleBookAgendaRepost(postID: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "book-agenda/\(postID)/repost", requiresAuthentication: true)
    }

    static func followBookAgendaActor(userID: String, follow: Bool) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "book-agenda-follow/\(userID)",
            body: .form(["follow": follow ? "1" : "0"]),
            requiresAuthentication: true
        )
    }
}

// MARK: - Okur Sohbeti

public extension APIEndpoint {
    static let chatRooms = APIEndpoint(method: .get, path: "chat/rooms")

    static func chatMessages(
        roomID: String,
        limit: Int = 40,
        beforeID: String? = nil,
        afterID: String? = nil
    ) -> APIEndpoint {
        var items = [URLQueryItem(name: "limit", value: String(min(max(limit, 10), 60)))]
        if let beforeID, !beforeID.isEmpty { items.append(URLQueryItem(name: "before_id", value: beforeID)) }
        if let afterID, !afterID.isEmpty { items.append(URLQueryItem(name: "after_id", value: afterID)) }
        return APIEndpoint(method: .get, path: "chat/rooms/\(roomID)/messages", queryItems: items)
    }

    static func sendChatMessage(roomID: String, message: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "chat/rooms/\(roomID)/messages",
            body: .form(["message": message]),
            requiresAuthentication: true
        )
    }
}

// MARK: - Canlı Aktivite

public extension APIEndpoint {
    static func liveActivity(limit: Int = 20, before: Int? = nil, userID: String? = nil) -> APIEndpoint {
        var items = [URLQueryItem(name: "limit", value: String(min(max(limit, 1), 40)))]
        if let before, before > 0 { items.append(URLQueryItem(name: "before", value: String(before))) }
        if let userID, !userID.isEmpty { items.append(URLQueryItem(name: "user_id", value: userID)) }
        return APIEndpoint(method: .get, path: "live-activity", queryItems: items)
    }
}

// MARK: - Okuma istatistikleri ve profil görselleri

public extension APIEndpoint {
    static let readingStats = APIEndpoint(method: .get, path: "me/reading-stats", requiresAuthentication: true)

    static func setDailyReadingGoal(minutes: Int) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "me/reading-stats",
            body: .form(["daily_goal_minutes": String(min(max(minutes, 10), 240))]),
            requiresAuthentication: true
        )
    }

    static func recordReadingSession(
        clientSessionID: String,
        bookID: String,
        readingDate: String,
        seconds: Int,
        pages: Int
    ) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "me/reading-stats",
            body: .form([
                "client_session_id": clientSessionID,
                "book_id": bookID,
                "reading_date": readingDate,
                "seconds": String(max(seconds, 0)),
                "pages": String(max(pages, 0))
            ]),
            requiresAuthentication: true
        )
    }

    static func uploadProfileImage(kind: ProfileImageKind, fileName: String, mimeType: String, data: Data) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "me/\(kind.rawValue)",
            body: .multipart(MultipartFile(field: "image", fileName: fileName, mimeType: mimeType, data: data)),
            requiresAuthentication: true
        )
    }
}
