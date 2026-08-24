import XCTest
@testable import EkitapligimCore

/// Payload fixtures below are trimmed captures of live https://ekitapligim.com/ios-api/v1/ responses.
final class CommunityModelDecodingTests: XCTestCase {
    private let decoder = JSONDecoder.ekitapligim

    func testBookAgendaPageDecodesLivePayload() throws {
        let json = """
        {
            "items": [
                {
                    "id": "19",
                    "post_id": 19,
                    "type": "quotation",
                    "message": "Bir sevgi... Bir fedakârlık...",
                    "created_at": 1787256690,
                    "edited_at": 0,
                    "visibility": "public",
                    "is_pinned": false,
                    "is_featured": false,
                    "is_sensitive": false,
                    "review_title": "",
                    "rating": 0,
                    "page_number": "",
                    "progress_current": 0,
                    "progress_total": 0,
                    "progress_percent": 0,
                    "comment_count": 0,
                    "reaction_score": 3,
                    "repost_count": 1,
                    "bookmark_count": 0,
                    "view_count": 32,
                    "actor": {
                        "id": "1",
                        "username": "Ekitapligim",
                        "avatar_url": "https://cdn.ekitapligim.com/data/avatars/m/0/1.jpg",
                        "is_verified": true
                    },
                    "book": {
                        "id": "16698",
                        "title": "Su Tanrısının Gelini 2",
                        "author": "Rümeysa Demirkutlu",
                        "cover_url": "https://cdn.ekitapligim.com/data/books/covers/16/16698.jpg",
                        "app_route": "detail/16698",
                        "target_url": "https://ekitapligim.com/konular/su-tanrisinin-gelini-2.16698/"
                    },
                    "attachments": [],
                    "quoted_post": null,
                    "viewer": {
                        "can_react": false,
                        "can_comment": false,
                        "can_edit": false,
                        "can_delete": false,
                        "reacted": false,
                        "bookmarked": false,
                        "reposted": false,
                        "following_actor": false
                    },
                    "app_route": "book-agenda/19",
                    "target_url": "https://ekitapligim.com/kitap-gundemi/19/"
                },
                {
                    "id": "13",
                    "post_id": 13,
                    "type": "standard",
                    "message": "Yaşayışta sadelik, düşüncede ihtişam.",
                    "created_at": 1785925213,
                    "edited_at": 0,
                    "visibility": "public",
                    "page_number": 42,
                    "comment_count": 0,
                    "reaction_score": 2,
                    "book": null,
                    "attachments": [],
                    "quoted_post": null,
                    "actor": {"id": "31", "username": "Astraea", "is_verified": true},
                    "app_route": "book-agenda/13"
                }
            ],
            "tab": "agenda",
            "filter": "",
            "pagination": {"page": 1, "per_page": 5, "has_more": true, "next_page": 2},
            "capabilities": {"authenticated": false, "can_create": false, "can_upload": false}
        }
        """
        let page = try decoder.decode(BookAgendaPageDTO.self, from: Data(json.utf8))

        XCTAssertEqual(page.items.count, 2)
        XCTAssertEqual(page.tab, "agenda")
        XCTAssertEqual(page.page, 1)
        XCTAssertTrue(page.hasMore)
        XCTAssertFalse(page.canCreate)
        XCTAssertFalse(page.authenticated)

        let quotation = page.items[0]
        XCTAssertEqual(quotation.id, "19")
        XCTAssertEqual(quotation.type, "quotation")
        XCTAssertEqual(quotation.reactionScore, 3)
        XCTAssertEqual(quotation.repostCount, 1)
        XCTAssertEqual(quotation.viewCount, 32)
        XCTAssertEqual(quotation.pageNumber, 0, "An empty string page number must fall back to zero")
        XCTAssertEqual(quotation.actor.username, "Ekitapligim")
        XCTAssertTrue(quotation.actor.isVerified)
        XCTAssertEqual(quotation.book?.id, "16698")
        XCTAssertNil(quotation.quotedPost)
        XCTAssertFalse(quotation.viewer.canReact)

        let standard = page.items[1]
        XCTAssertEqual(standard.type, "standard")
        XCTAssertEqual(standard.pageNumber, 42, "A numeric page number must decode directly")
        XCTAssertNil(standard.book)
        XCTAssertEqual(standard.viewer, BookAgendaViewerDTO())
    }

