import XCTest

/// Real root navigation backed by an explicitly enabled, local URLProtocol library state.
/// These scenarios never authenticate, purchase or write to an external service.
@MainActor
final class BookLibraryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        XCUIDevice.shared.orientation = .portrait
    }

    func testReadingShelfAndFavoritePersistIntoProfileAndLiveActivity() {
        let app = launch()
        openBook(in: app)
        selectReadingShelf(in: app)
        let shelf = app.buttons["book.library.shelf"]
        let favorite = app.buttons["book.library.favorite"]
        reveal(favorite, viewport: app.scrollViews["book-detail-scroll"], in: app)
        XCTAssertFalse(favorite.isSelected)
        favorite.tap()
        waitUntil("The acknowledged favorite must be selected") { favorite.isSelected && favorite.isEnabled }
        XCTAssertEqual(favorite.value as? String, "Favorilerinde")
        XCTAssertTrue((shelf.value as? String ?? "").contains("Okuyorum"), "Adding a favorite must preserve the selected reading shelf")
        capture(app, "book-library-reading-and-favorite-acknowledged")

        app.buttons["book.detail.back"].tap()
        XCTAssertTrue(app.scrollViews["catalog.scroll"].waitForExistence(timeout: 5))
        app.buttons["primary-tab-profile"].tap()
        let profileShelf = app.buttons["profile.ebook.shelf.3"]
        reveal(profileShelf, viewport: app.scrollViews["profile.scroll"], in: app)
        profileShelf.tap()
        let favoriteShelf = app.buttons["library.shelf.3"]
        XCTAssertTrue(favoriteShelf.waitForExistence(timeout: 8))
        XCTAssertTrue(favoriteShelf.isSelected)
        let savedBook = app.buttons["library.book.900042"]
        reveal(savedBook, viewport: app.scrollViews["library.scroll"], in: app)
        XCTAssertTrue(savedBook.label.contains("Beyaz Zambaklar Ülkesinde"), "A fresh server library fetch must retain the favorite")
        capture(app, "book-library-profile-favorite-persisted")

        app.buttons["primary-tab-flow"].tap()
        let liveViewport = app.scrollViews["live.scroll"]
        let favoriteActivity = app.buttons["live.activity.library-favorite-900042"]
        reveal(favoriteActivity, viewport: liveViewport, in: app)
        XCTAssertTrue(favoriteActivity.label.contains("favorilerine ekledi"))
        let readingActivity = app.buttons["live.activity.library-reading-900042"]
        reveal(readingActivity, viewport: liveViewport, in: app)
        XCTAssertTrue(readingActivity.label.contains("okumaya başladı"))
        capture(app, "book-library-server-acknowledged-live-activity")
    }

    func testRejectedFavoriteKeepsReadingShelfAndShowsFailureWithoutPublishingAnEvent() {
        let app = launch(mode: "failure")
        openBook(in: app)
        selectReadingShelf(in: app)
        let favorite = app.buttons["book.library.favorite"]
        reveal(favorite, viewport: app.scrollViews["book-detail-scroll"], in: app)
        favorite.tap()
        let error = app.staticTexts["Raf güncellenemedi."]
        reveal(error, viewport: app.scrollViews["book-detail-scroll"], in: app)
        XCTAssertTrue(error.isHittable)
        XCTAssertFalse(favorite.isSelected, "HTTP 200 success:false must never appear as a saved favorite")
        XCTAssertEqual(favorite.value as? String ?? "", "")
        XCTAssertTrue((app.buttons["book.library.shelf"].value as? String ?? "").contains("Okuyorum"))
        capture(app, "book-library-rejected-favorite-retains-reading")

        app.buttons["book.detail.back"].tap()
        app.buttons["primary-tab-flow"].tap()
        let reading = app.buttons["live.activity.library-reading-900042"]
        reveal(reading, viewport: app.scrollViews["live.scroll"], in: app)
        XCTAssertFalse(app.buttons["live.activity.library-favorite-900042"].exists, "Unacknowledged writes must not produce activity rows")
    }

    func testLargeTextGuestCanFindShelfActionAndReceivesSignInPrompt() {
        let app = launch(largeText: true, guest: true)
        openBook(in: app)
        let shelf = app.buttons["book.library.shelf"]
        reveal(shelf, viewport: app.scrollViews["book-detail-scroll"], in: app)
        XCTAssertGreaterThanOrEqual(shelf.frame.height, 44)
        XCTAssertGreaterThanOrEqual(shelf.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(shelf.frame.maxX, app.frame.maxX)
        capture(app, "book-library-visible-shelf-action-accessibility3")
        shelf.tap()
        let alert = app.alerts["Giriş gerekli"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Kitabı rafına veya favorilerine eklemek için giriş yap."].exists)
        XCTAssertFalse(app.buttons["book.library.favorite"].isSelected)
    }

    private func launch(mode: String = "success", largeText: Bool = false, guest: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = "catalog"
        app.launchEnvironment["MODERN_PARITY_LIBRARY_MUTATIONS"] = mode
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_GUEST"] = guest ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_PLAY_AUDIO"] = "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 12))
        return app
    }

    private func openBook(in app: XCUIApplication) {
        let book = app.buttons["catalog.book.900042"]
        reveal(book, viewport: app.scrollViews["catalog.scroll"], in: app)
        book.tap()
        XCTAssertTrue(app.scrollViews["book-detail-scroll"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["book.detail.back"].waitForExistence(timeout: 5))
    }

    private func selectReadingShelf(in app: XCUIApplication) {
        let shelf = app.buttons["book.library.shelf"]
        reveal(shelf, viewport: app.scrollViews["book-detail-scroll"], in: app)
        XCTAssertEqual(shelf.label.lowercased(), "rafa ekle", "Shelf selection must remain an obvious, named action")
        shelf.tap()
        let reading = app.buttons["Okuyorum"].firstMatch
        XCTAssertTrue(reading.waitForExistence(timeout: 5))
        reading.tap()
        waitUntil("The server must acknowledge the reading shelf") {
            (shelf.value as? String ?? "").contains("Okuyorum") && shelf.isEnabled
        }
    }

    private func reveal(_ element: XCUIElement, viewport: XCUIElement, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(viewport.waitForExistence(timeout: 10), file: file, line: line)
        for _ in 0..<28 {
            let bounds = viewport.frame.intersection(app.frame)
            if element.exists, element.isHittable,
               element.frame.minY >= bounds.minY, element.frame.maxY <= bounds.maxY { return }
            viewport.swipeUp()
        }
        XCTFail("Could not reveal \(element.identifier) in its visible scroll viewport", file: file, line: line)
    }

    private func waitUntil(_ message: String, condition: @escaping () -> Bool,
                           file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed, message, file: file, line: line)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
