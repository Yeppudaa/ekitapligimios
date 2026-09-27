import XCTest

final class GiftWheelUITests: XCTestCase {
    private func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-gift-wheel-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["WHEEL_FIXTURE_MODE"] = mode
        app.launch()
        XCTAssertTrue(app.buttons["gift-wheel-spin"].waitForExistence(timeout: 5))
        return app
    }
    private func scrollToAction(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["gift-wheel-spin"]
        for _ in 0..<6 {
            if button.isHittable { return button }
            app.swipeUp()
        }
        return button
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testGuestReferenceLayout() {
        let app = launch("guest")
        capture(app, "gift-wheel-guest-hero")
        let button = scrollToAction(app)
        XCTAssertEqual(button.label, "Giriş yap ve şansını dene")
        XCTAssertTrue(button.isEnabled)
        capture(app, "gift-wheel-guest-card")
    }
    func testFullTenSecondSpinThenServerAward() {
        let app = launch("ready")
        let button = scrollToAction(app)
        XCTAssertTrue(button.isEnabled)
        let start = ProcessInfo.processInfo.systemUptime
        button.tap()
        let result = app.descendants(matching: .any)["gift-wheel-result"].firstMatch
        let tooEarly = expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: result)
        tooEarly.isInverted = true
        wait(for: [tooEarly], timeout: 9)
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - start, 10)
        XCTAssertTrue(app.staticTexts["✦  7 GÜN PREMIUM  ✦"].exists)
        capture(app, "gift-wheel-award")
    }
    func testQuotaAndFailureAreActionable() {
        var app = launch("quota")
        XCTAssertFalse(scrollToAction(app).isEnabled)
        capture(app, "gift-wheel-quota")
        app.terminate()
        app = launch("error")
        let retry = scrollToAction(app)
        XCTAssertEqual(retry.label, "Tekrar yükle")
        XCTAssertTrue(retry.isEnabled)
        XCTAssertTrue(app.staticTexts["gift-wheel-error"].exists)
        capture(app, "gift-wheel-error")
    }
    @MainActor func testAccessibilityAudit() throws {
        let app = launch("guest")
        try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription])
    }
}
