import XCTest
@testable import EkitapligimCore

/// VIP Premium parity with Android and safety of the one-time App Store VIP product.
final class VipPremiumTests: XCTestCase {
    private let vip = PremiumProductCatalog.vipID
    private let lifetime = PremiumProductCatalog.lifetimeID
    private let monthly = "com.ekitapligim.app.premium.monthly"

    // MARK: Membership identity

    func testTierWireValuesMatchAndroid() {
        XCTAssertEqual(MembershipTier.fromWire("vip_supporter"), .vip)
        XCTAssertEqual(MembershipTier.fromWire("premium"), .premium)
        XCTAssertEqual(MembershipTier.fromWire(" Premium "), .premium)
        XCTAssertEqual(MembershipTier.fromWire("member"), .member)
        XCTAssertEqual(MembershipTier.fromWire(nil), .member)
        XCTAssertEqual(MembershipTier.vip.namePrefix, "💎 ")
        XCTAssertEqual(MembershipTier.premium.namePrefix, "👑 ")
        XCTAssertEqual(MembershipTier.member.namePrefix, "")
    }

    // MARK: Purchase safety

    func testVipIsNeverPartOfTheExistingPlanCatalog() {
        XCTAssertFalse(PremiumProductCatalog.productIDs.contains(vip))
        XCTAssertFalse(PremiumProductCatalog.legacyProductIDs.contains(vip))
        XCTAssertEqual(PremiumProductCatalog.productIDs.count, 5)
        XCTAssertTrue(PremiumProductCatalog.isLifetime(vip))
        XCTAssertTrue(PremiumProductCatalog.isLifetime(lifetime))
        XCTAssertFalse(PremiumProductCatalog.isLifetime(monthly))
        XCTAssertNil(PremiumProductCatalog.subscriptionMonths(for: vip))
    }

    func testVipCannotChargeUntilServerExplicitlySupportsIt() throws {
        XCTAssertFalse(PremiumProductCatalog.canPurchase(vip, context: try context("")))
        XCTAssertFalse(PremiumProductCatalog.canPurchase(vip, context: try context(",\"supported_product_ids\":[]")))
        XCTAssertFalse(PremiumProductCatalog.canPurchase(vip,
            context: try context(",\"supported_product_ids\":[\"\(lifetime)\"]")))
        XCTAssertTrue(PremiumProductCatalog.canPurchase(vip,
            context: try context(",\"supported_product_ids\":[\"\(vip)\"]")))
        let failed = PurchaseAccountDTO(success: false, appAccountToken: UUID(), supportedProductIds: [vip])
        XCTAssertFalse(PremiumProductCatalog.canPurchase(vip, context: failed))
    }

    func testExistingPlansKeepTheirPreviousAvailability() throws {
        let old = try context("")
        XCTAssertTrue(PremiumProductCatalog.canPurchase(monthly, context: old))
        XCTAssertTrue(PremiumProductCatalog.canPurchase(lifetime, context: old))
        XCTAssertFalse(PremiumProductCatalog.canPurchase("com.ekitapligim.app.premium.quarterly", context: old))
    }

