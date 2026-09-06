import XCTest

final class AIAssistantUITests: XCTestCase {
    func testAdaptiveTabsCompactCardsAndLauncher() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ai-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["AI_FIXTURE_MODE"] = "layout"
        app.launch()
        let launcher = app.buttons["ai-launcher"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 10))
        let tabs = ["home", "catalog", "agenda", "flow", "requests", "profile"].map {
            app.buttons["primary-tab-\($0)"]
        }
        let width = tabs[0].frame.width
        for tab in tabs {
            XCTAssertTrue(tab.isHittable)
            XCTAssertEqual(tab.frame.width, width, accuracy: 1)
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44)
        }
        XCTAssertLessThan(tabs[0].frame.minX, 12)
        XCTAssertGreaterThan(tabs[5].frame.maxX, app.frame.width - 12)
        let shortCard = app.descendants(matching: .any)["layout-card-1"].firstMatch
        let longCard = app.descendants(matching: .any)["layout-card-2"].firstMatch
        XCTAssertEqual(longCard.frame.height, shortCard.frame.height, accuracy: 2)
        XCTAssertEqual(longCard.frame.width, shortCard.frame.width, accuracy: 2)
        XCTAssertTrue(app.buttons["agenda-author-1"].exists)
        capture(app, name: "layout-tabs-and-agenda")

        let expandedWidth = launcher.frame.width
        let start = launcher.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 65, dy: 0)))
        let collapsed = NSPredicate(format: "value == %@", "Küçültülmüş")
        expectation(for: collapsed, evaluatedWith: launcher)
        waitForExpectations(timeout: 3)
        XCTAssertLessThan(launcher.frame.width, expandedWidth - 40)
        tabs[1].tap()
        XCTAssertEqual(launcher.value as? String, "Küçültülmüş")
        capture(app, name: "layout-collapsed-launcher")
        launcher.tap()
        XCTAssertTrue(app.buttons["ai-send"].waitForExistence(timeout: 5))
        app.buttons["layout-close-assistant"].tap()
        XCTAssertTrue(launcher.waitForExistence(timeout: 5))
        XCTAssertEqual(launcher.value as? String, "Genişletilmiş")
    }

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
        XCTAssertTrue(app.staticTexts["ai-user-message"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.staticTexts["ai-assistant-message"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(app.buttons["ai-send"].isHittable)
        capture(app, name: "ai-long-response")
    }
}
