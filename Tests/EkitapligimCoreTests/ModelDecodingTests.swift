import XCTest
@testable import EkitapligimCore

final class ModelDecodingTests: XCTestCase {
    func testSiteStatsDecodeCurrentBackendShape() throws {
        let data = Data("""
        {
          "total_books": 14404,
          "total_authors": 7131,
          "total_publishers": 1564,
          "total_categories": 32,
          "total_downloadable_books": 13000,
          "books_with_cover": 14307,
          "books_with_summary": 14100,
          "last_rebuild_date": 1782897891
        }
        """.utf8)
        let stats = try JSONDecoder.ekitapligim.decode(SiteStatsDTO.self, from: data)
        XCTAssertEqual(stats.totalBooks, 14404)
        XCTAssertEqual(stats.totalAuthors, 7131)
        XCTAssertEqual(stats.totalPublishers, 1564)
        XCTAssertEqual(stats.totalCategories, 32)
        XCTAssertEqual(stats.totalDownloadableBooks, 13000)
    }

    func testEmailChangeResponseDecodesConfirmationState() throws {
        let data = Data("""
        {"success":true,"email":"new@example.com","confirmation_required":true}
        """.utf8)
        let response = try JSONDecoder.ekitapligim.decode(EmailChangeResponseDTO.self, from: data)
        XCTAssertEqual(response.email, "new@example.com")
        XCTAssertTrue(response.confirmationRequired)
    }