    func testBookAgendaPostEnvelopeDecodesComments() throws {
        let json = """
        {
            "post": {
                "id": "12",
                "type": "standard",
                "message": "Bir kitap paylaşımı",
                "created_at": 1785835034,
                "comment_count": 1,
                "actor": {"id": "136", "username": "eliff"},
                "viewer": {"can_comment": true, "can_edit": true, "can_delete": true},
                "comments": [
                    {
                        "id": "4",
                        "comment_id": 4,
                        "message": "Ben de okumak isterim",
                        "created_at": 1785840000,
                        "reaction_score": 2,
                        "actor": {"id": "1", "username": "Ekitapligim"},
                        "viewer": {"can_edit": false, "can_delete": true}
                    }
                ]
            }
        }
        """
        let post = try decoder.decode(BookAgendaPostEnvelopeDTO.self, from: Data(json.utf8)).post

        XCTAssertEqual(post.id, "12")
        XCTAssertTrue(post.viewer.canComment)
        XCTAssertTrue(post.viewer.canDelete)
        XCTAssertEqual(post.comments.count, 1)
        XCTAssertEqual(post.comments[0].id, "4")
        XCTAssertEqual(post.comments[0].actor.username, "Ekitapligim")
        XCTAssertEqual(post.comments[0].reactionScore, 2)
        XCTAssertTrue(post.comments[0].viewer.canDelete)
    }

