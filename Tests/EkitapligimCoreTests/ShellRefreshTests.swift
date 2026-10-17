import XCTest
@testable import EkitapligimCore

final class ShellRefreshTests: XCTestCase {
    func testGuestNeverSeesCachedMembershipDetails() {
        let state = PremiumMenuPresentation(isSignedIn: false, isPremium: true, remainingDays: 30)
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.detail, .promotion)
    }

    func testLiveMembershipDaysArePresentedWithoutInventingExpiry() {
        XCTAssertEqual(PremiumMenuPresentation(isSignedIn: true, isPremium: true, remainingDays: 19).detail, .days(19))
        for days: Int? in [nil, 0, -1] {
            XCTAssertEqual(PremiumMenuPresentation(isSignedIn: true, isPremium: true, remainingDays: days).detail, .active)
        }
        XCTAssertEqual(PremiumMenuPresentation(isSignedIn: true, isPremium: false, remainingDays: 40).detail, .promotion)
    }

    func testSelectionKeepsAudioAndEbookDestinationsSeparate() {
        XCTAssertTrue(ShellMenuSelection.matches(item: .audiobooks, current: .audiobook(27693)))
        XCTAssertTrue(ShellMenuSelection.matches(item: .audiobooks, current: .audioLibrary(tab: "favorite")))
        XCTAssertTrue(ShellMenuSelection.matches(item: .catalog, current: .reader(12)))
        XCTAssertFalse(ShellMenuSelection.matches(item: .catalog, current: .audiobook(12)))
        XCTAssertFalse(ShellMenuSelection.matches(item: .members, current: .messages))
        XCTAssertEqual(ShellMenuSelection.badge(130), "99+")
        XCTAssertEqual(ShellMenuSelection.badge(7), "7")
        XCTAssertNil(ShellMenuSelection.badge(0))
    }

    func testAllAndroidAudioLibraryTabsRoundTrip() {
        let parser = DeepLinkParser()
        for tab in ["saved", "listening", "completed", "later", "favorite", "history"] {
            let route = AppRoute.audioLibrary(tab: tab)
            XCTAssertTrue(route.requiresAuthentication)
            XCTAssertEqual(parser.parseNativeRoute(route.nativeRoute), route)
            XCTAssertEqual(parser.parse("https://ekitapligim.com/sesli-kitaplar/library/?tab=\(tab)"), route)
        }
        XCTAssertEqual(parser.parseNativeRoute("audiobooks/library"), .audioLibrary(tab: "saved"))
        XCTAssertFalse(AppRoute.audiobook(27693).requiresAuthentication)
    }

    func testAudioLinksRejectInvalidAndOverflowIdentifiers() {
        let parser = DeepLinkParser()
        XCTAssertEqual(parser.parse("https://ekitapligim.com/sesli-kitaplar/27693/"), .audiobook(27693))
        XCTAssertEqual(parser.parseNativeRoute("audiobooks"), .audiobooks)
        for route in ["audiobook/0", "audiobook/-4", "audiobook/999999999999999999999", "audiobook/4/extra", "audiobooks/library/fake", "audio-player/1"] {
            XCTAssertNil(parser.parseNativeRoute(route), route)
        }
        for link in ["http://ekitapligim.com/sesli-kitaplar/1", "https://evil.example/sesli-kitaplar/1", "https://ekitapligim.com:9443/sesli-kitaplar/1", "https://x@ekitapligim.com/sesli-kitaplar/1", "https://ekitapligim.com/sesli-kitaplar/library?tab=later&tab=favorite"] {
            XCTAssertNil(parser.parse(link), link)
        }
    }

    func testAudioActivityMissingNativeRouteNeverOpensEbookWithSameID() throws {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        for type in ActivityPresentation.audioTypes {
            let json = """
            {"id":"audio_99","type":"\(type)","message":"activity","audio_book_id":"27693","book":{"id":27693,"title":"Beyaz Zambaklar Ülkesinde"},"app_route":"detail/27693"}
            """
            let item = try decoder.decode(LiveActivityItemDTO.self, from: Data(json.utf8))
            XCTAssertEqual(item.nativeDestination, .audiobook(27693))
        }
    }

    func testLegacyAudioActivityUsesBookAndSafeWebRouteFallbacks() throws {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let withBook = try decoder.decode(LiveActivityItemDTO.self, from: Data(#"{"id":"a1","type":"audio_started","book":{"id":"24","title":"Book"}}"#.utf8))
        XCTAssertEqual(withBook.nativeDestination, .audiobook(24))
        let withoutId = try decoder.decode(LiveActivityItemDTO.self, from: Data(#"{"id":"a2","type":"audio_started","app_route":"detail/7","target_url":"https://evil.example/sesli-kitaplar/7"}"#.utf8))
        XCTAssertNil(withoutId.nativeDestination)
        let withLink = try decoder.decode(LiveActivityItemDTO.self, from: Data(#"{"id":"a3","type":"audio_completed","target_url":"https://ekitapligim.com/sesli-kitaplar/31/"}"#.utf8))
        XCTAssertEqual(withLink.nativeDestination, .audiobook(31))
    }

    func testPremiumActivityNormalizationDoesNotRewriteActualMessages() {
        XCTAssertEqual(ActivityPresentation.message(type: "reading", rawMessage: "Original", username: "A"), "Original")
        XCTAssertEqual(ActivityPresentation.message(type: "premium", rawMessage: "6 month plan", username: "A"), "6 month plan")
        let repaired = ActivityPresentation.message(type: "premium", rawMessage: "Kitap Gündemi'nde bir paylaşım yaptı", username: "TestReader")
        XCTAssertTrue(repaired.contains("TestReader"))
        XCTAssertFalse(repaired.contains("Kitap Gündemi"))
    }
}
