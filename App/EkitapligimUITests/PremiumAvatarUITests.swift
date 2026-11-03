import XCTest

@MainActor
final class PremiumAvatarUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ screen: String, viewerPremium: Bool, memberPremium: Bool, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_STANDARD_MEMBER"] = viewerPremium ? "0" : "1"
        app.launchEnvironment["MODERN_PARITY_PREMIUM_MEMBER"] = memberPremium ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = large ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_LONG_MEMBER_NAME"] = large ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 15))
        return app
    }

    func testOwnPremiumProfileHasBookFrameAndVerifiedUsername() {
        let app = launch("profile", viewerPremium: true, memberPremium: false)
        defer { app.terminate() }
        let frame = app.descendants(matching: .any)["premium.avatar.frame"].firstMatch
        XCTAssertTrue(frame.waitForExistence(timeout: 8))
        let name = app.staticTexts["profile.username"]
        XCTAssertEqual(name.value as? String, "Onaylı premium üye")
        capture(app, name: "own-premium-book-frame")
    }

    func testStandardViewerSeesVisitedPremiumFrameAndNameBadge() {
        let app = launch("member-profile", viewerPremium: false, memberPremium: true)
        defer { app.terminate() }
        let name = app.staticTexts["member.username"]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        XCTAssertEqual(name.label, "Ada")
        XCTAssertEqual(name.value as? String, "Onaylı premium üye")
        let frame = app.descendants(matching: .any)["premium.avatar.frame"].firstMatch
        XCTAssertTrue(frame.exists)
        XCTAssertLessThan(frame.frame.maxY, name.frame.minY + 1)
        capture(app, name: "visited-premium-book-frame")
    }

    func testPremiumViewerDoesNotGiveStandardMemberAFrame() {
        let app = launch("member-profile", viewerPremium: true, memberPremium: false)
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["member.username"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["premium.avatar.frame"].firstMatch.exists)
        XCTAssertNotEqual(app.staticTexts["member.username"].value as? String, "Onaylı premium üye")
    }

    func testPremiumMemberStillOpensFromMembersList() {
        let app = launch("members", viewerPremium: false, memberPremium: true)
        defer { app.terminate() }
        let member = app.buttons["members.member.900002"]
        for _ in 0..<8 {
            if member.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(member.isHittable)
        member.tap()
        XCTAssertTrue(app.staticTexts["member.username"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["member.username"].value as? String, "Onaylı premium üye")
    }

    func testLargePremiumNameFitsProfileWidth() {
        let app = launch("member-profile", viewerPremium: false, memberPremium: true, large: true)
        defer { app.terminate() }
        let name = app.staticTexts["member.username"]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        XCTAssertGreaterThanOrEqual(name.frame.minX, 0)
        XCTAssertLessThanOrEqual(name.frame.maxX, app.frame.maxX)
        capture(app, name: "premium-profile-large-text")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
