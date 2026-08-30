import XCTest
@testable import EkitapligimCore

final class APIEndpointTests: XCTestCase {
    func testSiteStatsEndpointIsPublicAndReadOnly() {
        XCTAssertEqual(APIEndpoint.siteStats.path, "book-stats")
        XCTAssertEqual(APIEndpoint.siteStats.method, .get)
        XCTAssertFalse(APIEndpoint.siteStats.requiresAuthentication)
    }

    func testRegistrationAndPasswordResetArePublicFormRequests() {
        let registration = APIEndpoint.register(
            username: "okur",
            email: "okur@example.com",
            password: "secret",
            acceptedTermsVersion: "2026-08"
        )
        XCTAssertEqual(registration.path, "auth/register")
        XCTAssertEqual(registration.method, .post)
        XCTAssertFalse(registration.requiresAuthentication)
        XCTAssertEqual(registration.body, .form([
            "username": "okur",
            "email": "okur@example.com",
            "password": "secret",
            "accepted_terms_version": "2026-08"
        ]))

        let reset = APIEndpoint.forgotPassword(email: "okur@example.com")
        XCTAssertEqual(reset.path, "auth/forgot-password")
        XCTAssertEqual(reset.method, .post)
        XCTAssertFalse(reset.requiresAuthentication)
        XCTAssertEqual(reset.body, .form(["email": "okur@example.com"]))
    }

