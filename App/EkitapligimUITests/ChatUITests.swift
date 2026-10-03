import XCTest

final class ChatUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-chat-ui-fixture", "-chat-narrow", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        if largeText { app.launchArguments.append("-chat-large-text") }
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.isHittable { return }
            if element.exists && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFullMessageWrapsWithinNarrowWidthAndAvatarNavigates() {
        let app = launch()
        let text = app.staticTexts["chat-message-81"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        reveal(text, in: app)
        XCTAssertTrue(text.label.contains("mesajın SONU burada."))
        XCTAssertLessThanOrEqual(text.frame.width, 270)
        XCTAssertGreaterThan(text.frame.height, 65)
        capture(app, name: "chat-narrow-full-message")
        let avatar = app.buttons["chat-avatar-81"]
        reveal(avatar, in: app)
        if !avatar.isHittable { app.swipeDown() }
        XCTAssertTrue(avatar.isHittable)
        avatar.tap()
        XCTAssertTrue(app.navigationBars["Ada"].waitForExistence(timeout: 5))
    }

    func testReplyContextCanBeCanceledAndReactionCanBeSelectedAndRemoved() {
        let app = launch()
        let reply = app.buttons["chat-reply-81"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        reveal(reply, in: app)
        reply.tap()
        let cancel = app.buttons["chat-cancel-reply"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.tap()
        XCTAssertFalse(cancel.exists)
        let picker = app.buttons["chat-react-81"]
        reveal(picker, in: app)
        picker.tap()
        let love = app.buttons["chat-picker-reaction-7"]
        XCTAssertTrue(love.waitForExistence(timeout: 3))
        love.tap()
        let reaction = app.buttons["chat-reaction-81-7"]
        XCTAssertTrue(reaction.waitForExistence(timeout: 3))
        reveal(reaction, in: app)
        capture(app, name: "chat-reply-and-reaction")
        reaction.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: reaction)
        wait(for: [gone], timeout: 3)
    }

    @MainActor func testLargeTextAccessibilityAndMessageWidth() throws {
        let app = launch(largeText: true)
        let message = app.staticTexts["chat-message-81"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        reveal(message, in: app)
        XCTAssertLessThanOrEqual(message.frame.width, 270)
        capture(app, name: "chat-narrow-accessibility-text")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription])
    }
}
