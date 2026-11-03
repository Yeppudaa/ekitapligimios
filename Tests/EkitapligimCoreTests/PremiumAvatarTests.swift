import XCTest
@testable import EkitapligimCore

final class PremiumAvatarTests: XCTestCase {
    func testVisitedMemberUsesServerPremiumFlagOrRoleType() throws {
        for payload in [
            #"{"id":1,"is_premium":true}"#,
            #"{"id":1,"is_premium":1}"#,
            #"{"id":1,"role_type":"premium"}"#,
            #"{"id":1,"role_type":"Premium"}"#,
            #"{"id":1,"role":{"is_premium":true}}"#,
            #"{"id":1,"role":{"role_type":"premium"}}"#
        ] {
            XCTAssertTrue(try member(payload).isPremium, payload)
        }
    }

    func testOrdinaryVerifiedAndStaffMembersDoNotAcquirePremiumFrame() throws {
        for payload in [
            #"{"id":2}"#,
            #"{"id":2,"is_premium":false,"role_type":"member"}"#,
            #"{"id":2,"show_verified_badge":true}"#,
            #"{"id":2,"is_staff":true,"role_type":"admin"}"#,
            #"{"id":2,"username":"Premium","user_title":"Premium Üye","role_label":"Premium Üye"}"#
        ] {
            XCTAssertFalse(try member(payload).isPremium, payload)
        }
    }

    func testMemberListKeepsDifferentMembershipsAndExistingFollowPermissions() throws {
        let payload = #"{"members":[{"id":1,"is_premium":true,"can_follow":false},{"id":2,"is_premium":false,"can_follow":true,"show_verified_badge":true}],"pagination":{"page":1,"pages":1,"total":2}}"#
        let page = try JSONDecoder.ekitapligim.decode(MembersPageDTO.self, from: Data(payload.utf8))
        XCTAssertEqual(page.members.map(\.isPremium), [true, false])
        XCTAssertEqual(page.members.map(\.canFollow), [false, true])
        XCTAssertTrue(page.members[1].showVerifiedBadge)
    }

    func testPhotoCoversInnerGoldEdgeAtEverySupportedAvatarSize() {
        for size in [40.0, 66, 76, 94, 106, 160] {
            let radius = size * PremiumAvatarAppearance.photoDiameterRatio / 2
            let innerGoldRadius = size * (PremiumAvatarAppearance.ringRadius - PremiumAvatarAppearance.ringWidth / 2) / 100
            XCTAssertGreaterThan(radius, innerGoldRadius, "A transparent seam would expose the background")
            XCTAssertLessThan(radius, size * PremiumAvatarAppearance.ringRadius / 100, "Photo must not cover the rim")
            XCTAssertLessThan(size * PremiumAvatarAppearance.photoCenterYRatio + radius, size)
        }
    }

    func testSweepHasNoIdleWindowAndWrapsContinuously() {
        let duration = PremiumAvatarAppearance.sweepDuration
        let samples = (0..<48).map { PremiumAvatarAppearance.phase(elapsed: Double($0) / 10, duration: duration) }
        for pair in zip(samples, samples.dropFirst()) { XCTAssertGreaterThan(pair.1, pair.0) }
        XCTAssertEqual(PremiumAvatarAppearance.phase(elapsed: duration, duration: duration), 0, accuracy: 0.000001)
        XCTAssertEqual(PremiumAvatarAppearance.phase(elapsed: 0.5, duration: duration),
                       PremiumAvatarAppearance.phase(elapsed: duration + 0.5, duration: duration), accuracy: 0.000001)
    }

    func testMotionStopsForReducedMotionBackgroundAndDisappearance() {
        XCTAssertTrue(PremiumAvatarAppearance.animates(isPremium: true, reduceMotion: false, sceneActive: true, visible: true))
        XCTAssertFalse(PremiumAvatarAppearance.animates(isPremium: false, reduceMotion: false, sceneActive: true, visible: true))
        XCTAssertFalse(PremiumAvatarAppearance.animates(isPremium: true, reduceMotion: true, sceneActive: true, visible: true))
        XCTAssertFalse(PremiumAvatarAppearance.animates(isPremium: true, reduceMotion: false, sceneActive: false, visible: true))
        XCTAssertFalse(PremiumAvatarAppearance.animates(isPremium: true, reduceMotion: false, sceneActive: true, visible: false))
    }

    func testInvalidClockValuesHaveDeterministicStillFrame() {
        XCTAssertEqual(PremiumAvatarAppearance.phase(elapsed: .nan, duration: 4.8), PremiumAvatarAppearance.restingPhase)
        XCTAssertEqual(PremiumAvatarAppearance.phase(elapsed: 10, duration: 0), PremiumAvatarAppearance.restingPhase)
    }

    private func member(_ json: String) throws -> MemberDTO {
        try JSONDecoder.ekitapligim.decode(MemberDTO.self, from: Data(json.utf8))
    }
}
