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

    override func tearDownWithError() throws {
        if let run = testRun, run.failureCount > 0 || run.unexpectedExceptionCount > 0 {
            attachFailureDiagnostics(XCUIApplication(), name: "native-ui-failure")
        }
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ screen: String, largeText: Bool = false, dark: Bool = false, guest: Bool = false, standardMember: Bool = false, playAudio: Bool = false, catalogFailure: Bool = false, longAgenda: Bool = false, traceAudioDetail: Bool = false, cardSizing: Bool = false, categoryForums: String = "normal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DARK"] = dark ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_GUEST"] = guest ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_STANDARD_MEMBER"] = standardMember ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_PLAY_AUDIO"] = playAudio ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_CATALOG_FAILURE"] = catalogFailure ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_LONG_AGENDA"] = longAgenda ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DETAIL_TRACE"] = traceAudioDetail ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_CARD_SIZING"] = cardSizing ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_CATEGORY_FORUMS"] = categoryForums
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

    private func captureDevice(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForStableLandscapeGeometry(_ app: XCUIApplication, screen: String) async -> Bool {
        let deadline = Date().addingTimeInterval(15)
        var previousAppFrame = CGRect.null
        var previousWindowFrame = CGRect.null
        var stableSamples = 0
        while Date() < deadline && !Task.isCancelled {
            let appFrame = app.frame
            let window = app.windows.firstMatch
            let windowFrame = window.exists ? window.frame : .zero
            let landscape = XCUIDevice.shared.orientation == .landscapeLeft &&
                appFrame.width > appFrame.height && appFrame.height > 0 &&
                windowFrame.width > windowFrame.height && windowFrame.height > 0
            let sameBounds = abs(appFrame.minX - windowFrame.minX) <= 1 &&
                abs(appFrame.minY - windowFrame.minY) <= 1 &&
                abs(appFrame.width - windowFrame.width) <= 1 && abs(appFrame.height - windowFrame.height) <= 1
            if landscape && sameBounds && appFrame == previousAppFrame && windowFrame == previousWindowFrame {
                stableSamples += 1
            } else {
                stableSamples = 0
            }
            print("LANDSCAPE_GEOMETRY screen=\(screen),app=\(appFrame),window=\(windowFrame),landscape=\(landscape),stableSamples=\(stableSamples)")
            if stableSamples >= 2 { return true }
            previousAppFrame = appFrame
            previousWindowFrame = windowFrame
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        // Preserve both actual rasters on failure; never rotate, crop or fill missing pixels.
        captureDevice("modern-\(screen)-landscape-geometry-failure-device")
        attachFailureDiagnostics(app, name: "modern-\(screen)-landscape-geometry-failure-app")
        return false
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, towardStart: Bool = false) {
        // Bind vertical gestures to the page, rather than a nested horizontal carousel. LazyVStack
        // can report an existing, not-yet-laid-out child with a zero frame; that is not "above us".
        let viewport = ["agenda.composer.scroll", "home.scroll", "catalog.scroll", "notifications.list", "audio.catalog"]
            .map { app.scrollViews[$0] }.first(where: { $0.exists }) ?? app.scrollViews.firstMatch
        guard viewport.waitForExistence(timeout: 5) else {
            attachFailureDiagnostics(app, name: "reveal-missing-viewport")
            return
        }
        for step in 0..<24 {
            if element.isHittable { return }
            let bounds = viewport.frame.intersection(app.frame)
            let exists = element.exists
            let frame = exists ? element.frame : .zero
            let hasFrame = !frame.isEmpty && !frame.isNull && !frame.isInfinite
            let identifier = exists ? element.identifier : "not-instantiated"
            print("UI_REVEAL step=\(step),identifier=\(identifier),exists=\(exists),frame=\(frame),viewport=\(bounds),hittable=\(element.isHittable)")
            guard bounds.width > 0, bounds.height > 0 else { break }
            // A lazy child above the current page can disappear from AX entirely. A caller that
            // knows the target precedes the current content can still choose the correct direction.
            let needsDown = hasFrame ? frame.maxY <= bounds.minY : towardStart
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = bounds.minX - app.frame.minX + bounds.width * 0.88
            let top = origin.withOffset(CGVector(dx: x, dy: bounds.minY - app.frame.minY + bounds.height * 0.18))
            let bottom = origin.withOffset(CGVector(dx: x, dy: bounds.minY - app.frame.minY + bounds.height * 0.85))
            if needsDown { top.press(forDuration: 0.05, thenDragTo: bottom) }
            else { bottom.press(forDuration: 0.05, thenDragTo: top) }
        }
        if !element.isHittable { attachFailureDiagnostics(app, name: "reveal-unreachable") }
    }

    private func attachFailureDiagnostics(_ app: XCUIApplication, name: String) {
        capture(app, name)
        // These tests run only the explicit offline fixture. Never attach a real account's tree.
        let tree = XCTAttachment(string: String(app.debugDescription.prefix(40_000)))
        tree.name = name + "-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }

    private func revealCatalogCategory(_ element: XCUIElement, in app: XCUIApplication) -> CGRect {
        // A short category chip must be fully exposed before the ordinary element tap. XCUI
        // can report a partially obscured chip as hittable beneath navigation/search chrome.
        let viewport = app.scrollViews["catalog.scroll"]
        guard viewport.waitForExistence(timeout: 5) else {
            attachFailureDiagnostics(app, name: "catalog-category-missing-viewport")
            XCTFail("The catalog scroll viewport must exist before revealing a category")
            return .zero
        }
        func valid(_ frame: CGRect) -> Bool {
            !frame.isEmpty && !frame.isNull && !frame.isInfinite &&
                frame.minX.isFinite && frame.minY.isFinite && frame.maxX.isFinite && frame.maxY.isFinite
        }
        func usableBounds() -> CGRect {
            let bounds = viewport.frame.intersection(app.frame)
            guard valid(bounds) else { return .zero }
            var top = bounds.minY
            var bottom = bounds.maxY
            for bar in app.navigationBars.allElementsBoundByIndex where bar.exists {
                let frame = bar.frame
                if valid(frame), frame.intersects(bounds), frame.midY < bounds.midY {
                    top = max(top, frame.maxY)
                }
            }
            let primaryTabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "primary-tab-"))
            for button in primaryTabs.allElementsBoundByIndex where button.exists {
                let frame = button.frame
                if valid(frame), frame.intersects(bounds), frame.midY > bounds.midY {
                    bottom = min(bottom, frame.minY)
                }
            }
            // Newer iOS navigation layouts can place the catalog search field at the bottom.
            for field in app.searchFields.allElementsBoundByIndex where field.exists && field.isHittable {
                let frame = field.frame
                if valid(frame), frame.intersects(bounds), frame.midY > bounds.midY {
                    bottom = min(bottom, frame.minY)
                }
            }
            guard bottom > top + 8 else { return .zero }
            return CGRect(x: bounds.minX, y: top, width: bounds.width, height: bottom - top)
                .insetBy(dx: 4, dy: 4)
        }
        for attempt in 0...8 {
            let usable = usableBounds()
            let exists = element.exists
            let frame = exists ? element.frame : .zero
            let hittable = exists && element.isHittable
            print("CATALOG_CATEGORY_REVEAL attempt=\(attempt),exists=\(exists),frame=\(frame),usable=\(usable),hittable=\(hittable)")
            if valid(usable), valid(frame), frame.height >= 44, usable.contains(frame), hittable {
                return usable
            }
            guard attempt < 8, valid(usable) else { break }
            let towardStart = !valid(frame) || frame.minY < usable.minY
            let distance = min(CGFloat(140), usable.height * 0.30)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = usable.minX - app.frame.minX + usable.width * 0.80
            let middleY = usable.midY - app.frame.minY
            let upper = origin.withOffset(CGVector(dx: x, dy: middleY - distance / 2))
            let lower = origin.withOffset(CGVector(dx: x, dy: middleY + distance / 2))
            if towardStart { upper.press(forDuration: 0.05, thenDragTo: lower) }
            else { lower.press(forDuration: 0.05, thenDragTo: upper) }
        }
        attachFailureDiagnostics(app, name: "catalog-category-not-fully-visible")
        XCTFail("The complete 44-point category control must be visible outside navigation, search and tab chrome")
        return usableBounds()
    }

    private func assertContained(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(element.frame.width, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.minX, app.frame.minX - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX + 1, file: file, line: line)
    }

    private func openAudiobookCatalogFromMenu(in app: XCUIApplication) {
        let menu = app.buttons["Menü"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let list = app.scrollViews["modern-menu-scroll"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let audio = app.buttons["modern-menu-audiobooks"]
        for _ in 0..<8 {
            if audio.isHittable { break }
            list.swipeUp()
        }
        XCTAssertTrue(audio.isHittable)
        audio.tap()
        XCTAssertTrue(app.scrollViews["audio.catalog"].waitForExistence(timeout: 8))
    }

    private func assertAudioPageUsesNativeNavigation(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.buttons["Kapat"].exists, "Audio pages must use native Back instead of a sheet close button", file: file, line: line)
        for tab in ["home", "catalog", "agenda", "flow", "requests", "profile"] {
            XCTAssertTrue(app.buttons["primary-tab-\(tab)"].isHittable, "The bottom tabs must remain available on an audio page", file: file, line: line)
        }
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.isHittable, "A pushed audio page must expose the native Back action", file: file, line: line)
        XCTAssertNotEqual(back.identifier, "audio.catalog.library", "The library action cannot substitute for native Back", file: file, line: line)
    }

    func testA00AudioDetailAppSwipeReachesItsChapterWithoutPlayback() {
        executionTimeAllowance = 90
        checkAudioDetailScroll(reproduceAppSwipe: true)
    }

    func testA01AudioDetailTargetedDragReachesItsChapterWithoutPlayback() {
        executionTimeAllowance = 90
        checkAudioDetailScroll(reproduceAppSwipe: false)
    }

    private func checkAudioDetailScroll(reproduceAppSwipe: Bool) {
        // Use the real detail screen and its normal non-listenable payload. No manifest/player is
        // started: this isolates the scrolling stall from the separately tested native AVPlayer.
        let app = launch("audio-detail", playAudio: false, traceAudioDetail: true)
        defer { app.terminate() }
        let mode = reproduceAppSwipe ? "app-swipe" : "targeted-drag"
        XCTAssertEqual(app.launchEnvironment["MODERN_PARITY_PLAY_AUDIO"], "0")
        XCTAssertTrue(app.buttons["audio.detail.listen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["audio.player"].exists)
        let viewport = app.scrollViews["audio.detail"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 5), "The real outer detail scroll view must be identifiable")
        capture(app, "modern-audio-detail-\(mode)-before-scroll")
        let chapter = app.buttons["audio.detail.chapter.1010"]
        for step in 0..<8 {
            // Always execute the first gesture, including on a tall iPad where the chapter may
            // already be partially visible. Later queries bound the amount of scrolling.
            if step > 0 {
                print("AUDIO_DETAIL_UI mode=\(mode) step=\(step) phase=chapter-query.begin")
                let reached = chapter.isHittable
                print("AUDIO_DETAIL_UI mode=\(mode) step=\(step) phase=chapter-query.end reached=\(reached)")
                if reached { break }
            }
            print("AUDIO_DETAIL_UI mode=\(mode) step=\(step) phase=gesture.begin")
            if reproduceAppSwipe {
                // Retain the exact gesture that stalled in the full normal-screen smoke test.
                app.swipeUp()
            } else {
                let bounds = viewport.frame.intersection(app.frame)
                XCTAssertGreaterThan(bounds.width, 0)
                XCTAssertGreaterThan(bounds.height, 0)
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let x = bounds.minX - app.frame.minX + bounds.width * 0.88
                let top = origin.withOffset(CGVector(dx: x, dy: bounds.minY - app.frame.minY + bounds.height * 0.25))
                let bottom = origin.withOffset(CGVector(dx: x, dy: bounds.minY - app.frame.minY + bounds.height * 0.80))
                bottom.press(forDuration: 0.05, thenDragTo: top)
            }
            print("AUDIO_DETAIL_UI mode=\(mode) step=\(step) phase=gesture.returned")
        }
        XCTAssertTrue(chapter.isHittable, "The real chapter action must remain reachable without starting playback")
        assertContained(chapter, in: app)
        let anchors = app.descendants(matching: .any)["audio.detail.anchors"].firstMatch
        XCTAssertTrue(anchors.exists)
        assertContained(anchors, in: app)
        XCTAssertFalse(app.descendants(matching: .any)["audio.player"].exists)
        capture(app, "modern-audio-detail-\(mode)-chapter-reached")
    }

    func testEveryRefreshedNativeScreenRendersWithNormalText() {
        // Keep playback last so a real AVPlayer failure cannot suppress other page evidence.
        for screen in ["home", "catalog", "library", "profile", "requests", "forum", "threads", "authors", "publishers", "agenda", "live", "chat", "audio", "audio-detail", "audio-library", "notifications", "audio-player"] {
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

    func testHomeGenreShowcaseKeepsAndroidCategoriesWhenForumsAreUnavailableOrUnrelated() {
        let categories = [("6", "Roman"), ("7", "Edebiyat"), ("8", "Eğitim"), ("9", "Bilim"),
                          ("10", "Tarih"), ("11", "Din"), ("12", "Psikoloji"), ("13", "Kişisel Gelişim")]
        for state in ["empty", "failure", "unrelated"] {
            let app = launch("home", categoryForums: state)
            defer { app.terminate() }
            let roman = app.buttons["home.categoryShowcase.6"].firstMatch
            reveal(roman, in: app)
            XCTAssertTrue(roman.isHittable, "Roman must remain visible with \(state) forum metadata")
            assertContained(roman, in: app)
            var previousFrame: CGRect?
            for (id, title) in categories {
                let category = app.buttons["home.categoryShowcase.\(id)"].firstMatch
                XCTAssertTrue(category.exists, "The \(title) category must remain present with \(state) forum metadata")
                XCTAssertTrue(category.label.contains(title))
                let frame = category.frame
                XCTAssertGreaterThan(frame.width, 0, "Every eager category must have an actual layout frame")
                XCTAssertGreaterThan(frame.height, 0)
                if let previousFrame {
                    XCTAssertGreaterThanOrEqual(frame.minX, previousFrame.maxX - 1,
                                               "Home categories must retain Android's horizontal taxonomy order")
                }
                previousFrame = frame
            }
            XCTAssertFalse(app.staticTexts["Bütün türleri katalogda keşfet."].exists,
                           "Missing forum metadata must not replace available genres with the empty message")
            capture(app, "modern-home-genre-showcase-forums-\(state)")
            roman.tap()
            let selectedCategory = app.buttons["catalog.category.6"].firstMatch
            XCTAssertTrue(selectedCategory.waitForExistence(timeout: 8), "Roman must open the native category catalog")
            XCTAssertTrue(selectedCategory.isSelected, "The opened catalog must select the tapped Roman category")
            capture(app, "modern-home-roman-catalog-forums-\(state)")
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.isHittable, "The category catalog must expose native Back navigation")
            back.tap()
            XCTAssertTrue(app.scrollViews["home.scroll"].waitForExistence(timeout: 5))
            reveal(roman, in: app)
            XCTAssertTrue(roman.isHittable, "Native Back must restore the reachable Home genre showcase")
            capture(app, "modern-home-genre-showcase-return-forums-\(state)")
        }
    }

    func testHomeNewArrivalCardsRemainVisibleAndOpenNativeBookDetails() {
        for largeText in [false, true] {
            let app = launch("home", largeText: largeText, cardSizing: !largeText)
            let firstBook = app.buttons["home.bookRail.newest.book.900041"]
            reveal(firstBook, in: app)
            XCTAssertTrue(firstBook.isHittable, "A loaded newest-book card must be visible beneath its heading")
            XCTAssertGreaterThan(firstBook.frame.height, 100, "The horizontal rail must retain its actual card height")
            assertContained(firstBook, in: app)
            if !largeText {
                let secondBook = app.buttons["home.bookRail.newest.book.900042"]
                XCTAssertTrue(secondBook.waitForExistence(timeout: 5), "The next real book card must be laid out in the same rail")
                XCTAssertGreaterThan(secondBook.frame.height, 100)
                XCTAssertEqual(firstBook.frame.width, secondBook.frame.width, accuracy: 1,
                    "Different book titles must retain the same card width")
                XCTAssertEqual(firstBook.frame.height, secondBook.frame.height, accuracy: 1,
                    "Different book titles must retain the same card height")
            }
            capture(app, largeText ? "modern-home-newest-cards-accessibility3" : "modern-home-newest-cards-normal")
            firstBook.tap()
            XCTAssertTrue(app.staticTexts["Sonsuzluğun Büyüsü"].firstMatch.waitForExistence(timeout: 8), "The selected newest book must open its own native detail")
            let back = app.buttons["book.detail.back"]
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.tap()
            XCTAssertTrue(firstBook.waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    func testHomeAgendaRailKeepsDifferentContentAtEqualCardDimensions() {
        let app = launch("home", longAgenda: true)
        defer { app.terminate() }
        let firstCard = app.descendants(matching: .any)["home.agenda.940001"].firstMatch
        let firstOpen = app.buttons["agenda.open.940001"]
        reveal(firstOpen, in: app)
        XCTAssertTrue(firstOpen.isHittable)
        XCTAssertTrue(firstCard.exists)
        let secondCard = app.descendants(matching: .any)["home.agenda.940002"].firstMatch
        XCTAssertTrue(secondCard.waitForExistence(timeout: 5), "Both eager agenda cards must have their real layout frames")
        XCTAssertGreaterThan(firstCard.frame.height, 100)
        XCTAssertGreaterThan(secondCard.frame.height, 100)
        XCTAssertEqual(firstCard.frame.width, secondCard.frame.width, accuracy: 1,
            "A long review and a short note must use equal rail card widths")
        XCTAssertEqual(firstCard.frame.height, secondCard.frame.height, accuracy: 1,
            "A long review and a short note must share the tallest card's natural height")
        capture(app, "modern-home-agenda-equal-card-dimensions")
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

    func testRefreshedScreensCaptureSmokeEvidenceAtAccessibilityTextSizeInLandscape() async throws {
        // This collects visual evidence; per-feature tests assert actual control reachability.
        for screen in ["home", "catalog", "library", "profile", "requests", "forum", "threads", "authors", "publishers", "agenda", "live", "chat", "audio", "audio-detail", "audio-library", "notifications", "audio-player"] {
            let app = launch(screen, largeText: true, dark: true)
            if screen == "audio-player" { XCTAssertTrue(app.buttons["Duraklat"].firstMatch.waitForExistence(timeout: 15)) }
            XCUIDevice.shared.orientation = .landscapeLeft
            let landscapeReady = await waitForStableLandscapeGeometry(app, screen: screen)
            XCTAssertTrue(landscapeReady, "The actual application and window must settle in landscape before visual evidence is captured")
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 8))
            captureDevice("modern-\(screen)-landscape-accessibility3-dark")
            app.swipeUp()
            captureDevice("modern-\(screen)-landscape-accessibility3-scrolled")
            XCTAssertFalse(app.alerts.firstMatch.exists)
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
    }

    func testLandscapeRotationSettlesActualWindowAndCapturesWholeDevice() async {
        for screen in ["home", "chat", "audio"] {
            let app = launch(screen)
            XCUIDevice.shared.orientation = .landscapeLeft
            let landscapeReady = await waitForStableLandscapeGeometry(app, screen: screen)
            XCTAssertTrue(landscapeReady, "A supported landscape orientation must update the real application and window bounds")
            XCTAssertGreaterThan(app.frame.width, app.frame.height)
            XCTAssertTrue(app.windows.firstMatch.exists)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 8))
            // Keep the full device and application captures side by side for raster comparison.
            captureDevice("modern-\(screen)-landscape-normal-device-comparison")
            capture(app, "modern-\(screen)-landscape-normal-app-comparison")
            XCTAssertFalse(app.alerts.firstMatch.exists)
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
    }

    func testHomeAgendaUsesIntrinsicCardsForLongAccessibilityTextInBothOrientations() {
        for landscape in [false, true] {
            let app = launch("home", largeText: true, longAgenda: true)
            XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
            let card = app.descendants(matching: .any)["home.agenda.940001"].firstMatch
            let open = app.buttons["agenda.open.940001"]
            reveal(open, in: app)
            XCTAssertTrue(open.isHittable, "The actual post action must remain reachable")
            XCTAssertTrue(card.exists)
            XCTAssertGreaterThan(card.frame.height, 360, "Accessibility content must grow beyond the normal rail height")
            let nextCard = app.descendants(matching: .any)["home.agenda.940002"].firstMatch
            XCTAssertTrue(nextCard.exists)
            XCTAssertGreaterThanOrEqual(nextCard.frame.minY, card.frame.maxY,
                "Large-text agenda cards must stack without overlapping each other's content")
            assertContained(nextCard, in: app)
            assertContained(open, in: app)
            XCTAssertGreaterThan(open.frame.height, 0)
            XCTAssertGreaterThan(open.frame.intersection(app.scrollViews["home.scroll"].frame).height, 0)
            XCTAssertGreaterThanOrEqual(open.frame.minY, card.frame.minY - 1)
            XCTAssertLessThanOrEqual(open.frame.maxY, card.frame.maxY + 1,
                "The post action must remain within its intrinsically sized card")
            // A body Button is one semantic element. Its full label verifies accessible content;
            // it does not establish the geometry or clipping of individual rendered text lines.
            for expectedText in [
                "Her yeni kitap başka bir dünyanın kapısını açıyor. Bu uzun değerlendirme, büyük yazılarda da satırları kesilmeden okunabilmeli.",
                "Birlikte Keşfettiğimiz Hikâyelerin İzinde Uzun Bir Okuma Yolculuğu",
                "Birbirinden Güzel Hikâyeler Anlatan Örnek Yazar"
            ] {
                XCTAssertTrue(open.label.contains(expectedText), "The actual post action must expose its full review and book context")
            }
            // AX geometry establishes action/card containment, not glyph rendering. Retain pixels.
            capture(app, "modern-home-long-agenda-accessibility3-\(landscape ? "landscape" : "portrait")")
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
    }

    func testAgendaComposerRetainsDraftAcrossTypesAndSelectsABook() {
        let app = launch("agenda")
        defer { app.terminate() }
        let open = app.buttons["agenda.composer.open"]
        reveal(open, in: app)
        XCTAssertTrue(open.isHittable)
        open.tap()

        let editor = app.descendants(matching: .any)["agenda.composer.message"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        reveal(editor, in: app)
        editor.tap()
        let draft = "Bugün aklımda kalan bir okuma notu."
        editor.typeText(draft)
        let keyboardClose = app.buttons["agenda.composer.keyboard.close"]
        XCTAssertTrue(keyboardClose.waitForExistence(timeout: 5))
        keyboardClose.tap()
        XCTAssertFalse(app.buttons["agenda.composer.book"].exists)

        let bookType = app.buttons["agenda.composer.type.book"]
        reveal(bookType, in: app, towardStart: true)
        bookType.tap()
        let book = app.buttons["agenda.composer.book"]
        reveal(book, in: app)
        XCTAssertTrue(book.isHittable)
        book.tap()
        // The existing local catalog fixture supplies this book; selecting it only reads data.
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sonsuzluğun Büyüsü")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        result.tap()
        XCTAssertTrue(book.waitForExistence(timeout: 5))
        XCTAssertTrue((book.value as? String ?? "").contains("Sonsuzluğun Büyüsü"))

        for (type, detailIdentifier) in [
            ("quotation", "agenda.composer.page"),
            ("review", "agenda.composer.rating"),
            ("progress", "agenda.composer.current")
        ] {
            let option = app.buttons["agenda.composer.type.\(type)"]
            reveal(option, in: app, towardStart: true)
            option.tap()
            XCTAssertEqual(editor.value as? String, draft, "Changing the post type must retain the draft")
            XCTAssertTrue(book.exists, "Book-linked post types must retain their book selection")
            let detail = app.descendants(matching: .any)[detailIdentifier].firstMatch
            reveal(detail, in: app)
            XCTAssertTrue(detail.isHittable, "The \(type) control must remain reachable")
            assertContained(detail, in: app)
            if type == "progress" {
                let total = app.descendants(matching: .any)["agenda.composer.total"].firstMatch
                XCTAssertTrue(total.exists)
                XCTAssertFalse(app.sliders["agenda.composer.rating"].exists)
            }
        }
        capture(app, "modern-agenda-composer-progress-draft")
        let note = app.buttons["agenda.composer.type.standard"]
        reveal(note, in: app, towardStart: true)
        note.tap()
        XCTAssertEqual(editor.value as? String, draft)
        XCTAssertFalse(book.exists)
        XCTAssertFalse(app.descendants(matching: .any)["agenda.composer.current"].firstMatch.exists)
        capture(app, "modern-agenda-composer-note-draft")
        // No valid post is submitted: this test exercises the native composer and catalog only.
    }

    func testAgendaComposerLocalValidationAndNumericKeyboardAtLargeDarkText() {
        let app = launch("agenda", largeText: true, dark: true)
        defer { app.terminate() }
        let open = app.buttons["agenda.composer.open"]
        reveal(open, in: app)
        XCTAssertTrue(open.isHittable)
        open.tap()
        let submit = app.buttons["agenda.composer.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isHittable, "The footer action must be reachable without scrolling")
        assertContained(submit, in: app)
        submit.tap()
        let error = app.descendants(matching: .any)["agenda.composer.error"].firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("Paylaşım metni boş olamaz."))
        capture(app, "modern-agenda-composer-empty-accessibility3-dark")

        let progress = app.buttons["agenda.composer.type.progress"]
        reveal(progress, in: app, towardStart: true)
        progress.tap()
        let current = app.descendants(matching: .any)["agenda.composer.current"].firstMatch
        reveal(current, in: app)
        XCTAssertTrue(current.isHittable)
        assertContained(current, in: app)
        current.tap()
        current.typeText("12")
        let keyboardClose = app.buttons["agenda.composer.keyboard.close"]
        XCTAssertTrue(keyboardClose.waitForExistence(timeout: 5), "The numeric keyboard needs an accessible dismissal action")
        XCTAssertTrue(keyboardClose.isHittable)
        capture(app, "modern-agenda-composer-numeric-keyboard-accessibility3-dark")
        keyboardClose.tap()
        XCTAssertEqual(current.value as? String, "12")
        let total = app.descendants(matching: .any)["agenda.composer.total"].firstMatch
        reveal(total, in: app)
        XCTAssertTrue(total.isHittable, "Both stacked progress fields must remain reachable")
        assertContained(total, in: app)
        XCTAssertTrue(submit.isHittable)
        XCTAssertLessThanOrEqual(submit.frame.maxY, app.frame.maxY + 1)
        capture(app, "modern-agenda-composer-progress-accessibility3-dark")
        // The only submit attempt was empty and is rejected locally before any API mutation.
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
        let header = app.descendants(matching: .any)["chat-pinned-header"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 8))
        XCTAssertTrue(header.label.contains("Okur Sohbeti"), "The compact accessible header must retain the room title")
        XCTAssertTrue(header.label.contains("28"), "The room presence must remain available to accessibility")
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
        let opened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Filtreler açık"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: 3), .completed, "Tapping the filter header must expand the controls")
        let query = app.textFields["audio.filter.query"]
        reveal(query, in: app)
        XCTAssertTrue(query.waitForExistence(timeout: 3))
        XCTAssertTrue(query.isHittable)
        assertContained(query, in: app)
        XCTAssertEqual(toggle.value as? String, "Filtreler açık")
        capture(app, "modern-audio-filters-expanded")
        reveal(toggle, in: app)
        toggle.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Filtreler kapalı"), object: toggle)
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: query)
        XCTAssertEqual(XCTWaiter.wait(for: [closed, removed], timeout: 3), .completed)
        XCTAssertFalse(query.exists)
        XCTAssertEqual(toggle.value as? String, "Filtreler kapalı")
    }

    func testAudiobookMenuOpensANativePageAndBackReturnsToEachOriginTab() {
        for screen in ["home", "profile", "catalog"] {
            let app = launch(screen)
            openAudiobookCatalogFromMenu(in: app)
            assertAudioPageUsesNativeNavigation(app)
            capture(app, "modern-\(screen)-to-audio-native-page")

            app.navigationBars.buttons.firstMatch.tap()

            let origin = app.scrollViews["\(screen).scroll"]
            XCTAssertTrue(origin.waitForExistence(timeout: 5), "Back must return to the originating \(screen) page")
            XCTAssertTrue(origin.isHittable)
            XCTAssertFalse(app.scrollViews["audio.catalog"].exists)
            app.terminate()
        }
    }

    func testAudiobookCatalogDetailAndLibraryKeepNativeBackNavigation() {
        let app = launch("home")
        openAudiobookCatalogFromMenu(in: app)
        let start = app.buttons["audio.catalog.start"]
        reveal(start, in: app)
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(app.scrollViews["audio.detail"].waitForExistence(timeout: 8))
        assertAudioPageUsesNativeNavigation(app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.scrollViews["audio.catalog"].waitForExistence(timeout: 5))

        let library = app.buttons["audio.catalog.library"]
        XCTAssertTrue(library.isHittable)
        library.tap()
        XCTAssertTrue(app.scrollViews["audio.library"].waitForExistence(timeout: 8))
        assertAudioPageUsesNativeNavigation(app)
        capture(app, "modern-audio-catalog-to-library-native-page")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.scrollViews["audio.catalog"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.scrollViews["home.scroll"].waitForExistence(timeout: 5))
    }

    func testChangingBottomTabsLeavesAudioWithoutReopeningItOnReturn() {
        let app = launch("home")
        openAudiobookCatalogFromMenu(in: app)
        assertAudioPageUsesNativeNavigation(app)

        app.buttons["primary-tab-catalog"].tap()

        XCTAssertTrue(app.scrollViews["catalog.scroll"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.scrollViews["audio.catalog"].exists)
        app.buttons["primary-tab-home"].tap()
        XCTAssertTrue(app.scrollViews["home.scroll"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.scrollViews["audio.catalog"].exists, "Returning to Home must not reopen the dismissed audio page")
    }

    func testFailedCatalogCategoryChangeRemovesOldResultsAndRetryUsesTheNewCategory() {
        let app = launch("catalog", catalogFailure: true)
        let oldBook = app.buttons["catalog.book.900041"]
        reveal(oldBook, in: app)
        XCTAssertTrue(oldBook.waitForExistence(timeout: 8))
        XCTAssertTrue(oldBook.isHittable)
        assertContained(oldBook, in: app)
        // This real chip is above the verified book results. Do not require a particular XCUI
        // element type for its horizontal container or scroll farther down when AX evicts it.
        let category = app.buttons["catalog.category.35"]
        let usableCategoryBounds = revealCatalogCategory(category, in: app)
        XCTAssertTrue(category.isHittable)
        assertContained(category, in: app)
        XCTAssertGreaterThanOrEqual(category.frame.height, 44)
        XCTAssertTrue(usableCategoryBounds.contains(category.frame), "The entire category control must be inside the unobscured catalog viewport")
        XCTAssertFalse(category.isSelected)
        print("CATALOG_CATEGORY_BEFORE_TAP frame=\(category.frame),usable=\(usableCategoryBounds)")
        capture(app, "modern-catalog-category-fully-visible-before-tap")
        category.tap()
        let categorySelected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: category)
        XCTAssertEqual(XCTWaiter.wait(for: [categorySelected], timeout: 3), .completed,
                       "A single ordinary tap on the fully visible category must select it before checking the failure response")
        let retry = app.buttons["catalog.retry"]
        reveal(retry, in: app)
        XCTAssertTrue(retry.waitForExistence(timeout: 8), "A failed category reset must show an error instead of the old results")
        XCTAssertTrue(retry.isHittable)
        assertContained(retry, in: app)
        XCTAssertFalse(oldBook.exists, "A failed category change must remove the old category results before retry")
        capture(app, "modern-catalog-category-failure-without-stale-results")
        retry.tap()
        let newBook = app.buttons["catalog.book.900140"]
        reveal(newBook, in: app)
        XCTAssertTrue(newBook.waitForExistence(timeout: 8))
        XCTAssertTrue(newBook.isHittable)
        assertContained(newBook, in: app)
        XCTAssertFalse(oldBook.exists, "Old category results must never be mixed with the retried category")
        capture(app, "modern-catalog-category-retry-recovered")
    }

    func testNonPremiumAudiobookListenShowsAccessMessageWithoutStartingPurchase() {
        let app = launch("audio-detail", standardMember: true)
        let listen = app.buttons["audio.detail.listen"]
        reveal(listen, in: app)
        XCTAssertTrue(listen.isHittable)
        listen.tap()
        let title = app.staticTexts["Hikâyeler sana seslensin."]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        assertContained(title, in: app)
        let message = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Sadece Premium üyeler sesli kitap dinleyebilir")).firstMatch
        XCTAssertTrue(message.exists)
        assertContained(message, in: app)
        let hero = app.descendants(matching: .any)["audio.premium.hero"].firstMatch
        XCTAssertTrue(hero.exists)
        assertContained(hero, in: app)
        let premium = app.buttons["Premium'u keşfet"]
        reveal(premium, in: app)
        XCTAssertTrue(premium.isHittable)
        assertContained(premium, in: app)
        capture(app, "modern-audio-premium-explanation")
        // No Premium purchase, authentication, restore, or media manifest action is invoked.
        app.buttons["Şimdi değil"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["audio.detail"].exists)
    }

    func testLibraryArtworkAndActualShelfNavigationRemainReachable() {
        let app = launch("library", largeText: true)
        let hero = app.descendants(matching: .any)["library.scenicHero"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Kişisel Kitaplığım"), "The accessible library summary must retain its title")
        XCTAssertTrue(hero.label.contains("2 kitap"), "The accessible library summary must retain the actual book count")
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
        assertAudioPageUsesNativeNavigation(app)
        capture(app, "modern-profile-to-audiobook-library-native-route")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.scrollViews["profile.scroll"].waitForExistence(timeout: 5))
        XCTAssertTrue(library.isHittable, "Native Back must restore the profile's audiobook section")
        XCTAssertFalse(destination.exists)
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
        XCTAssertTrue(app.staticTexts["Beyaz Zambaklar Ülkesinde"].firstMatch.waitForExistence(timeout: 8), "The real book-detail route must load its fixture before returning")
        let back = app.buttons["book.detail.back"]
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
