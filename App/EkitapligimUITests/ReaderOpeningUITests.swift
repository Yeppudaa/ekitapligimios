import XCTest

/// Offline fixtures use the shipping transition, captured cover and PDFKit reader.
final class ReaderOpeningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(hold: Bool = false, reduceMotion: Bool = false, nestedCover: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-reader-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["READER_FIXTURE_MODE"] = "cover-opening"
        app.launchEnvironment["READER_OPENING_HOLD"] = hold ? "1" : "0"
        app.launchEnvironment["READER_OPENING_REDUCE_MOTION"] = reduceMotion ? "1" : "0"
        app.launchEnvironment["READER_OPENING_NESTED_COVER"] = nestedCover ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.buttons["book.openReader"].waitForExistence(timeout: 10))
        return app
    }

    func testOpeningHandsOffToTheRealReaderAndCanReopen() {
        let app = launch()
        for _ in 0..<2 {
            app.buttons["book.openReader"].tap()
            XCTAssertTrue(app.buttons["reader.showControls"].waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertFalse(app.buttons["reader.opening.cancel"].exists)
            assertRestoredPage(in: app)
            let paper = app.descendants(matching: .any)["reader.fixture.document"].firstMatch
            XCTAssertLessThanOrEqual(paper.frame.minY, app.frame.minY + 1)
            XCTAssertGreaterThanOrEqual(paper.frame.maxY, app.frame.maxY - 1)
            app.buttons["reader.close"].tap()
            XCTAssertTrue(app.buttons["book.openReader"].waitForExistence(timeout: 5))
        }
    }

    func testCancelDoesNotMountReaderAndClearsPresentation() {
        let app = launch(hold: true)
        app.buttons["book.openReader"].tap()
        let cancel = app.buttons["reader.opening.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(cancel.frame.width, 43.99)
        XCTAssertGreaterThanOrEqual(cancel.frame.height, 43.99)
        XCTAssertFalse(app.buttons["reader.showControls"].exists)
        cancel.tap()
        XCTAssertTrue(app.buttons["book.openReader"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reader.showControls"].exists)
        XCTAssertFalse(app.buttons["reader.opening.cancel"].exists)
    }

    func testReducedMotionOpensReaderWithoutHinge() {
        let app = launch(reduceMotion: true)
        app.buttons["book.openReader"].tap()
        XCTAssertTrue(app.buttons["reader.showControls"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reader.opening.cancel"].exists)
        assertRestoredPage(in: app)
    }

    func testReaderOwnedFullScreenNoticeDuringRevealKeepsReaderAfterDismissal() {
        let app = launch(nestedCover: true)
        app.buttons["book.openReader"].tap()
        let closeNotice = app.buttons["reader.opening.fixture.closeNestedCover"]
        XCTAssertTrue(closeNotice.waitForExistence(timeout: 10), app.debugDescription)
        closeNotice.tap()
        XCTAssertTrue(app.buttons["reader.showControls"].waitForExistence(timeout: 5), app.debugDescription)
        assertRestoredPage(in: app)
        XCTAssertFalse(app.buttons["reader.opening.cancel"].exists)
        app.buttons["reader.close"].tap()
        XCTAssertTrue(app.buttons["book.openReader"].waitForExistence(timeout: 5))
    }

    private func assertRestoredPage(in app: XCUIApplication) {
        let page = app.staticTexts["reader.focusProgress"]
        expectation(for: NSPredicate(format: "label == %@", "Sayfa 25 / 60"), evaluatedWith: page)
        waitForExpectations(timeout: 10)
    }
}
