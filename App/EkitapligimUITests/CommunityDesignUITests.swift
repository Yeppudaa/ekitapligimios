import XCTest

@MainActor
final class CommunityDesignUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ screen: String, guest: Bool = false, largeText: Bool = false, navigation: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_GUEST"] = guest ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_SOCIAL_NAVIGATION"] = navigation ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 15))
        return app
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForMember(_ app: XCUIApplication) {
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label == %@", "Ada"),
                                               object: app.staticTexts["member.username"])
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 10), .completed)
    }

    private func assertGoogleAboveCredentials(_ app: XCUIApplication) {
        let google = app.buttons["auth.google"]
        let username = app.textFields["auth.username"]
        XCTAssertTrue(google.waitForExistence(timeout: 10))
        XCTAssertTrue(username.exists)
        XCTAssertLessThan(google.frame.maxY, username.frame.minY)
        XCTAssertGreaterThanOrEqual(google.frame.height, 53.99)
    }

    func testGuestLoginHasGoogleFirst() {
        let app = launch("profile", guest: true)
        capture(app, "guest-profile-new-design")
        let login = app.buttons["profile.guest.login"]
        reveal(login, app: app); login.tap()
        assertGoogleAboveCredentials(app)
        capture(app, "login-google-above-form")
    }

    func testGuestRegisterHasGoogleFirstWithLargeText() {
        let app = launch("profile", guest: true, largeText: true)
        let register = app.buttons["profile.guest.register"]
        reveal(register, app: app); register.tap()
        assertGoogleAboveCredentials(app)
        capture(app, "register-google-first-large-text")
    }

    func testMembersEmptySearchCanBeClearedAndProfileOpens() {
        let app = launch("members")
        let search = app.textFields["members.search"]
        reveal(search, app: app); search.tap(); search.typeText("zz-no-reader")
        let clear = app.buttons["members.clearSearch"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5)); clear.tap()
        search.typeText("\n")
        let member = app.buttons["members.member.900002"]
        reveal(member, app: app); member.tap()
        waitForMember(app)
        XCTAssertEqual(app.staticTexts["member.username"].label, "Ada")
        capture(app, "member-profile-new-design")
        let library = app.buttons["member.tab.library"]
        reveal(library, app: app); library.tap()
        capture(app, "member-public-library")
    }

    func testInboxOpensConversationAndComposer() {
        let app = launch("messages")
        let row = app.buttons["messages.conversation.980001"]
        reveal(row, app: app)
        capture(app, "messages-inbox")
        row.tap()
        XCTAssertTrue(app.scrollViews["conversation-messages-scroll"].waitForExistence(timeout: 10))
        capture(app, "messages-conversation")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let compose = app.buttons["messages.compose"]
        XCTAssertTrue(compose.waitForExistence(timeout: 5)); compose.tap()
        XCTAssertTrue(app.textViews["conversation-new-message-input"].waitForExistence(timeout: 5))
        capture(app, "messages-new-conversation")
    }

    func testLiveMemberNameOpensTheCorrectProfile() {
        let app = launch("live", navigation: true)
        let member = app.buttons["live.member.930001"]
        reveal(member, app: app); member.tap()
        waitForMember(app)
        XCTAssertEqual(app.staticTexts["member.username"].label, "Ada")
    }

    func testLiveBookCardOpensTheCorrectBook() {
        let app = launch("live", navigation: true)
        let book = app.buttons["live.book.930001"]
        reveal(book, app: app); book.tap()
        XCTAssertTrue(app.scrollViews["book-detail-scroll"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Beyaz Zambaklar Ülkesinde"].firstMatch.exists)
    }
}
