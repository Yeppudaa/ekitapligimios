import XCTest

final class AIAssistantUITests: XCTestCase {
    private func launch(_ mode: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ai-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment["AI_FIXTURE_MODE"] = mode
        app.launch()
        XCTAssertTrue(app.buttons["ai-send"].waitForExistence(timeout: 10))
        return app
    }
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testWelcomeKeyboardAndResponse() throws {
        let app = launch("welcome")
        capture(app, name: "ai-welcome")
        let input = app.textFields["ai-input"].exists ? app.textFields["ai-input"] : app.textViews["ai-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("Bir kitap öner")
        XCTAssertTrue(app.buttons["ai-send"].isHittable)
        capture(app, name: "ai-keyboard")
        app.buttons["ai-send"].tap()
        XCTAssertTrue(app.staticTexts["Sen"].waitForExistence(timeout: 10))
        capture(app, name: "ai-response")
    }
    func testQuotaAndConnectionErrorPreventSend() throws {
        let quota = launch("quota")
        XCTAssertFalse(quota.buttons["ai-send"].isEnabled)
        capture(quota, name: "ai-quota-exhausted"); quota.terminate()
        let error = launch("error")
        XCTAssertFalse(error.buttons["ai-send"].isEnabled)
        capture(error, name: "ai-connection-error")
    }
    func testLargeTextAndAccessibility() throws {
        let app = launch("welcome", largeText: true)
        capture(app, name: "ai-large-text")
        try app.performAccessibilityAudit(for: [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription])
    }
    func testLongAnswerKeepsComposerVisible() throws {
        let app = launch("long")
        let input = app.textFields["ai-input"].exists ? app.textFields["ai-input"] : app.textViews["ai-input"]
        input.tap(); input.typeText("Bir kitap öner")
        app.buttons["ai-send"].tap()
        XCTAssertTrue(app.staticTexts["Sen"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(app.buttons["ai-send"].isHittable)
        capture(app, name: "ai-long-response")
    }
}