    func testOfferDecisionsForVip() throws {
        let none = try context("")
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: vip, context: none, entitlement: .none), .allowed)
        // Lifetime Premium members may upgrade without a warning.
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: vip,
            context: try context(",\"has_lifetime\":true"), entitlement: .none), .allowed)
        // A renewing Apple subscription is not cancelled by the one-time payment.
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: vip,
            context: try context(",\"has_active_subscription\":true"), entitlement: .none), .warnExistingSubscription)
        // Fixed-term access is kept; no warning is needed.
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: vip,
            context: try context(",\"has_fixed_term\":true"), entitlement: .none), .allowed)
        // VIP owners are never charged again for anything.
        let owner = try context(",\"has_vip_supporter\":true")
        for id in PremiumProductCatalog.productIDs + [vip] {
            XCTAssertEqual(PurchaseOfferPolicy.decision(productID: id, context: owner, entitlement: .none), .alreadyVip)
        }
    }

    func testVipEntitlementFallbackWhenServerOmitsTheFlag() throws {
        let entitlement = PremiumEntitlement(productID: vip, expiration: nil, renewalState: .active)
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: vip, context: try context(""), entitlement: entitlement), .alreadyVip)
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: monthly, context: try context(""), entitlement: entitlement), .alreadyVip)
        XCTAssertNil(PurchaseOfferPolicy.displayedExpiration(entitlement: entitlement, serverExpiration: 123))
    }

    func testLifetimeDecisionsAreUnchangedForExistingPlans() throws {
        let lifetimeOwner = try context(",\"has_lifetime\":true")
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: monthly, context: lifetimeOwner, entitlement: .none), .alreadyLifetime)
        XCTAssertEqual(PurchaseOfferPolicy.decision(productID: lifetime, context: lifetimeOwner, entitlement: .none), .alreadyLifetime)
    }

    func testVerifiedVipWithoutExpirationIsActive() throws {
        let response = try JSONDecoder.ekitapligim.decode(BillingResponseDTO.self,
            from: Data(#"{"success":true,"is_premium":true,"expiration_time":null}"#.utf8))
        XCTAssertNil(try PurchaseVerificationPolicy.requireActive(response, productID: vip))
        XCTAssertNil(try PurchaseVerificationPolicy.requireActive(response, productID: lifetime))
        XCTAssertThrowsError(try PurchaseVerificationPolicy.requireActive(response, productID: monthly))
    }

    func testPurchaseContextDecodesVipFlag() throws {
        XCTAssertEqual(try context(",\"has_vip_supporter\":true").hasVipSupporter, true)
        XCTAssertNil(try context("").hasVipSupporter)
    }

    // MARK: Decoding

    func testChatMessageVipFlags() throws {
        let message = try decode(ChatMessageDTO.self, #"{"id":1,"room_id":1,"user_id":5,"username":"a","message":"m","is_premium":true,"is_vip_supporter":true,"is_vip_announcement":false}"#)
        XCTAssertTrue(message.isVipSupporter)
        XCTAssertFalse(message.isVipAnnouncement)
        let old = try decode(ChatMessageDTO.self, #"{"id":2,"room_id":1,"user_id":5,"username":"a","message":"m"}"#)
        XCTAssertFalse(old.isVipSupporter)
        XCTAssertFalse(old.isVipAnnouncement)
        let notice = try decode(ChatMessageDTO.self, #"{"id":3,"room_id":1,"user_id":0,"username":"a","message":"m","is_announcement":true,"is_vip_announcement":1}"#)
        XCTAssertTrue(notice.isVipAnnouncement)
    }

    func testLiveActivityTiersAndRecentMembers() throws {
        let page = try decode(LiveActivityPageDTO.self, #"""
        {"items":[
          {"id":"a","type":"vip","message":"","event_date":1,"actor":{"id":"7","username":"Ada"}},
          {"id":"b","type":"reading","message":"x","event_date":1,"actor":{"id":"8","username":"Bo","membership_tier":"premium"}},
          {"id":"c","type":"premium","message":"y","event_date":1,"actor":{"id":"9","username":"Cy","membership_tier":"member"}}
        ],
        "recent_premium_members":[
          {"id":"7","username":"Ada","avatar_url":"","membership_tier":"vip_supporter"},
          {"id":"8","username":"Bo","membership_tier":"premium"},
          {"id":"9","username":"","membership_tier":"premium"}
        ],
        "pagination":{"next_before":5,"has_more":true}}
        """#)
        XCTAssertEqual(page.items.map(\.actorTier), [.vip, .premium, .member])
        XCTAssertEqual(page.items.first?.message, "Ada VIP PREMIUM üyeliğe yükseldi. ✨")
        XCTAssertEqual(page.recentPremiumMembers.map(\.membershipTier), [.vip, .premium])
        XCTAssertEqual(page.nextBefore, 5)
        let old = try decode(LiveActivityPageDTO.self, #"{"items":[]}"#)
        XCTAssertTrue(old.recentPremiumMembers.isEmpty)
    }

    func testAgendaActorTier() throws {
        XCTAssertEqual(try decode(BookAgendaActorDTO.self, #"{"id":"1","username":"a","membership_tier":"vip_supporter"}"#).membershipTier, .vip)
        XCTAssertEqual(try decode(BookAgendaActorDTO.self, #"{"id":"1","username":"a"}"#).membershipTier, .member)
    }

    func testMemberVipFromTopLevelOrRole() throws {
        let top = try decode(MemberDTO.self, #"{"id":"1","username":"a","is_premium":true,"is_vip_supporter":true}"#)
        XCTAssertEqual(top.membershipTier, .vip)
        let nested = try decode(MemberDTO.self, #"{"id":"1","username":"a","role":{"is_premium":true,"is_vip_supporter":true}}"#)
        XCTAssertEqual(nested.membershipTier, .vip)
        let premium = try decode(MemberDTO.self, #"{"id":"1","username":"a","is_premium":true}"#)
        XCTAssertEqual(premium.membershipTier, .premium)
    }

    func testMemberProfileUploadedBannerOnly() throws {
        let profile = try decode(MemberProfileDTO.self, #"{"member":{"id":"1","username":"a","banner_url":"https://e/b.jpg"}}"#)
        XCTAssertEqual(profile.bannerUrl, "https://e/b.jpg")
        let empty = try decode(MemberProfileDTO.self, #"{"member":{"id":"1","username":"a","banner_url":"  "}}"#)
        XCTAssertNil(empty.bannerUrl)
    }

    func testSubscriptionAndProfileVipFlags() throws {
        XCTAssertTrue(try decode(SubscriptionDTO.self, #"{"is_premium":true,"is_vip_supporter":true}"#).isVipSupporter)
        XCTAssertFalse(try decode(SubscriptionDTO.self, #"{"is_premium":true}"#).isVipSupporter)
        XCTAssertTrue(try decode(ProfileDTO.self, #"{"id":"1","username":"a","role":{"is_vip_supporter":true}}"#).isVipSupporter)
    }

    private func context(_ fields: String) throws -> PurchaseAccountDTO {
        try JSONDecoder.ekitapligim.decode(PurchaseAccountDTO.self, from: Data(
            ("{\"success\":true,\"app_account_token\":\"9249ceaa-60dd-4a61-917b-0057f22818aa\"" + fields + "}").utf8))
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.ekitapligim.decode(T.self, from: Data(json.utf8))
    }
}