    func testBookCommentsDecodeCurrentBackendShape() throws {
        let data = Data("""
        {
          "comments": [
            {
              "id": "15601",
              "post_id": 15601,
              "book_id": "15585",
              "username": "Demo",
              "message": "Güzel kitap",
              "image_urls": [],
              "rating": 5,
              "created_at": 1783710000
            }
          ],
          "pagination": { "page": 1, "total": 1, "pages": 1 }
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(BookCommentsPageDTO.self, from: data)

        XCTAssertEqual(page.comments.first?.id, "15601")
        XCTAssertEqual(page.comments.first?.bookId, "15585")
        XCTAssertEqual(page.comments.first?.rating, 5)
    }

    func testMembersPageDecodesCurrentBackendShape() throws {
        let data = Data("""
        {
          "members": [
            {
              "id": "4",
              "username": "Demo",
              "user_title": "Topluluk Üyesi",
              "message_count": 12,
              "reaction_score": 3,
              "register_date": 1783710000,
              "last_activity": 0,
              "avatar_url": "https://ekitapligim.com/avatar.jpg",
              "is_staff": false,
              "is_followed": true,
              "can_follow": true,
              "role_label": "Topluluk Üyesi",
              "show_verified_badge": false
            }
          ],
          "pagination": { "page": 1, "total": 25, "pages": 2 }
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(MembersPageDTO.self, from: data)

        XCTAssertEqual(page.members.first?.id, "4")
        XCTAssertEqual(page.members.first?.messageCount, 12)
        XCTAssertEqual(page.members.first?.isFollowed, true)
        XCTAssertEqual(page.total, 25)
    }

    func testConversationDetailDecodesCurrentBackendShape() throws {
        let data = Data("""
        {
          "conversation": {
            "id": "7",
            "conversation_id": 7,
            "title": "Deneme konuşması",
            "starter_username": "Ekitapligim",
            "last_message_date": 1783710000,
            "last_message_username": "Demo",
            "reply_count": 1,
            "is_unread": true,
            "is_starred": false,
            "can_reply": true,
            "participants": [],
            "preview": "Son mesaj"
          },
          "messages": [
            {
              "id": "10",
              "conversation_id": 7,
              "user_id": 1,
              "username": "Ekitapligim",
              "message": "Merhaba",
              "message_date": 1783710000,
              "avatar_url": "https://ekitapligim.com/avatar.jpg",
              "is_mine": true
            }
          ]
        }
        """.utf8)

        let detail = try JSONDecoder.ekitapligim.decode(ConversationDetailDTO.self, from: data)

        XCTAssertEqual(detail.conversation.id, "7")
        XCTAssertTrue(detail.conversation.isUnread)
        XCTAssertEqual(detail.messages.first?.message, "Merhaba")
        XCTAssertEqual(detail.messages.first?.isMine, true)
    }

    func testBookRequestsDecodeCurrentBackendShape() throws {
        let data = Data("""
        {
          "book_requests": [
            {
              "id": "3",
              "request_id": 3,
              "title": "Gece Yarısı Kütüphanesi",
              "author": "Matt Haig",
              "requested_by": "Ekitapligim",
              "vote_count": 13,
              "status": "PENDING"
            }
          ]
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(BookRequestsPageDTO.self, from: data)

        XCTAssertEqual(page.items.first?.id, "3")
        XCTAssertEqual(page.items.first?.requestedBy, "Ekitapligim")
        XCTAssertEqual(page.items.first?.voteCount, 13)
    }

    func testBookRequestVoteDecodesSnakeCaseCount() throws {
        let data = Data("""
        { "success": true, "voted": true, "vote_count": 14 }
        """.utf8)

        let vote = try JSONDecoder.ekitapligim.decode(BookRequestVoteDTO.self, from: data)

        XCTAssertTrue(vote.voted)
        XCTAssertEqual(vote.voteCount, 14)
    }

    func testDirectoryPageDecodesCurrentBackendShape() throws {
        let data = Data("""
        {
          "authors": [
            {
              "id": "agatha-christie",
              "name": "Agatha Christie",
              "slug": "agatha-christie",
              "book_count": 78,
              "kind": "author"
            }
          ],
          "pagination": {
            "page": 1,
            "per_page": 30,
            "total": 6904,
            "pages": 231
          }
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(DirectoryPageDTO.self, from: data)

        XCTAssertEqual(page.items.first?.slug, "agatha-christie")
        XCTAssertEqual(page.items.first?.bookCount, 78)
        XCTAssertEqual(page.lastPage, 231)
        XCTAssertEqual(page.total, 6904)
    }

    func testBooksPageDecodesCurrentBackendPaginationShape() throws {
        let data = Data("""
        {
          "books": [
            {
              "id": "15585",
              "thread_id": 15585,
              "title": "Yanlış Hedef",
              "author": "Domenico Starnone",
              "publisher": "TERSİNE KİTAP",
              "isbn": "9786259264257",
              "category": "Roman",
              "language": "Türkçe",
              "publish_year": "2026-05-18",
              "description": "Açıklama",
              "cover_url": "https://ekitapligim.com/data/books/covers/15/15585.jpg",
              "pdf_url": "https://ekitapligim.com/books/yanlis-hedef.15585/read",
              "page_count": 168,
              "isPremiumOnly": false,
              "view_count": 1,
              "reaction_score": 0,
              "rating": 0
            }
          ],
          "pagination": {
            "page": 1,
            "per_page": 20,
            "total": 14409,
            "pages": 721
          }
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(BooksPageDTO.self, from: data)

        XCTAssertEqual(page.books.first?.id, "15585")
        XCTAssertEqual(page.currentPage, 1)
        XCTAssertEqual(page.lastPage, 721)
        XCTAssertEqual(page.totalBooks, 14409)
    }

    func testBookDetailEnvelopeDecodesSimilarBooks() throws {
        let data = Data("""
        {
          "book": {
            "id": "15585", "title": "Yanlış Hedef", "author": "Domenico Starnone",
            "publisher": "Tersine Kitap", "isbn": "9786259264257", "category": "Roman",
            "language": "Türkçe", "publish_year": "2026", "description": "Açıklama",
            "cover_url": "https://example.com/15585.jpg", "pdf_url": "", "page_count": 168,
            "isPremiumOnly": false,
            "similar_books": [
              {
                "id": "15586", "title": "Benzer Kitap", "author": "Yazar",
                "publisher": "Yayınevi", "isbn": "9780000000001", "category": "Roman",
                "language": "Türkçe", "publish_year": "2025", "description": "",
                "cover_url": "https://example.com/15586.jpg", "pdf_url": "", "page_count": 200,
                "isPremiumOnly": false
              }
            ]
          }
        }
        """.utf8)

        let detail = try JSONDecoder.ekitapligim.decode(BookEnvelope.self, from: data)

        XCTAssertEqual(detail.book.id, "15585")
        XCTAssertEqual(detail.similarBooks.map(\.id), ["15586"])
        XCTAssertEqual(detail.similarBooks.first?.category, "Roman")
    }

    func testForumListDecodesCurrentBackendShape() throws {
        let data = Data("""
        {
          "forums": [
            {
              "id": "6",
              "node_id": 6,
              "title": "Roman",
              "description": "Kitap forumu",
              "url": "https://ekitapligim.com/forumlar/roman.6/",
              "stats": "3251 konu, 3254 mesaj",
              "thread_count": 3251,
              "is_book_forum": true
            }
          ]
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(ForumsPageDTO.self, from: data)

        XCTAssertEqual(page.forums.first?.id, "6")
        XCTAssertEqual(page.forums.first?.url, "https://ekitapligim.com/forumlar/roman.6/")
        XCTAssertEqual(page.forums.first?.threadCount, 3251)
        XCTAssertEqual(page.forums.first?.isBookForum, true)
    }

    func testForumListToleratesLegacyMissingOptionalFields() throws {
        let data = Data("""
        {
          "forums": [
            {
              "node_id": 44,
              "title": "Genel Sohbet",
              "description": ""
            }
          ]
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(ForumsPageDTO.self, from: data)

        XCTAssertEqual(page.forums.first?.id, "44")
        XCTAssertEqual(page.forums.first?.url, "")
        XCTAssertNil(page.forums.first?.threadCount)
    }

    func testForumThreadsDecodeItemsAndNestedPaginationFallback() throws {
        let data = Data("""
        {
          "items": [
            {
              "id": "1",
              "title": "Forum Kuralları",
              "username": "Ekitapligim",
              "reply_count": 0,
              "view_count": 108,
              "post_date": 1779279451,
              "can_reply": false,
              "is_sticky": true,
              "discussion_type": "discussion"
            }
          ],
          "pagination": {
            "page": 1,
            "total": 1,
            "pages": 1
          }
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(ForumThreadsPageDTO.self, from: data)

        XCTAssertEqual(page.threads.count, 1)
        XCTAssertEqual(page.threads.first?.replyCount, 0)
        XCTAssertEqual(page.currentPage, 1)
        XCTAssertEqual(page.lastPage, 1)
        XCTAssertEqual(page.total, 1)
    }

    func testForumPostsDecodeCurrentBackendShape() throws {
        let data = Data("""
        {
          "posts": [
            {
              "id": "15606",
              "thread_id": "15585",
              "username": "Ekitapligim",
              "message": "Merhaba",
              "post_date": 1782941233,
              "can_edit": false,
              "can_reply": false,
              "thread_title": "Yanlış Hedef",
              "image_urls": [],
              "user_id": 1,
              "avatar_url": "https://ekitapligim.com/data/avatars/m/0/1.jpg",
              "is_admin": true,
              "is_moderator": true,
              "is_premium": true
            }
          ],
          "current_page": 1,
          "last_page": 1,
          "total": 1
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(ForumPostsPageDTO.self, from: data)

        XCTAssertEqual(page.posts.first?.threadId, "15585")
        XCTAssertEqual(page.posts.first?.imageUrls, [])
        XCTAssertEqual(page.posts.first?.isAdmin, true)
        XCTAssertEqual(page.currentPage, 1)
        XCTAssertEqual(page.lastPage, 1)
    }

    func testForumReplyEnvelopeDecodesPost() throws {
        let data = Data("""
        {
          "success": true,
          "post": {
            "id": "15607",
            "thread_id": "15585",
            "username": "Ekitapligim",
            "message": "Cevap",
            "post_date": 1782941300,
            "can_edit": false,
            "can_reply": true,
            "thread_title": "Yanlış Hedef",
            "image_urls": [],
            "user_id": 1
          }
        }
        """.utf8)

        let envelope = try JSONDecoder.ekitapligim.decode(ForumPostEnvelope.self, from: data)

        XCTAssertEqual(envelope.post.id, "15607")
        XCTAssertEqual(envelope.post.message, "Cevap")
    }

    func testMyCommentsDecodeCurrentBackendShape() throws {
        let data = Data("""
        {
          "items": [
            {
              "id": "15607",
              "thread_id": 15585,
              "thread_title": "Yanlış Hedef",
              "username": "Ekitapligim",
              "message": "Cevap",
              "post_date": 1782941300,
              "can_edit": false,
              "can_reply": true
            }
          ],
          "pagination": {
            "page": 2,
            "per_page": 30,
            "total": 31,
            "pages": 2
          }
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(MyCommentsPageDTO.self, from: data)

        XCTAssertEqual(page.comments.first?.id, "15607")
        XCTAssertEqual(page.comments.first?.threadId, "15585")
        XCTAssertEqual(page.comments.first?.threadTitle, "Yanlış Hedef")
        XCTAssertEqual(page.currentPage, 2)
        XCTAssertEqual(page.lastPage, 2)
        XCTAssertEqual(page.total, 31)
    }

    func testNotificationDecodesNativeRouteFields() throws {
        let data = Data("""
        {
          "items": [
            {
              "id": "28",
              "type": "post",
              "title": "Yeni yanıt",
              "message": "Konunuza yanıt verildi.",
              "actor_username": "okur",
              "target_url": "https://ekitapligim.com/threads/yanlis-hedef.15585/",
              "app_route": "thread/15585",
              "content_id": 15607,
              "event_date": 1782941300,
              "is_read": false,
              "is_viewed": true
            }
          ],
          "counts": { "unread": 1, "unviewed": 0, "conversations_unread": 0 },
          "current_page": 1,
          "last_page": 1,
          "total": 1
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(NotificationsPageDTO.self, from: data)
        let notification = try XCTUnwrap(page.items.first)

        XCTAssertEqual(notification.appRoute, "thread/15585")
        XCTAssertEqual(notification.contentId, 15607)
        XCTAssertEqual(notification.targetUrl, "https://ekitapligim.com/threads/yanlis-hedef.15585/")
        XCTAssertEqual(notification.isRead, false)
    }

    func testAuthResponseDecodesBackendShape() throws {
        let data = Data("""
        {
          "access_token": "ms_at_example",
          "refresh_token": "ms_rt_example",
          "user": {
            "user_id": 3,
            "username": "SDR1035",
            "email": "demo@example.com",
            "is_premium": false,
            "premium_plan_name": "Standart Üye"
          }
        }
        """.utf8)

        let response = try JSONDecoder.ekitapligim.decode(AuthResponseDTO.self, from: data)

        XCTAssertEqual(response.accessToken, "ms_at_example")
        XCTAssertEqual(response.refreshToken, "ms_rt_example")
        XCTAssertEqual(response.user.username, "SDR1035")
        XCTAssertEqual(response.user.isPremium, false)
    }

    func testProfileDecodesCurrentBackendShape() throws {
        let data = Data("""
        {
          "id": "1",
          "user_id": 1,
          "username": "Ekitapligim",
          "email": "info@ekitapligim.com",
          "title": "",
          "avatar_url": "https://ekitapligim.com/data/avatars/m/0/1.jpg",
          "message_count": 14439,
          "reaction_score": 3,
          "register_date": 1779275665,
          "is_staff": true,
          "can_edit": true,
          "about": "Kitap tutkunu",
          "location": "İstanbul",
          "website": "https://example.com",
          "activity_visible": false
        }
        """.utf8)

        let profile = try JSONDecoder.ekitapligim.decode(ProfileDTO.self, from: data)

        XCTAssertEqual(profile.id, "1")
        XCTAssertEqual(profile.username, "Ekitapligim")
        XCTAssertEqual(profile.messageCount, 14439)
        XCTAssertEqual(profile.isStaff, true)
        XCTAssertEqual(profile.about, "Kitap tutkunu")
        XCTAssertEqual(profile.location, "İstanbul")
        XCTAssertEqual(profile.website, "https://example.com")
        XCTAssertEqual(profile.activityVisible, false)
    }

    func testReaderSessionDecodesCurrentBackendShape() throws {
        let data = Data("""
        {
          "token": "reader-token",
          "source_url": "https://ekitapligim.com/books/yanlis-hedef.15585/read-source?t=reader-token",
          "sourceUrl": "https://ekitapligim.com/books/yanlis-hedef.15585/read-source?t=reader-token",
          "api_source_url": "https://ekitapligim.com/api/v1/books/reader-source?t=reader-token",
          "file_type": "pdf",
          "expires_in": 900
        }
        """.utf8)

        let session = try JSONDecoder.ekitapligim.decode(ReaderSessionDTO.self, from: data)

        XCTAssertEqual(session.token, "reader-token")
        XCTAssertEqual(session.sourceUrl, "https://ekitapligim.com/books/yanlis-hedef.15585/read-source?t=reader-token")
        XCTAssertEqual(session.fileType, "pdf")
    }

    func testReaderSessionDecodesEPUBFileType() throws {
        let data = Data("""
        {
          "token": "reader-token",
          "source_url": "https://ekitapligim.com/mobile-api/v1/books/42/reader/source?t=reader-token",
          "file_type": "epub"
        }
        """.utf8)
        let session = try JSONDecoder.ekitapligim.decode(ReaderSessionDTO.self, from: data)
        XCTAssertEqual(session.fileType, "epub")
    }

    func testTermsStatusDecodesBackendShape() throws {
        let data = Data("""
        {
          "required_version": "2026-07",
          "accepted_version": null,
          "accepted_at": null,
          "requires_acceptance": true
        }
        """.utf8)

        let status = try JSONDecoder.ekitapligim.decode(TermsStatusDTO.self, from: data)

        XCTAssertEqual(status.requiredVersion, "2026-07")
        XCTAssertEqual(status.requiresAcceptance, true)
    }

    func testSuccessResponsesDecodeCommonBackendShapes() throws {
        let simple = try JSONDecoder.ekitapligim.decode(SuccessResponse.self, from: Data("""
        { "success": true }
        """.utf8))
        let deletion = try JSONDecoder.ekitapligim.decode(SuccessResponse.self, from: Data("""
        { "success": true, "request_id": 12, "message": "Hesap silme talebiniz alındı." }
        """.utf8))
        let emptyObject = try JSONDecoder.ekitapligim.decode(SuccessResponse.self, from: Data("""
        {}
        """.utf8))

        XCTAssertTrue(simple.success)
        XCTAssertEqual(deletion.requestId, 12)
        XCTAssertTrue(emptyObject.success)
    }

    func testBillingResponseDecodesVerifiedActiveShape() throws {
        let data = Data("""
        {
          "success": true,
          "status": "verified_active",
          "is_premium": true,
          "expiration_time": 1786281936,
          "product_id": "ekitapligim.premium.monthly",
          "transaction_id": "1000001",
          "original_transaction_id": "1000000",
          "environment": "Sandbox"
        }
        """.utf8)

        let response = try JSONDecoder.ekitapligim.decode(BillingResponseDTO.self, from: data)

        XCTAssertTrue(response.success)
        XCTAssertTrue(response.isPremium)
        XCTAssertEqual(response.expirationTime, 1786281936)
    }

    func testBlockedMembersDecodesBackendShape() throws {
        let data = Data("""
        {
          "members": [
            {
              "id": "4",
              "user_id": 4,
              "username": "Editor",
              "avatar_url": "",
              "blocked_at": null
            }
          ]
        }
        """.utf8)

        let page = try JSONDecoder.ekitapligim.decode(BlockedMembersPageDTO.self, from: data)

        XCTAssertEqual(page.members.first?.id, "4")
        XCTAssertEqual(page.members.first?.username, "Editor")
    }
}
