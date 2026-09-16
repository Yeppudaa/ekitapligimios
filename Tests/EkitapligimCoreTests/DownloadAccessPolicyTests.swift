import XCTest
@testable import EkitapligimCore

final class DownloadAccessPolicyTests: XCTestCase {
    func testMemberWithoutDownloadRightsNeedsPremiumNotLimitFull() throws {
        let access = try decodeAccess("""
        {
          "user_tier": "member",
          "can_read_online": true,
          "can_download": false,
          "denial_code": "daily_download_limit",
          "denial_message": "İndirme limitiniz dolu",
          "daily_download": {
            "limit": 0,
            "used": 0,
            "remaining": 0,
            "is_unlimited": false,
            "is_allowed": false
          }
        }
        """)

        XCTAssertEqual(
            DownloadAccessPolicy.decision(isSignedIn: true, isPremium: false, access: access),
            .premiumRequired
        )
    }

    func testPremiumUserWhoExhaustedQuotaSeesDailyLimit() throws {
        let access = try decodeAccess("""
        {
          "user_tier": "premium",
          "can_read_online": true,
          "can_download": false,
          "denial_code": "daily_download_limit",
          "denial_message": "İndirme limitiniz dolu",
          "daily_download": {
            "limit": 10,
            "used": 10,
            "remaining": 0,
            "is_unlimited": false,
            "is_allowed": false
          }
        }
        """)

        XCTAssertEqual(
            DownloadAccessPolicy.decision(isSignedIn: true, isPremium: true, access: access),
            .dailyLimitReached
        )
    }

    func testGuestMustSignIn() {
        XCTAssertEqual(
            DownloadAccessPolicy.decision(isSignedIn: false, isPremium: false, access: nil),
            .loginRequired
        )
    }

    func testAllowedDownloadPassesThrough() throws {
        let access = try decodeAccess("""
        {
          "user_tier": "premium",
          "can_read_online": true,
          "can_download": true
        }
        """)

        XCTAssertEqual(
            DownloadAccessPolicy.decision(isSignedIn: true, isPremium: true, access: access),
            .allowed
        )
    }

    private func decodeAccess(_ json: String) throws -> ReaderAccessDTO {
        try JSONDecoder.ekitapligim.decode(ReaderAccessDTO.self, from: Data(json.utf8))
    }
}
