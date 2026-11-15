import XCTest

@MainActor
final class ReadingRoomUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testOlderMessagesMergeAndPrivateAttachmentOpens() {
        let app = launch("messages", richMessages: true)
        defer { app.terminate() }
        let conversation = app.buttons["messages.conversation.980001"]
        XCTAssertTrue(conversation.waitForExistence(timeout: 10)); conversation.tap()
        let earlier = app.buttons["messages.earlier"]
        XCTAssertTrue(earlier.waitForExistence(timeout: 10)); earlier.tap()
        XCTAssertTrue(app.staticTexts["Önceki sayfadaki mesaj."].waitForExistence(timeout: 10))
        XCTAssertFalse(earlier.exists)
        let image = app.buttons["messages.image.21"]
        reveal(image, in: app); image.tap()
        XCTAssertTrue(app.images["messages.photo.loaded"].waitForExistence(timeout: 10))
        capture(app, "reading-room-private-attachment")
    }

    func testBookPreviewOpensNativeDetailWithoutEnteringConversation() {
        let app = launch("messages", richMessages: true)
        defer { app.terminate() }
        let card = app.buttons["messages.preview.book.900002"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        reveal(card, in: app)
        XCTAssertFalse(card.label.contains("EMBED"))
        capture(app, "reading-room-inbox-book")
        card.tap()
        XCTAssertTrue(app.scrollViews["book-detail-scroll"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.scrollViews["conversation-messages-scroll"].exists)
    }

    func testMembershipExplanationClosesBackToRequestsWithoutOpeningPurchase() {
        let app = launch("requests", access: "membership")
        defer { app.terminate() }
        let create = app.buttons["requests.create.open"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); create.tap()
        let primary = app.buttons["requests.access.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        XCTAssertEqual(primary.label, "Premium’u keşfet")
        capture(app, "reading-room-request-membership")
        app.buttons["requests.access.close"].tap()
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["requests.create.title"].exists)
    }

    func testExhaustedQuotaShowsRealRenewalAndCatalogActionWithLargeDarkText() {
        let app = launch("requests", access: "exhausted", large: true)
        defer { app.terminate() }
        let create = app.buttons["requests.create.open"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); create.tap()
        let primary = app.buttons["requests.access.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        XCTAssertEqual(primary.label, "Kitapları keşfet")
        XCTAssertGreaterThanOrEqual(primary.frame.height, 44)
        XCTAssertGreaterThanOrEqual(primary.frame.minX, 0)
        XCTAssertLessThanOrEqual(primary.frame.maxX, app.frame.maxX)
        let renewal = app.descendants(matching: .any)["requests.access.renewal"].firstMatch
        reveal(renewal, in: app)
        XCTAssertTrue(renewal.label.contains("2026"))
        XCTAssertFalse(app.buttons["Premium’u keşfet"].exists)
        capture(app, "reading-room-request-quota-large-dark")
    }

    private func launch(_ screen: String, access: String = "", large: Bool = false, richMessages: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["READING_ROOM_REQUEST_ACCESS"] = access
        app.launchEnvironment["READING_ROOM_RICH_MESSAGES"] = richMessages ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = large ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DARK"] = large ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 15))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Reading-room element is not reachable: \(element.identifier)")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
