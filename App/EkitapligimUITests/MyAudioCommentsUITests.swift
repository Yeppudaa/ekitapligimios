import XCTest

/// Run on iPhone SE, iPhone 11 and iPhone 13 simulators. Real native routes use an offline transport.
@MainActor
final class MyAudioCommentsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        if let run = testRun, run.failureCount > 0 || run.unexpectedExceptionCount > 0 {
            capture(XCUIApplication(), "audio-comments-failure")
        }
    }

    func testProfileCommentsOpenNativeAudioDetailsAndBackRetainsProfileTab() {
        let app = launch()
        defer { app.terminate() }
        openComments(in: app)
        for (postID, bookID, title) in [
            ("980001", "101", "Beyaz Zambaklar Ülkesinde"),
            ("980002", "102", "Küçük Prens")
        ] {
            let row = element("audio.comments.row.\(postID)", in: app)
            reveal(row, using: app.scrollViews["audio.comments.scroll"], in: app)
            XCTAssertTrue(row.isHittable)
            assertHorizontallyContained(row, in: app)
            row.tap()
            let detail = app.scrollViews["audio.detail"]
            XCTAssertTrue(detail.waitForExistence(timeout: 8))
            XCTAssertEqual(detail.value as? String, bookID, "A comment must open its own audio book")
            let heading = element("audio.detail.title", in: app)
            XCTAssertTrue(heading.waitForExistence(timeout: 8))
            XCTAssertEqual(heading.label, title)
            assertNativeProfileNavigation(in: app)
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.scrollViews["audio.comments.scroll"].waitForExistence(timeout: 5))
            XCTAssertTrue(row.exists, "Back must retain loaded personal comments")
        }
        capture(app, "profile-audio-comments-native-list")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.scrollViews["profile.scroll"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["primary-tab-profile"].isSelected)
        XCTAssertFalse(app.scrollViews["audio.comments.scroll"].exists)
        XCTAssertTrue(app.buttons["profile.audio.comments"].isHittable, "Back must restore the profile audio section")
    }

    func testLargeTextCommentsRemainWithinTheScreenAndBothRowsAreReachable() {
        let app = launch(largeText: true)
        defer { app.terminate() }
        openComments(in: app)
        let scroll = app.scrollViews["audio.comments.scroll"]
        for postID in ["980001", "980002"] {
            let row = element("audio.comments.row.\(postID)", in: app)
            reveal(row, using: scroll, in: app)
            XCTAssertTrue(row.isHittable, "Long audio comments must remain reachable at accessibility text sizes")
            assertHorizontallyContained(row, in: app)
            XCTAssertGreaterThanOrEqual(row.frame.height, 88, "Text must have room to grow")
            for text in row.staticTexts.allElementsBoundByIndex where text.exists {
                assertHorizontallyContained(text, in: app)
                XCTAssertGreaterThan(text.frame.height, 0)
            }
            capture(app, "audio-comments-accessibility3-\(postID)")
        }
        let second = element("audio.comments.row.980002", in: app)
        second.tap()
        XCTAssertTrue(app.scrollViews["audio.detail"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.scrollViews["audio.detail"].value as? String, "102")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        assertNativeProfileNavigation(in: app)
    }

    func testEmptyAudioHistoryShowsAnHonestNativeEmptyState() {
        let app = launch(comments: "empty")
        defer { app.terminate() }
        openComments(in: app)
        let title = app.staticTexts["Henüz sesli kitap yorumun yok"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        assertHorizontallyContained(title, in: app)
        XCTAssertFalse(element("audio.comments.row.980001", in: app).exists)
        XCTAssertFalse(element("audio.comments.row.980002", in: app).exists)
        assertNativeProfileNavigation(in: app)
        capture(app, "audio-comments-empty-native-state")
    }

    func testUnavailableAudioEndpointShowsAnErrorWithoutOpeningTheWebsite() {
        let app = launch(comments: "unavailable")
        defer { app.terminate() }
        openComments(in: app)
        let message = app.staticTexts["Sesli kitap yorumları şu anda kullanılamıyor. Lütfen daha sonra tekrar dene."]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        assertHorizontallyContained(message, in: app)
        XCTAssertFalse(element("audio.comments.row.980001", in: app).exists)
        XCTAssertFalse(app.staticTexts["Henüz sesli kitap yorumun yok"].exists,
                       "An unavailable server must not be presented as an empty personal history")
        assertNativeProfileNavigation(in: app)
        capture(app, "audio-comments-unavailable-native-state")
    }

    private func launch(largeText: Bool = false, comments: String = "normal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = "profile"
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_AUDIO_COMMENTS"] = comments
        app.launchEnvironment["MODERN_PARITY_PLAY_AUDIO"] = "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollViews["profile.scroll"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["primary-tab-profile"].isSelected)
        return app
    }

    private func openComments(in app: XCUIApplication) {
        let button = app.buttons["profile.audio.comments"]
        reveal(button, using: app.scrollViews["profile.scroll"], in: app)
        XCTAssertTrue(button.isHittable)
        assertHorizontallyContained(button, in: app)
        button.tap()
        XCTAssertTrue(app.scrollViews["audio.comments.scroll"].waitForExistence(timeout: 8),
                      "The profile button must open the native personal audio comments screen")
        XCTAssertTrue(app.navigationBars["Sesli kitap yorumlarım"].exists)
        assertNativeProfileNavigation(in: app)
    }

    private func assertNativeProfileNavigation(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["primary-tab-profile"].isSelected, file: file, line: line)
        XCTAssertTrue(app.buttons["primary-tab-home"].isHittable, file: file, line: line)
        XCTAssertTrue(app.buttons["primary-tab-profile"].isHittable, file: file, line: line)
        XCTAssertFalse(app.webViews.firstMatch.exists, "Comments must use native views", file: file, line: line)
        XCTAssertFalse(app.buttons["Kapat"].exists, "The page must retain native Back navigation", file: file, line: line)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func reveal(_ element: XCUIElement, using scroll: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<30 {
            if element.isHittable { return }
            let viewport = scroll.frame.intersection(app.frame)
            guard viewport.width > 0, viewport.height > 0 else { break }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = viewport.minX - app.frame.minX + viewport.width * 0.88
            let top = origin.withOffset(CGVector(dx: x, dy: viewport.minY - app.frame.minY + viewport.height * 0.22))
            let bottom = origin.withOffset(CGVector(dx: x, dy: viewport.minY - app.frame.minY + viewport.height * 0.80))
            if element.exists && !element.frame.isEmpty && element.frame.maxY <= viewport.minY {
                top.press(forDuration: 0.05, thenDragTo: bottom)
            } else {
                bottom.press(forDuration: 0.05, thenDragTo: top)
            }
        }
        XCTAssertTrue(element.isHittable, "The native control must be reachable by vertical scrolling")
    }

    private func assertHorizontallyContained(_ element: XCUIElement, in app: XCUIApplication,
                                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(element.frame.width, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.minX, app.frame.minX - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX + 1, file: file, line: line)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
