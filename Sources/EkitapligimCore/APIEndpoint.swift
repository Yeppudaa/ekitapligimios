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
        APIEndpoint(method: .get, path: "books/\(bookID)/reader/access")
    }

    static func readerSession(bookID: Int) -> APIEndpoint {
        APIEndpoint(method: .post, path: "books/\(bookID)/reader/session", requiresAuthentication: true)
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

    static func login(username: String, password: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "auth/login",
            body: .form(["login": username, "password": password])
        )
    }

    static func register(username: String, email: String, password: String) -> APIEndpoint {
        APIEndpoint(
            method: .post,
            path: "auth/register",
            body: .form(["username": username, "email": email, "password": password])
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

    static func blockMember(userID: Int) -> APIEndpoint {
        APIEndpoint(method: .post, path: "members/\(userID)/block", requiresAuthentication: true)
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

    static func verifyAppStorePurchase(
        signedTransaction: String,
        productID: String,
        originalTransactionID: String?
    ) -> APIEndpoint {
        var fields = [
            "signed_transaction": signedTransaction,
            "product_id": productID
        ]
        if let originalTransactionID, !originalTransactionID.isEmpty {
            fields["original_transaction_id"] = originalTransactionID
        }
        return APIEndpoint(
            method: .post,
            path: "billing/app-store/verify",
            body: .form(fields),
            requiresAuthentication: true
        )
    }
}
