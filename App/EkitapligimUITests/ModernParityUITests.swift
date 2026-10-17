import XCTest

/// Run the same suite on iPhone SE, a current iPhone and iPad simulators. The DEBUG host injects
/// offline read-only payloads into real shipping screens; this suite never purchases or signs in.
@MainActor
final class ModernParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws { XCUIDevice.shared.orientation = .portrait }

    private func launch(_ screen: String, largeText: Bool = false, dark: Bool = false, guest: Bool = false, standardMember: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DARK"] = dark ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_GUEST"] = guest ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_STANDARD_MEMBER"] = standardMember ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 10), "The offline screen did not become ready: \(screen)")
        XCTAssertFalse(app.staticTexts["modern-parity-error"].exists)
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            if element.exists && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
    }

    private func assertContained(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(element.frame.width, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.minX, app.frame.minX - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX + 1, file: file, line: line)
    }

    func testEveryRefreshedNativeScreenRendersWithNormalText() {
        for screen in ["home", "catalog", "library", "profile", "requests", "forum", "threads", "authors", "publishers", "agenda", "live", "chat", "audio", "audio-detail", "audio-library", "notifications"] {
            let app = launch(screen)
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 10), "Expected native scroll content on \(screen)")
            capture(app, "modern-\(screen)-portrait")
            app.swipeUp()
            capture(app, "modern-\(screen)-scrolled")
            XCTAssertFalse(app.alerts.firstMatch.exists, "An unexpected failure alert appeared on \(screen)")
            app.terminate()
        }
    }

    func testCommunityAndLibraryStayUsableAtAccessibilityTextSizeInLandscape() throws {
        for screen in ["requests", "forum", "authors", "library", "profile", "chat", "audio", "audio-detail", "audio-library", "notifications"] {
            let app = launch(screen, largeText: true, dark: true)
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 8))
            capture(app, "modern-\(screen)-landscape-accessibility3-dark")
            app.swipeUp()
            capture(app, "modern-\(screen)-landscape-accessibility3-scrolled")
            XCTAssertFalse(app.alerts.firstMatch.exists)
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
    }

    func testMenuHeaderAndCloseRemainPinnedWhileSectionsScroll() throws {
        let app = launch("menu", largeText: true)
        let menu = app.buttons["Menü"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let close = app.buttons["modern-menu-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let origin = close.frame.minY
        let list = app.scrollViews["modern-menu-scroll"]
        XCTAssertTrue(list.exists)
        list.swipeUp()
        list.swipeUp()
        XCTAssertTrue(close.isHittable)
        XCTAssertEqual(close.frame.minY, origin, accuracy: 2)
        assertContained(close, in: app)
        capture(app, "modern-menu-pinned-close-accessibility3")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription])
        close.tap()
        XCTAssertFalse(close.exists)
    }

    func testChatTranscriptScrollDoesNotMoveItsHeaderOrExposeRemovedRoomTabs() {
        let app = launch("chat")
        let header = app.otherElements["chat-pinned-header"]
        XCTAssertTrue(header.waitForExistence(timeout: 8))
        let origin = header.frame.minY
        let message = app.staticTexts["chat-message-920024"]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        app.scrollViews.firstMatch.swipeDown()
        app.scrollViews.firstMatch.swipeDown()
        XCTAssertEqual(header.frame.minY, origin, accuracy: 2)
        assertContained(header, in: app)
        XCTAssertFalse(app.buttons["Yeni Kitaplar"].exists)
        capture(app, "modern-chat-fixed-header-scrolled-messages")
    }

    func testAudiobookFiltersStartClosedAndCanBeOpenedAndClosed() {
        let app = launch("audio")
        let toggle = app.buttons["audio.filter.toggle"]
        reveal(toggle, in: app)
        XCTAssertTrue(toggle.isHittable)
        XCTAssertEqual(toggle.value as? String, "Filtreler kapalı")
        XCTAssertFalse(app.textFields["audio.filter.query"].exists)
        toggle.tap()
        let query = app.textFields["audio.filter.query"]
        XCTAssertTrue(query.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.value as? String, "Filtreler açık")
        capture(app, "modern-audio-filters-expanded")
        toggle.tap()
        XCTAssertFalse(query.exists)
        XCTAssertEqual(toggle.value as? String, "Filtreler kapalı")
    }

    func testNonPremiumAudiobookListenShowsAccessMessageWithoutStartingPurchase() {
        let app = launch("audio-detail", standardMember: true)
        let listen = app.buttons["Sesli dinle"]
        reveal(listen, in: app)
        XCTAssertTrue(listen.isHittable)
        listen.tap()
        XCTAssertTrue(app.staticTexts["Hikâyeler sana seslensin."].waitForExistence(timeout: 5))
        let message = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Sadece Premium üyeler sesli kitap dinleyebilir")).firstMatch
        XCTAssertTrue(message.exists)
        capture(app, "modern-audio-premium-explanation")
        // No Premium purchase, authentication, restore, or media manifest action is invoked.
        app.buttons["Şimdi değil"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["audio.detail"].exists)
    }

    func testLibraryArtworkAndActualShelfNavigationRemainReachable() {
        let app = launch("library", largeText: true)
        let hero = app.otherElements["library.scenicHero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        assertContained(hero, in: app)
        let nextShelf = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Daha sonra oku")).firstMatch
        reveal(nextShelf, in: app)
        XCTAssertTrue(nextShelf.isHittable)
        nextShelf.tap()
        let book = app.staticTexts["Yeni Bir Hikâye"]
        reveal(book, in: app)
        XCTAssertTrue(book.isHittable)
        capture(app, "modern-library-shelf-navigation-accessibility3")
    }

    func testProfileAudiobookLibraryOpensThroughActualApplicationRouting() {
        let app = launch("profile")
        let library = app.buttons["Sesli Kitaplığım"].firstMatch
        reveal(library, in: app)
        XCTAssertTrue(library.isHittable)
        library.tap()
        let destination = app.descendants(matching: .any)["audio.library"].firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Dinleme yolculuğun"].exists)
        capture(app, "modern-profile-to-audiobook-library-native-route")
    }

    func testNotificationsReadPermissionStatusWithoutAutomaticallyRequestingPermission() {
        let app = launch("notifications", largeText: true)
        let settings = app.buttons["notifications.delivery.settings"]
        reveal(settings, in: app)
        XCTAssertTrue(settings.isHittable)
        assertContained(settings, in: app)
        XCTAssertFalse(app.alerts.firstMatch.exists, "Opening notifications must never prompt for permission automatically")
        let notification = app.buttons["notification-970001"]
        reveal(notification, in: app)
        XCTAssertTrue(notification.isHittable)
        assertContained(notification, in: app)
        capture(app, "modern-notification-permission-card-and-unread-event")
        // Reading permission and rendering the list do not request permission or mark alerts read.
    }
}
