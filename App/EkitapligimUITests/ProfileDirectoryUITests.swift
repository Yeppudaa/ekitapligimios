import XCTest

@MainActor
final class ProfileDirectoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ screen: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DIRECTORY_PAGES"] = "1"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 15))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            if element.exists && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func select(_ letter: String, in app: XCUIApplication) {
        let alphabet = app.scrollViews["directory.alphabet"]
        reveal(alphabet, in: app)
        let button = app.buttons["directory.letter.\(letter)"]
        for _ in 0..<12 {
            if button.exists && button.isHittable { break }
            alphabet.swipeLeft()
        }
        XCTAssertTrue(button.isHittable, app.debugDescription)
        button.tap()
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testEditorPhotoControlsAndSaveRemainAccessibleWithLargeText() throws {
        let app = launch("profile-edit", largeText: true)
        capture(app, "profile-editor-large-text-introduction")
        for name in ["avatar", "banner"] {
            let button = app.buttons["profileEditor.\(name)"]
            reveal(button, in: app)
            XCTAssertGreaterThanOrEqual(button.frame.height, 53.99)
            XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
        }
        capture(app, "profile-editor-large-text-images")
        let save = app.buttons["profileEditor.save"]
        reveal(save, in: app)
        XCTAssertTrue(save.isEnabled)
        XCTAssertGreaterThanOrEqual(save.frame.height, 53.99)
        capture(app, "profile-editor-large-text-general")
        try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    }

    func testEditorKeyboardAndFailedSaveKeepTypedDraft() {
        let app = launch("profile-edit")
        capture(app, "profile-editor-images")
        let location = app.textFields["profileEditor.location"]
        reveal(location, in: app); location.tap(); location.typeText("İzmir")
        capture(app, "profile-editor-keyboard")
        app.buttons["Tamam"].firstMatch.tap()
        let save = app.buttons["profileEditor.save"]
        reveal(save, in: app); save.tap()
        // The offline transport rejects every profile mutation with 405.
        let error = app.descendants(matching: .any).matching(identifier: "profileEditor.error").firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        reveal(location, in: app)
        XCTAssertEqual(location.value as? String, "İzmir")
        XCTAssertTrue(save.isEnabled)
        capture(app, "profile-editor-failed-save-draft-retained")
    }

    func testAuthorsLetterFindsLaterPageAndKeepsBookNavigation() {
        let app = launch("authors")
        XCTAssertFalse(app.buttons["directory.item.950102"].exists)
        select("Z", in: app)
        let author = app.buttons["directory.item.950102"]
        XCTAssertTrue(author.waitForExistence(timeout: 10), app.debugDescription)
        reveal(author, in: app)
        XCTAssertFalse(app.buttons["directory.item.950100"].exists)
        capture(app, "authors-Z-from-later-page")
        let next = app.buttons["directory.item.950103"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        reveal(next, in: app); next.tap()
        XCTAssertTrue(app.navigationBars["Zygmunt Bauman"].waitForExistence(timeout: 10))
    }

    func testPublisherDottedLetterCollectsAllSparsePagesWithoutExtraTaps() {
        let app = launch("publishers")
        select("İ", in: app)
        let publisher = app.buttons["directory.item.950102"]
        XCTAssertTrue(publisher.waitForExistence(timeout: 10), app.debugDescription)
        reveal(publisher, in: app)
        capture(app, "publishers-dotted-I-from-later-page")
        XCTAssertTrue(app.buttons["directory.item.950103"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["directory.item.950100"].exists)
    }
}
