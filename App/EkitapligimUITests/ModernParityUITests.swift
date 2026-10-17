import XCTest

/// Run the same suite on iPhone SE, a current iPhone and iPad simulators. The DEBUG host injects
/// offline payloads into real shipping screens; only explicitly enabled local audio manifests/progress
/// can be written to the fixture transport. This suite never purchases, signs in or mutates a server.
@MainActor
final class ModernParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 900
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws { XCUIDevice.shared.orientation = .portrait }

    private func launch(_ screen: String, largeText: Bool = false, dark: Bool = false, guest: Bool = false, standardMember: Bool = false, playAudio: Bool = false, catalogFailure: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DARK"] = dark ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_GUEST"] = guest ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_STANDARD_MEMBER"] = standardMember ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_PLAY_AUDIO"] = playAudio ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_CATALOG_FAILURE"] = catalogFailure ? "1" : "0"
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
        for screen in ["home", "catalog", "library", "profile", "requests", "forum", "threads", "authors", "publishers", "agenda", "live", "chat", "audio", "audio-detail", "audio-library", "audio-player", "notifications"] {
            let app = launch(screen)
            if screen == "audio-player" { XCTAssertTrue(app.buttons["Duraklat"].firstMatch.waitForExistence(timeout: 15), "The local native audio fixture did not become ready") }
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 10), "Expected native scroll content on \(screen)")
            capture(app, "modern-\(screen)-portrait")
            app.swipeUp()
            capture(app, "modern-\(screen)-scrolled")
            XCTAssertFalse(app.alerts.firstMatch.exists, "An unexpected failure alert appeared on \(screen)")
            app.terminate()
        }
    }

    func testHomeLowerScenicSectionsRemainReachableAndContained() {
        let app = launch("home")
        let promo = app.buttons["home.promo.explore"].firstMatch
        reveal(promo, in: app)
        XCTAssertTrue(promo.isHittable)
        assertContained(promo, in: app)
        capture(app, "modern-home-paired-scenic-promotions")
        let category = app.buttons["home.categoryShowcase.6"].firstMatch
        reveal(category, in: app)
        XCTAssertTrue(category.isHittable)
        assertContained(category, in: app)
        capture(app, "modern-home-scenic-category-showcase")
        let library = app.buttons["home.libraryBanner.open"].firstMatch
        reveal(library, in: app)
        XCTAssertTrue(library.isHittable)
        assertContained(library, in: app)
        capture(app, "modern-home-personal-library-footer")
    }

    func testHomeGenreOpensFilteredCatalogAndReturnsToHomeInTheSameNavigationStack() {
        let app = launch("home")
        let genre = app.buttons["home.genre.6"].firstMatch
        reveal(genre, in: app)
        XCTAssertTrue(genre.isHittable)
        genre.tap()
        let catalogHero = app.descendants(matching: .any)["catalog.scenicHero"].firstMatch
        XCTAssertTrue(catalogHero.waitForExistence(timeout: 10))
        capture(app, "modern-home-genre-native-catalog")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.isHittable)
        back.tap()
        XCTAssertTrue(app.buttons["home.genre.6"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(catalogHero.exists)
    }

    func testCommunityAndLibraryStayUsableAtAccessibilityTextSizeInLandscape() throws {
        for screen in ["home", "catalog", "library", "profile", "requests", "forum", "threads", "authors", "publishers", "agenda", "live", "chat", "audio", "audio-detail", "audio-library", "audio-player", "notifications"] {
            let app = launch(screen, largeText: true, dark: true)
            if screen == "audio-player" { XCTAssertTrue(app.buttons["Duraklat"].firstMatch.waitForExistence(timeout: 15)) }
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

    func testFailedCatalogCategoryChangeRemovesOldResultsAndRetryUsesTheNewCategory() {
        let app = launch("catalog", catalogFailure: true)
        let oldBook = app.buttons["catalog.book.900041"]
        reveal(oldBook, in: app)
        XCTAssertTrue(oldBook.waitForExistence(timeout: 8))
        let categories = app.scrollViews["catalog.categories"]
        reveal(categories, in: app)
        XCTAssertTrue(categories.isHittable)
        let category = app.buttons["catalog.category.35"]
        for _ in 0..<12 {
            if category.isHittable { break }
            categories.swipeLeft()
        }
        XCTAssertTrue(category.isHittable)
        category.tap()
        let retry = app.buttons["catalog.retry"]
        reveal(retry, in: app)
        XCTAssertTrue(retry.waitForExistence(timeout: 8), "A failed category reset must show an error instead of the old results")
        capture(app, "modern-catalog-category-failure-without-stale-results")
        retry.tap()
        let newBook = app.buttons["catalog.book.900140"]
        reveal(newBook, in: app)
        XCTAssertTrue(newBook.waitForExistence(timeout: 8))
        XCTAssertFalse(oldBook.exists, "Old category results must never be mixed with the retried category")
        capture(app, "modern-catalog-category-retry-recovered")
    }

    func testNonPremiumAudiobookListenShowsAccessMessageWithoutStartingPurchase() {
        let app = launch("audio-detail", standardMember: true)
        let listen = app.buttons["audio.detail.listen"]
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

    func testProfileFavoriteShelfAndDetailBackNavigationKeepTheChosenShelf() {
        let app = launch("profile")
        let favorites = app.buttons["profile.ebook.shelf.3"]
        reveal(favorites, in: app)
        XCTAssertTrue(favorites.isHittable)
        favorites.tap()
        let selectedShelf = app.buttons["library.shelf.3"]
        XCTAssertTrue(selectedShelf.waitForExistence(timeout: 8))
        XCTAssertTrue(selectedShelf.isSelected, "The profile's Favorites route must not open the Reading shelf")
        let book = app.buttons["library.book.900042"]
        reveal(book, in: app)
        XCTAssertTrue(book.isHittable)
        book.tap()
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 8))
        back.tap()
        XCTAssertTrue(selectedShelf.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedShelf.isSelected, "Returning from book details must retain the selected shelf")
        capture(app, "modern-profile-favorites-retained-after-book-detail")
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

    func testNativeFullAudioPlayerRendersReadyCoverChaptersAndVisibleControls() {
        let app = launch("audio-player")
        let player = app.descendants(matching: .any)["audio.player"].firstMatch
        XCTAssertTrue(player.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Duraklat"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Beyaz Zambaklar Ülkesinde"].firstMatch.exists)
        capture(app, "modern-native-audio-player-ready-cover")
        let rewind = app.buttons["15 saniye geri"].firstMatch
        reveal(rewind, in: app)
        XCTAssertTrue(rewind.isHittable)
        assertContained(rewind, in: app)
        let forward = app.buttons["15 saniye ileri"].firstMatch
        XCTAssertTrue(forward.isHittable)
        assertContained(forward, in: app)
        let settings = app.buttons["Dinleme ayarları"].firstMatch
        reveal(settings, in: app)
        XCTAssertTrue(settings.isHittable)
        settings.tap()
        XCTAssertTrue(app.staticTexts["Uyku zamanlayıcısı"].firstMatch.waitForExistence(timeout: 5))
        capture(app, "modern-native-audio-player-settings")
        app.buttons["Bitti"].tap()
        let chapter = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Birinci Bölüm · Yerel test kaydı")).firstMatch
        reveal(chapter, in: app)
        XCTAssertTrue(chapter.isHittable)
        capture(app, "modern-native-audio-player-chapters")
        XCTAssertEqual(app.buttons.matching(identifier: "audio.mini.close").count, 0, "Full player must not display a duplicate mini player")
    }

    func testAudioAnnotationTextRemainsVisibleAndEditableInDarkAppearance() {
        let app = launch("audio-player", dark: true)
        XCTAssertTrue(app.buttons["Duraklat"].firstMatch.waitForExistence(timeout: 15))
        let note = app.buttons["Not ekle"].firstMatch
        reveal(note, in: app)
        XCTAssertTrue(note.isHittable)
        note.tap()
        let editor = app.textViews["audio.annotation.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        let text = "Bu hikâyede yeni bir dünya buldum."
        editor.typeText(text)
        XCTAssertTrue((editor.value as? String)?.contains(text) == true)
        assertContained(editor, in: app)
        capture(app, "modern-audio-annotation-typed-text-dark")
        app.buttons["Vazgeç"].firstMatch.tap()
        XCTAssertFalse(editor.exists)
        // Typing and cancelling never writes an annotation, even to the offline transport.
    }

    func testSingleMiniPlayerPersistsAcrossActualRootNavigationAndClosesAudio() {
        let app = launch("home", playAudio: true)
        let closeQuery = app.buttons.matching(identifier: "audio.mini.close")
        XCTAssertTrue(closeQuery.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Duraklat"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(closeQuery.count, 1)
        for tab in ["primary-tab-catalog", "primary-tab-profile", "primary-tab-home"] {
            let destination = app.buttons[tab]
            XCTAssertTrue(destination.isHittable)
            destination.tap()
            XCTAssertTrue(closeQuery.firstMatch.waitForExistence(timeout: 5))
            XCTAssertEqual(closeQuery.count, 1, "Navigation created a second mini player")
        }
        capture(app, "modern-single-mini-player-root-navigation")
        app.buttons["Oynatıcıyı aç"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["audio.player"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Duraklat"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(closeQuery.count, 0)
        app.buttons["Oynatıcıyı küçült"].firstMatch.tap()
        XCTAssertTrue(closeQuery.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(closeQuery.count, 1)
        closeQuery.firstMatch.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: closeQuery.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        XCTAssertFalse(app.buttons["Duraklat"].exists)
        app.buttons["primary-tab-catalog"].tap()
        XCTAssertEqual(closeQuery.count, 0, "A closed player must not reappear after navigation")
        capture(app, "modern-mini-player-closed-after-navigation")
    }
}
