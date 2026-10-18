import XCTest

/// Offline transport exercises the real detail view; comment mutations deliberately fail locally.
@MainActor
final class BookAgendaUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(guest: Bool = false, readOnly: Bool = false, commentsFailure: Bool = false,
                        largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = "agenda-detail"
        app.launchEnvironment["MODERN_PARITY_GUEST"] = guest ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_AGENDA_READ_ONLY"] = readOnly ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_AGENDA_COMMENTS_FAILURE"] = commentsFailure ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DARK"] = largeText ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        let scroll = app.scrollViews["agenda.detail.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            if element.isHittable { return }
            scroll.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    func testCommentHeadingAndPaddedEditorOpenKeyboardAndFailedSendKeepsDraft() {
        let app = launch()
        defer { app.terminate() }
        let heading = app.buttons["agenda.comment.focus"]
        reveal(heading, app: app)
        heading.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let editor = app.descendants(matching: .any)["agenda.comment.message"].firstMatch
        let draft = "Bu kitabı okudum."
        editor.typeText(draft)
        app.buttons["agenda.comment.keyboard.close"].tap()
        reveal(editor, app: app)
        // Tap the lower padded area of the multiline field, away from its first text baseline.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["agenda.comment.keyboard.close"].tap()
        let submit = app.buttons["agenda.comment.submit"]
        reveal(submit, app: app)
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["agenda.comment.error"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, draft)
    }

    func testCommentEditorRemainsReachableAtLargeDarkText() {
        let app = launch(largeText: true)
        defer { app.terminate() }
        let heading = app.buttons["agenda.comment.focus"]
        reveal(heading, app: app)
        heading.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["agenda.comment.keyboard.close"].exists)
    }

    func testDeniedPermissionAndGuestShowActionableStates() {
        let member = launch(readOnly: true)
        let permission = member.staticTexts["agenda.comment.permission"]
        reveal(permission, app: member)
        XCTAssertTrue(permission.exists)
        XCTAssertFalse(member.descendants(matching: .any)["agenda.comment.message"].firstMatch.exists)
        member.terminate()

        let guest = launch(guest: true)
        defer { guest.terminate() }
        let login = guest.buttons["agenda.comment.login"]
        reveal(login, app: guest)
        XCTAssertTrue(login.isEnabled)
        XCTAssertFalse(guest.descendants(matching: .any)["agenda.comment.message"].firstMatch.exists)
    }

    func testCommentLoadFailureDoesNotShowFalseEmptyState() {
        let app = launch(commentsFailure: true)
        defer { app.terminate() }
        let error = app.descendants(matching: .any)["agenda.comments.error"].firstMatch
        reveal(error, app: app)
        XCTAssertTrue(error.exists)
        XCTAssertFalse(app.staticTexts["Henüz yorum yok"].exists)
    }
}