    func testBooksEndpointBuildsQuery() throws {
        let base = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        let url = try APIEndpoint.books(page: 2, query: "Orhan", category: "Roman", order: "popular").url(relativeTo: base)

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "ekitapligim.com")
        XCTAssertTrue(url.absoluteString.contains("/ios-api/v1/books"))
        XCTAssertTrue(url.absoluteString.contains("page=2"))
        XCTAssertTrue(url.absoluteString.contains("q=Orhan"))
    }

    func testBooksEndpointBuildsAdvancedFilters() throws {
        let base = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        let endpoint = APIEndpoint.books(
            page: 3,
            category: "12",
            author: "Yaşar Kemal",
            publisher: "Yapı Kredi",
            isbn: "9789750807149",
            order: "rated",
            premiumOnly: true
        )
        let url = try endpoint.url(relativeTo: base)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        XCTAssertEqual(items.first(where: { $0.name == "category" })?.value, "12")
        XCTAssertEqual(items.first(where: { $0.name == "author" })?.value, "Yaşar Kemal")
        XCTAssertEqual(items.first(where: { $0.name == "publisher" })?.value, "Yapı Kredi")
        XCTAssertEqual(items.first(where: { $0.name == "isbn" })?.value, "9789750807149")
        XCTAssertEqual(items.first(where: { $0.name == "order" })?.value, "rated")
        XCTAssertEqual(items.first(where: { $0.name == "premium_only" })?.value, "1")
    }

    func testDirectoryEndpointsUseNativeMobileRoutes() throws {
        let base = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        let authors = APIEndpoint.directory(kind: .author, page: 2, query: "Yaşar")
        let authorURL = try authors.url(relativeTo: base)

        XCTAssertEqual(authors.path, "authors")
        XCTAssertTrue(authorURL.absoluteString.contains("page=2"))
        XCTAssertTrue(authorURL.absoluteString.contains("q=Ya%C5%9Far"))

        let books = APIEndpoint.directoryBooks(kind: .publisher, slug: "can-yayinlari", page: 3)
        XCTAssertEqual(books.path, "publishers/can-yayinlari/books")
        XCTAssertEqual(books.queryItems.first?.value, "3")
    }

    func testBookRequestWriteEndpointsRequireAuthentication() {
        XCTAssertEqual(APIEndpoint.bookRequests.path, "book-requests")
        XCTAssertFalse(APIEndpoint.bookRequests.requiresAuthentication)

        let create = APIEndpoint.createBookRequest(title: "Dune", author: "Frank Herbert", isbn: "9780441172719")
        XCTAssertEqual(create.method, .post)
        XCTAssertTrue(create.requiresAuthentication)

        let vote = APIEndpoint.voteBookRequest(id: "42")
        XCTAssertEqual(vote.path, "book-requests/42/vote")
        XCTAssertTrue(vote.requiresAuthentication)
    }

    func testConversationEndpointsRequireAuthentication() {
        let list = APIEndpoint.conversations(page: 2)
        XCTAssertEqual(list.path, "conversations")
        XCTAssertEqual(list.queryItems.first?.value, "2")
        XCTAssertTrue(list.requiresAuthentication)

        XCTAssertEqual(APIEndpoint.conversation(id: "7").path, "conversation-detail/7")
        XCTAssertTrue(APIEndpoint.conversation(id: "7").requiresAuthentication)
        XCTAssertEqual(APIEndpoint.replyToConversation(id: "7", message: "Merhaba").path, "conversation-reply/7")
        XCTAssertTrue(APIEndpoint.createConversation(recipient: "demo", title: "Konu", message: "Mesaj").requiresAuthentication)
    }

    func testMemberEndpointsUseCollisionFreeMobileRoutes() {
        let list = APIEndpoint.members(page: 2, query: "demo", sort: "active")
        XCTAssertEqual(list.path, "members")
        XCTAssertFalse(list.requiresAuthentication)
        XCTAssertEqual(list.queryItems.first(where: { $0.name == "sort" })?.value, "active")

        XCTAssertEqual(APIEndpoint.member(id: "42").path, "member-detail/42")
        XCTAssertEqual(APIEndpoint.followMember(id: "42").path, "member-follow/42")
        XCTAssertTrue(APIEndpoint.followMember(id: "42").requiresAuthentication)
        XCTAssertEqual(APIEndpoint.unfollowMember(id: "42").path, "member-unfollow/42")
    }

    func testReaderProgressRequiresAuthentication() {
        let endpoint = APIEndpoint.updateReaderProgress(bookID: 15582, page: 12, percent: 25)

        XCTAssertEqual(endpoint.method, .post)
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertEqual(endpoint.path, "books/15582/reader/progress")
        XCTAssertEqual(endpoint.queryItems.first(where: { $0.name == "position_type" })?.value, "page")
        XCTAssertEqual(endpoint.queryItems.first(where: { $0.name == "position_value" })?.value, "12")
        XCTAssertEqual(endpoint.queryItems.first(where: { $0.name == "progress_percent" })?.value, "25.0")
    }

    func testReaderSessionsUseAnExplicitAuthorizedPurpose() {
        let read = APIEndpoint.readerSession(bookID: 15582, purpose: .read)
        let download = APIEndpoint.readerSession(bookID: 15582, purpose: .download)

        XCTAssertEqual(read.method, .post)
        XCTAssertEqual(read.path, "books/15582/reader/session")
        XCTAssertTrue(read.requiresAuthentication)
        XCTAssertEqual(read.body, .form(["purpose": "read"]))
        XCTAssertEqual(download.body, .form(["purpose": "download"]))
    }

    func testReaderAccessCarriesAuthenticationForMemberQuota() {
        let access = APIEndpoint.readerAccess(bookID: 15582)

        XCTAssertTrue(access.requiresAuthentication)
        XCTAssertEqual(access.path, "books/15582/reader/access")
    }

    func testBookDetailUsesDedicatedMobileRoute() {
        let endpoint = APIEndpoint.book(id: 15585)

        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.path, "book-detail/15585")
        XCTAssertFalse(endpoint.requiresAuthentication)
    }

    func testBookCommentEndpoints() {
        let list = APIEndpoint.bookComments(bookID: 15585, page: 2)
        XCTAssertEqual(list.path, "books/15585/comments")
        XCTAssertEqual(list.queryItems.first?.value, "2")
        XCTAssertFalse(list.requiresAuthentication)

        let create = APIEndpoint.createBookComment(bookID: 15585, message: "Güzel kitap", rating: 5)
        XCTAssertEqual(create.method, .post)
        XCTAssertTrue(create.requiresAuthentication)
    }

    func testSafetyEndpointsRequireAuthentication() {
        XCTAssertTrue(APIEndpoint.blockMember(userID: 42).requiresAuthentication)
        XCTAssertEqual(APIEndpoint.legalTerms.path, "legal/terms")
        let report = APIEndpoint.reportContent(
            type: .agendaComment,
            contentID: 91,
            reason: .harassment,
            details: "test"
        )
        XCTAssertEqual(report.path, "safety/reports")
        XCTAssertEqual(report.body, .form([
            "content_type": "agenda_comment",
            "content_id": "91",
            "reason_code": "harassment",
            "details": "test"
        ]))
        XCTAssertTrue(APIEndpoint.reportForumPost(postID: 99, message: "Uygunsuz içerik").requiresAuthentication)
        XCTAssertEqual(APIEndpoint.blockedMembers.path, "me/blocked-members")
    }

    func testAppStoreVerifyEndpointRequiresAuthentication() {
        let endpoint = APIEndpoint.verifyAppStorePurchase(
            signedTransaction: "signed",
            productID: "ekitapligim.premium.monthly",
            originalTransactionID: "1000001",
            signedRenewalInfo: "renewal"
        )

        XCTAssertEqual(endpoint.path, "billing/app-store/verify")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertTrue(endpoint.requiresAuthentication)
        guard case .form(let fields) = endpoint.body else {
            return XCTFail("Expected StoreKit verification form body")
        }
        XCTAssertEqual(fields["signed_renewal_info"], "renewal")
    }

    func testForumEndpoints() {
        XCTAssertEqual(APIEndpoint.forums.path, "forums")

        let threads = APIEndpoint.forumThreads(forumID: 12, page: 3)
        XCTAssertEqual(threads.path, "forums/12/threads")
        XCTAssertEqual(threads.queryItems.first?.value, "3")

        let reply = APIEndpoint.replyToThread(threadID: 99, message: "Merhaba")
        XCTAssertEqual(reply.path, "threads/99/posts")
        XCTAssertEqual(reply.method, .post)
        XCTAssertTrue(reply.requiresAuthentication)

        let create = APIEndpoint.createForumThread(forumID: 12, title: "Başlık", message: "Mesaj")
        XCTAssertEqual(create.path, "forums/12/threads")
        XCTAssertEqual(create.method, .post)
        XCTAssertTrue(create.requiresAuthentication)

        XCTAssertEqual(APIEndpoint.createBookRequest(title: "T", author: "A", isbn: "").path, "book-requests")
        XCTAssertTrue(APIEndpoint.createBookRequest(title: "T", author: "A", isbn: "").requiresAuthentication)

        XCTAssertEqual(APIEndpoint.sendChatMessage(roomID: "3", message: "Selam").path, "chat/rooms/3/messages")
        XCTAssertTrue(APIEndpoint.sendChatMessage(roomID: "3", message: "Selam").requiresAuthentication)
    }

    func testLibraryUpdateRequiresAuthentication() {
        let endpoint = APIEndpoint.updateLibraryItem(bookID: 15582, shelfState: "OKUYORUM", progressPercent: 40, lastReadPage: 12)

        XCTAssertEqual(endpoint.path, "me/library/15582")
        XCTAssertEqual(endpoint.method, .put)
        XCTAssertTrue(endpoint.requiresAuthentication)
    }

    func testAccountDeletionCanCarryReauthenticationFields() {
        let endpoint = APIEndpoint.accountDeletion(currentPassword: "secret", reason: "Artık kullanmıyorum")

        XCTAssertEqual(endpoint.path, "me/account-deletion-request")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertNotNil(endpoint.body)
    }

    func testProfileAndNotificationEndpointsRequireAuthentication() {
        XCTAssertEqual(APIEndpoint.profile.path, "me")
        XCTAssertTrue(APIEndpoint.profile.requiresAuthentication)
        XCTAssertEqual(APIEndpoint.notifications.path, "me/notifications")
        XCTAssertTrue(APIEndpoint.notifications.requiresAuthentication)
        XCTAssertEqual(APIEndpoint.notificationCounts.path, "me/notifications/counts")
        XCTAssertTrue(APIEndpoint.notificationCounts.requiresAuthentication)
    }

    func testMyCommentsEndpointRequiresAuthenticationAndBuildsPageQuery() {
        let endpoint = APIEndpoint.myComments(page: 3)

        XCTAssertEqual(endpoint.path, "me/comments")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.queryItems.first?.value, "3")
        XCTAssertTrue(endpoint.requiresAuthentication)
    }

    func testProfileUpdateUsesAuthenticatedFormRequest() {
        let endpoint = APIEndpoint.updateProfile(
            about: "Okur",
            location: "İstanbul",
            website: "https://example.com",
            activityVisible: false
        )

        XCTAssertEqual(endpoint.path, "me")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertEqual(
            endpoint.body,
            .form([
                "about": "Okur",
                "location": "İstanbul",
                "website": "https://example.com",
                "activity_visible": "0"
            ])
        )
    }

    func testIdentityChangeEndpointsRequireReauthenticationFields() {
        let email = APIEndpoint.updateEmail(currentPassword: "old", email: "new@example.com")
        XCTAssertEqual(email.path, "me/email")
        XCTAssertEqual(email.method, .post)
        XCTAssertTrue(email.requiresAuthentication)
        XCTAssertEqual(email.body, .form(["current_password": "old", "email": "new@example.com"]))

        let password = APIEndpoint.updatePassword(currentPassword: "old", newPassword: "new-secret")
        XCTAssertEqual(password.path, "me/password")
        XCTAssertEqual(password.method, .post)
        XCTAssertTrue(password.requiresAuthentication)
        XCTAssertEqual(password.body, .form(["current_password": "old", "new_password": "new-secret"]))
    }

    func testMarkNotificationEndpointsRequireAuthentication() {
        let markOne = APIEndpoint.markNotificationRead(id: 55)
        XCTAssertEqual(markOne.path, "me/notifications/55/mark")
        XCTAssertTrue(markOne.requiresAuthentication)

        XCTAssertEqual(APIEndpoint.markAllNotificationsRead().path, "me/notifications/mark-all")
        XCTAssertTrue(APIEndpoint.markAllNotificationsRead().requiresAuthentication)
    }

    func testTermsEndpointsRequireAuthentication() {
        XCTAssertEqual(APIEndpoint.termsStatus.path, "me/terms")
        XCTAssertTrue(APIEndpoint.termsStatus.requiresAuthentication)

        let accept = APIEndpoint.acceptTerms(version: "2026-07")
        XCTAssertEqual(accept.path, "me/terms/accept")
        XCTAssertEqual(accept.method, .post)
        XCTAssertTrue(accept.requiresAuthentication)
    }

    func testCommunityEndpointsMatchAndroidRoutes() throws {
        let base = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))

        let agenda = APIEndpoint.bookAgenda(tab: .agenda, filter: "review", page: 2, perPage: 15)
        XCTAssertEqual(agenda.path, "book-agenda")
        XCTAssertFalse(agenda.requiresAuthentication)
        let agendaURL = try agenda.url(relativeTo: base)
        XCTAssertTrue(agendaURL.absoluteString.contains("tab=agenda"))
        XCTAssertTrue(agendaURL.absoluteString.contains("filter=review"))

        XCTAssertEqual(APIEndpoint.bookAgendaPost(id: "19").path, "book-agenda/19")
        XCTAssertEqual(APIEndpoint.toggleBookAgendaReaction(postID: "19").path, "book-agenda/19/reaction")
        XCTAssertTrue(APIEndpoint.toggleBookAgendaReaction(postID: "19").requiresAuthentication)

        XCTAssertEqual(APIEndpoint.chatRooms.path, "chat/rooms")
        XCTAssertFalse(APIEndpoint.chatRooms.requiresAuthentication)

        let chatMessages = APIEndpoint.chatMessages(roomID: "1", limit: 40, afterID: "99")
        XCTAssertEqual(chatMessages.path, "chat/rooms/1/messages")
        let chatURL = try chatMessages.url(relativeTo: base)
        XCTAssertTrue(chatURL.absoluteString.contains("after_id=99"))

        let live = APIEndpoint.liveActivity(limit: 20, before: 1_700_000, userID: "37")
        XCTAssertEqual(live.path, "live-activity")
        let liveURL = try live.url(relativeTo: base)
        XCTAssertTrue(liveURL.absoluteString.contains("user_id=37"))

        XCTAssertEqual(APIEndpoint.readingStats.path, "me/reading-stats")
        XCTAssertTrue(APIEndpoint.readingStats.requiresAuthentication)

        let avatar = APIEndpoint.uploadProfileImage(
            kind: .avatar,
            fileName: "avatar.jpg",
            mimeType: "image/jpeg",
            data: Data([0xFF, 0xD8, 0xFF])
        )
        XCTAssertEqual(avatar.path, "me/avatar")
        XCTAssertTrue(avatar.requiresAuthentication)
        if case .multipart(let file) = avatar.body {
            XCTAssertEqual(file.field, "image")
            XCTAssertEqual(file.fileName, "avatar.jpg")
        } else {
            XCTFail("Expected multipart body")
        }
    }

    func testMissingEndpointDetection() {
        let missing = APIClientError.httpStatus(404, nil)
        XCTAssertTrue(missing.isMissingEndpoint)
        XCTAssertFalse(APIClientError.authenticationRequired.isMissingEndpoint)
    }
}