    func testBookAgendaActionAndFollowDecode() throws {
        let action = try decoder.decode(
            BookAgendaActionDTO.self,
            from: Data(#"{"success": true, "reacted": true, "reaction_score": 4}"#.utf8)
        )
        XCTAssertTrue(action.success)
        XCTAssertTrue(action.reacted)
        XCTAssertEqual(action.reactionScore, 4)
        XCTAssertNil(action.repostCount)

        let follow = try decoder.decode(
            BookAgendaFollowDTO.self,
            from: Data(#"{"success": true, "following": true}"#.utf8)
        )
        XCTAssertTrue(follow.following)
    }

    func testLiveActivityPageDecodesLivePayload() throws {
        let json = """
        {
            "items": [
                {
                    "id": "reading-2110",
                    "type": "reading",
                    "message": "Şəbi Gölgesiz - 2 kitabını okumaya başladı.",
                    "event_date": 1787491786,
                    "eventDate": 1787491786,
                    "actor": {
                        "id": "292",
                        "username": "Şəbi",
                        "avatar_url": "https://cdn.ekitapligim.com/data/avatars/s/0/292.jpg",
                        "avatarUrl": "https://cdn.ekitapligim.com/data/avatars/s/0/292.jpg"
                    },
                    "book": {
                        "id": "16693",
                        "title": "Gölgesiz - 2",
                        "author": "Sibel Akcan",
                        "cover_url": "https://cdn.ekitapligim.com/data/books/covers/16/16693.jpg",
                        "coverUrl": "https://cdn.ekitapligim.com/data/books/covers/16/16693.jpg"
                    },
                    "app_route": "detail/16693",
                    "appRoute": "detail/16693",
                    "target_url": "https://ekitapligim.com/konular/golgesiz-2.16693/",
                    "targetUrl": "https://ekitapligim.com/konular/golgesiz-2.16693/"
                },
                {
                    "id": "join-292",
                    "type": "join",
                    "message": "Şəbi aramıza katıldı.",
                    "event_date": 1787491711,
                    "actor": {"id": "292", "username": "Şəbi"},
                    "book": null,
                    "app_route": "member/292"
                }
            ],
            "pagination": {"limit": 3, "before": 0, "next_before": 1787490100, "has_more": true},
            "capabilities": {"can_view": true, "max_page_size": 40}
        }
        """
        let page = try decoder.decode(LiveActivityPageDTO.self, from: Data(json.utf8))

        XCTAssertEqual(page.items.count, 2)
        XCTAssertEqual(page.nextBefore, 1787490100)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.items[0].type, "reading")
        XCTAssertEqual(page.items[0].book?.title, "Gölgesiz - 2")
        XCTAssertEqual(page.items[0].appRoute, "detail/16693")
        XCTAssertNil(page.items[1].book)
        XCTAssertEqual(page.items[1].actor?.username, "Şəbi")
    }

    func testLiveActivityPageWithoutNextCursor() throws {
        let json = #"{"items": [], "pagination": {"next_before": 0, "has_more": false}}"#
        let page = try decoder.decode(LiveActivityPageDTO.self, from: Data(json.utf8))

        XCTAssertTrue(page.items.isEmpty)
        XCTAssertNil(page.nextBefore)
        XCTAssertFalse(page.hasMore)
    }

    func testChatRoomsDecodeLivePayload() throws {
        let json = """
        {
            "items": [
                {
                    "id": "1",
                    "room_id": 1,
                    "name": "Okur Sohbeti",
                    "description": "Kitaplar, yazarlar ve yeni keşifler üzerine sohbet edin.",
                    "user_count": 3,
                    "last_activity": 0,
                    "is_read_only": false,
                    "is_locked": false,
                    "is_private": false,
                    "is_joined": false,
                    "can_send": false,
                    "app_route": "chat/1",
                    "target_url": "https://ekitapligim.com/chat/room/okur-sohbeti.1/"
                }
            ],
            "rooms": [],
            "capabilities": {"authenticated": false, "can_use": false, "push_available": true}
        }
        """
        let rooms = try decoder.decode(ChatRoomsDTO.self, from: Data(json.utf8))

        XCTAssertEqual(rooms.rooms.count, 1)
        XCTAssertEqual(rooms.rooms[0].id, "1")
        XCTAssertEqual(rooms.rooms[0].name, "Okur Sohbeti")
        XCTAssertEqual(rooms.rooms[0].userCount, 3)
        XCTAssertFalse(rooms.rooms[0].canSend)
        XCTAssertFalse(rooms.capabilities.canUse)
        XCTAssertTrue(rooms.capabilities.pushAvailable)
    }

    func testChatMessagesPageDecodesLivePayload() throws {
        let json = """
        {
            "room": {"id": "1", "room_id": 1, "name": "Okur Sohbeti", "can_send": true},
            "items": [
                {
                    "id": "435",
                    "message_id": 435,
                    "room_id": 1,
                    "user_id": 1,
                    "username": "Ekitapligim",
                    "message": "Üyeliğiniz aktif edildi. İyi okumalar",
                    "message_type": "chat",
                    "message_date": 1786749552,
                    "avatar_url": "https://cdn.ekitapligim.com/data/avatars/m/0/1.jpg",
                    "is_mine": false,
                    "is_bot": false,
                    "is_announcement": false,
                    "is_edited": false,
                    "is_admin": true,
                    "is_moderator": true,
                    "is_staff": true
                }
            ],
            "pagination": {"oldest_id": 435, "newest_id": 469, "has_more": true}
        }
        """
        let page = try decoder.decode(ChatMessagesPageDTO.self, from: Data(json.utf8))

        XCTAssertEqual(page.room?.name, "Okur Sohbeti")
        XCTAssertEqual(page.messages.count, 1)
        XCTAssertEqual(page.messages[0].id, "435")
        XCTAssertEqual(page.messages[0].roomId, "1")
        XCTAssertEqual(page.messages[0].userId, "1")
        XCTAssertTrue(page.messages[0].isAdmin)
        XCTAssertFalse(page.messages[0].isMine)
        XCTAssertEqual(page.oldestId, "435")
        XCTAssertEqual(page.newestId, "469")
        XCTAssertTrue(page.hasMore)
    }

    func testChatMessageEnvelopeAcceptsWrappedAndBarePayloads() throws {
        let wrapped = try decoder.decode(
            ChatMessageEnvelopeDTO.self,
            from: Data(#"{"message": {"id": "470", "username": "Okur", "message": "Merhaba", "message_date": 1786749999}}"#.utf8)
        )
        XCTAssertEqual(wrapped.message.id, "470")
        XCTAssertEqual(wrapped.message.message, "Merhaba")

        let bare = try decoder.decode(
            ChatMessageEnvelopeDTO.self,
            from: Data(#"{"id": "471", "username": "Okur", "message": "Selam", "message_date": 1786750000}"#.utf8)
        )
        XCTAssertEqual(bare.message.id, "471")
        XCTAssertEqual(bare.message.message, "Selam")
    }

    func testReadingStatsDecodeAndDerivedValues() throws {
        let json = """
        {
            "daily_goal_minutes": 45,
            "total_seconds": 8100,
            "total_pages": 320,
            "streak_count": 4,
            "today_seconds": 900,
            "today_pages": 22,
            "goal_completed": false,
            "goal_progress_percent": 33
        }
        """
        let stats = try decoder.decode(ReadingStatsDTO.self, from: Data(json.utf8))

        XCTAssertEqual(stats.dailyGoalMinutes, 45)
        XCTAssertEqual(stats.todayMinutes, 15)
        XCTAssertEqual(stats.totalMinutes, 135)
        XCTAssertEqual(stats.remainingMinutes, 30)
        XCTAssertEqual(stats.streakCount, 4)
        XCTAssertEqual(stats.goalProgressPercent, 33)
        XCTAssertFalse(stats.goalCompleted)
    }

    func testReadingStatsComputesProgressWhenServerOmitsIt() throws {
        let json = #"{"daily_goal_minutes": 60, "today_seconds": 1800}"#
        let stats = try decoder.decode(ReadingStatsDTO.self, from: Data(json.utf8))

        XCTAssertEqual(stats.goalProgressPercent, 50)
        XCTAssertEqual(stats.remainingMinutes, 30)
    }

    func testProfileDecodesRoleReadingStatsAndBadges() throws {
        let json = """
        {
            "id": "1",
            "user_id": 1,
            "username": "Ekitapligim",
            "email": "info@ekitapligim.com",
            "title": "Yönetici",
            "custom_title": "",
            "user_title": "E-Kitaplığım üyesi",
            "avatar_url": "https://cdn.ekitapligim.com/data/avatars/m/0/1.jpg",
            "banner_url": "https://cdn.ekitapligim.com/data/profile_banners/l/0/1.jpg",
            "can_upload_avatar": true,
            "can_upload_banner": true,
            "message_count": 15507,
            "reaction_score": 34,
            "trophy_points": 48,
            "register_date": 1747699200,
            "last_activity": 1787491786,
            "is_staff": true,
            "can_edit": true,
            "about": "Ekitapligim.Com",
            "signature": "",
            "location": "",
            "website": "https://ekitapligim.com/",
            "timezone": "Europe/Istanbul",
            "activity_visible": true,
            "earned_badges": [
                {
                    "id": "reading_daily_goal",
                    "title": "Günlük Hedef Rozeti",
                    "description": "Günlük okuma hedefini tamamladın.",
                    "points": 10,
                    "award_date": 1787400000
                }
            ],
            "reading_stats": {
                "daily_goal_minutes": 45,
                "total_seconds": 0,
                "total_pages": 0,
                "streak_count": 0,
                "today_seconds": 0,
                "today_pages": 0,
                "goal_completed": false,
                "goal_progress_percent": 0
            },
            "role": {
                "role_label": "Admin",
                "role_type": "admin",
                "show_verified_badge": true,
                "is_admin": true,
                "is_moderator": false,
                "is_premium": true
            }
        }
        """
        let profile = try decoder.decode(ProfileDTO.self, from: Data(json.utf8))

        XCTAssertEqual(profile.id, "1")
        XCTAssertEqual(profile.username, "Ekitapligim")
        XCTAssertEqual(profile.messageCount, 15507)
        XCTAssertEqual(profile.reactionScore, 34)
        XCTAssertEqual(profile.trophyPoints, 48)
        XCTAssertEqual(profile.bannerUrl?.isEmpty, false)
        XCTAssertTrue(profile.isAdmin)
        XCTAssertTrue(profile.isPremium)
        XCTAssertFalse(profile.isModerator)
        XCTAssertEqual(profile.role?.roleLabel, "Admin")
        XCTAssertEqual(profile.readingStats?.dailyGoalMinutes, 45)
        XCTAssertEqual(profile.badges.count, 1)
        XCTAssertEqual(profile.badges[0].title, "Günlük Hedef Rozeti")
        XCTAssertEqual(profile.displayTitle, "Yönetici")
        XCTAssertEqual(profile.activityVisible, true)
    }

    func testProfileDecodesMinimalPayload() throws {
        let profile = try decoder.decode(
            ProfileDTO.self,
            from: Data(#"{"id": "9", "username": "Okur", "email": "okur@example.com"}"#.utf8)
        )

        XCTAssertEqual(profile.username, "Okur")
        XCTAssertFalse(profile.isAdmin)
        XCTAssertNil(profile.role)
        XCTAssertNil(profile.readingStats)
        XCTAssertTrue(profile.badges.isEmpty)
        XCTAssertNil(profile.displayTitle)
    }

    func testProfileMediaDecodes() throws {
        let media = try decoder.decode(
            ProfileMediaDTO.self,
            from: Data(#"{"success": true, "avatar_url": "https://cdn.ekitapligim.com/data/avatars/m/0/1.jpg"}"#.utf8)
        )
        XCTAssertTrue(media.success)
        XCTAssertNotNil(media.avatarUrl)
        XCTAssertNil(media.bannerUrl)
    }

    func testBookAgendaPostUpdatingPreservesFieldsAndCommentCount() throws {
        let page = try decoder.decode(
            BookAgendaPageDTO.self,
            from: Data(
                """
                {"items":[{"id":"19","type":"standard","message":"Test","comment_count":2,"reaction_score":1,"repost_count":0,"bookmark_count":0,"view_count":1,"actor":{"id":"1","username":"u"},"attachments":[],"viewer":{}}],"has_more":false}
                """.utf8
            )
        )
        let original = try XCTUnwrap(page.items.first)
        let updated = original.updating(commentCount: 3)

        XCTAssertEqual(updated.commentCount, 3)
        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.message, original.message)
        XCTAssertEqual(updated.reactionScore, original.reactionScore)
    }
}
