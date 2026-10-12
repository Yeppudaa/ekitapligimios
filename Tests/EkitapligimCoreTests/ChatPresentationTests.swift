import XCTest
@testable import EkitapligimCore

final class ChatPresentationTests: XCTestCase {
    private func message(_ fields: [String: Any] = [:]) throws -> ChatMessageDTO {
        let payload: [String: Any] = ["id": 81, "room_id": 4, "user_id": 9,
                                      "username": "Ada", "message": "Selam"]
            .merging(fields) { _, new in new }
        return try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self,
            from: JSONSerialization.data(withJSONObject: payload))
    }

    func testLegacySenderStaysPlainAndPremiumMetadataIsPresentationOnly() throws {
        let legacy = try message()
        XCTAssertFalse(legacy.hasPremiumUsername)
        XCTAssertEqual(legacy.profileMemberID, "9")
        XCTAssertNil(legacy.linkedAnnouncementMember)
        for fields: [String: Any] in [["is_premium": true], ["is_premium": "1"], ["role_type": " Premium "]] {
            let premium = try message(fields)
            XCTAssertTrue(premium.hasPremiumUsername)
            XCTAssertEqual(premium.profileMemberID, legacy.profileMemberID)
            XCTAssertEqual(premium.message, legacy.message)
            XCTAssertEqual(premium.canQuote, legacy.canQuote)
            XCTAssertEqual(premium.canReact, legacy.canReact)
        }
    }

    func testStaffAndSyntheticMessagesNeverReceivePremiumDecoration() throws {
        for key in ["is_admin", "is_moderator", "is_staff", "is_bot", "is_announcement"] {
            XCTAssertFalse(try message(["is_premium": true, key: true]).hasPremiumUsername, key)
        }
        for role in ["admin", "moderator", " STAFF "] {
            XCTAssertFalse(try message(["is_premium": true, "role_type": role]).hasPremiumUsername, role)
        }
    }

    func testProfileLinksRejectBotsAnnouncementsAndInvalidSenderIDs() throws {
        for id in ["0", "-2", "someone", "9223372036854775808"] {
            XCTAssertNil(try message(["user_id": id]).profileMemberID)
        }
        XCTAssertNil(try message(["is_bot": true]).profileMemberID)
        XCTAssertNil(try message(["is_announcement": true]).profileMemberID)
        XCTAssertEqual(try message(["user_id": "009"]).profileMemberID, "9")
    }

    func testAnnouncementUsesOnlyExplicitMemberAndDoesNotDuplicateName() throws {
        let member: [String: Any] = ["user_id": "25", "username": "Deniz", "body": "👑 Premium üyeliğe yükseldi."]
        let linked = try message(["is_announcement": true, "user_id": 1,
                                  "message": "Deniz 👑 Premium üyeliğe yükseldi.", "announcement_member": member])
        XCTAssertEqual(linked.linkedAnnouncementMember?.userId, "25")
        XCTAssertEqual(linked.linkedAnnouncementMember?.username, "Deniz")
        XCTAssertEqual(linked.linkedAnnouncementMember?.body, "👑 Premium üyeliğe yükseldi.")
        XCTAssertNil(linked.profileMemberID)
        XCTAssertNil(try message(["announcement_member": member]).linkedAnnouncementMember)
        XCTAssertNil(try message(["is_bot": true, "is_announcement": true, "announcement_member": member]).linkedAnnouncementMember)
        let legacy = try message(["is_announcement": true, "message": "Ada Premium üyeliğe yükseldi."])
        XCTAssertNil(legacy.linkedAnnouncementMember)
        XCTAssertEqual(legacy.message, "Ada Premium üyeliğe yükseldi.")
    }

    func testMalformedAnnouncementMetadataFallsBackToCompleteReadableText() throws {
        for member: [String: Any] in [["user_id": 0, "username": "Ada", "body": "Metin"],
                                     ["user_id": 9, "username": " ", "body": "Metin"],
                                     ["user_id": 9, "username": "Ada", "body": " "],
                                     ["user_id": 9, "username": "Ada"],
                                     ["user_id": [9], "username": "Ada", "body": "Metin"]] {
            let decoded = try message(["is_announcement": true, "announcement_member": member])
            XCTAssertNil(decoded.linkedAnnouncementMember)
            XCTAssertEqual(decoded.message, "Selam")
        }
    }
}
