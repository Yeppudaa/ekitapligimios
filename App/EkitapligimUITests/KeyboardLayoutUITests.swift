import XCTest
import UIKit

/// Run on iPhone SE, a current iPhone, and iPad in full screen and a reduced app window.
/// Simulator: Hardware > Keyboard > Connect Hardware Keyboard must be OFF. A missing software
/// keyboard fails the test; synthetic keyboard notifications cannot validate window layout.
/// Dock the iPad software keyboard for this suite's avoidance assertions.
/// The DEBUG fixture renders the shipping RootView and intercepts every request. Mutations remain
/// HTTP 405, and no test submits a post, comment, conversation, or chat message.
@MainActor
final class KeyboardLayoutUITests: XCTestCase {
    private var activeApplication: XCUIApplication?
    private let geometryTolerance: CGFloat = 2

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 180
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        if let app = activeApplication,
           let run = testRun, run.failureCount > 0 || run.unexpectedExceptionCount > 0 {
            attachDiagnostics(app, name: "keyboard-layout-failure")
        }
        activeApplication?.terminate()
        activeApplication = nil
        XCUIDevice.shared.orientation = .portrait
    }

    func testPrimaryTabsStartAtTheBottomOfTheRealAppWindow() async throws {
        let app = launch(destination: "forum")
        let geometry = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: geometry)
    }

    func testForumKeyboardRepeatedlyOpensAndClosesWithoutRetainingItsHeight() async throws {
        let app = launch(destination: "forum")
        try openForumThread(app)
        let baseline = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: baseline)
        let editor = element("forum-reply-input", in: app)

        for cycle in 0..<3 {
            let editing = try await openKeyboard(editor, in: app, shell: true)
            assertEditorIsOutsideKeyboard(editor, geometry: editing)
            editor.typeText("\(cycle + 1). deneme ")
            try await dismissKeyboard(in: app)
            let restored = try await stableGeometry(app, keyboard: false, shell: true)
            assertRestoredShell(app, geometry: restored, baseline: baseline)
            let draft = try XCTUnwrap(editor.value as? String)
            let entries = (0...cycle).map { "\($0 + 1). deneme " }
            // A normal focus tap chooses an insertion point. Preserve every typed entry
            // exactly once without assuming that tapping always places the caret at the end.
            XCTAssertEqual(draft.count, entries.joined().count)
            for entry in entries { XCTAssertTrue(draft.contains(entry), "Lost draft entry: \(entry)") }
        }
    }

    func testPoppingForumPageWithKeyboardOpenAndSwitchingTabsRestoresFullHeight() async throws {
        let app = launch(destination: "forum")
        try openForumThread(app)
        let baseline = try await stableGeometry(app, keyboard: false, shell: true)
        _ = try await openKeyboard(element("forum-reply-input", in: app), in: app, shell: true)

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.isHittable, "The real pushed forum page must expose native Back")
        back.tap()
        let popped = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: popped, baseline: baseline)
        XCTAssertFalse(element("forum-reply-input", in: app).exists)

        for destination in ["agenda", "requests", "home"] {
            let tab = app.buttons["primary-tab-\(destination)"]
            XCTAssertTrue(tab.isHittable)
            tab.tap()
            let changed = try await stableGeometry(app, keyboard: false, shell: true)
            assertRestoredShell(app, geometry: changed, baseline: baseline)
        }
    }

    func testInteractiveForumKeyboardDismissalRestoresTheSameViewport() async throws {
        let app = launch(destination: "forum")
        try openForumThread(app)
        let baseline = try await stableGeometry(app, keyboard: false, shell: true)
        let editor = element("forum-reply-input", in: app)
        _ = try await openKeyboard(editor, in: app, shell: true)
        editor.typeText("Kaydırarak kapatılan taslak.")
        let scroll = app.scrollViews["forum-thread-scroll"]
        let bounds = scroll.frame.intersection(app.windows.firstMatch.frame)
        let topY = bounds.minY + 40
        let bottomY = editor.frame.minY - 12
        XCTAssertGreaterThan(bottomY, topY)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = bounds.midX - app.frame.minX
        let start = origin.withOffset(CGVector(dx: x, dy: topY - app.frame.minY))
        let end = origin.withOffset(CGVector(dx: x, dy: bottomY - app.frame.minY))
        start.press(forDuration: 0.1, thenDragTo: end)
        let restored = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: restored, baseline: baseline)
        XCTAssertEqual(editor.value as? String, "Kaydırarak kapatılan taslak.")
    }

    func testAgendaCommentKeyboardRestoresRootShellAtAccessibilityTextSize() async throws {
        let app = launch(destination: "agenda", largeText: true)
        let post = element("agenda.post.940001", in: app)
        try reveal(post, in: app)
        post.tap()
        let heading = app.buttons["agenda.comment.focus"]
        try reveal(heading, in: app, scrollID: "agenda.detail.scroll")
        let baseline = try await stableGeometry(app, keyboard: false, shell: true)

        heading.tap()
        let editing = try await stableGeometry(app, keyboard: true, shell: true)
        let editor = element("agenda.comment.message", in: app)
        XCTAssertTrue(editor.isHittable)
        editor.typeText("Büyük yazıda yorum taslağı.")
        assertEditorIsOutsideKeyboard(editor, geometry: editing)
        try await dismissKeyboard(in: app, identifier: "agenda.comment.keyboard.close")
        let restored = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: restored, baseline: baseline)
        XCTAssertEqual(editor.value as? String, "Büyük yazıda yorum taslağı.")
    }

    func testDismissingAgendaComposerWhileKeyboardIsOpenRestoresUnderlyingTabs() async throws {
        let app = launch(destination: "agenda")
        let baseline = try await stableGeometry(app, keyboard: false, shell: true)
        let compose = app.buttons["agenda.composer.open"]
        try reveal(compose, in: app)
        compose.tap()
        let editor = element("agenda.composer.message", in: app)
        try reveal(editor, in: app, scrollID: "agenda.composer.scroll")
        let editing = try await openKeyboard(editor, in: app, shell: false)
        assertEditorIsOutsideKeyboard(editor, geometry: editing)
        editor.typeText("Yalnızca çevrimdışı taslak.")

        let close = app.buttons["agenda.composer.close"]
        XCTAssertTrue(close.isHittable)
        close.tap()
        let restored = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: restored, baseline: baseline)
        XCTAssertFalse(element("agenda.composer", in: app).exists)
    }

    func testPrivateMessageAndChatSheetsReleaseKeyboardSpaceWhenDismissed() async throws {
        for (destination, editorID) in [
            ("conversation", "conversation-reply-input"),
            ("chat", "chat-composer")
        ] {
            let app = launch(destination: destination)
            let editor = element(editorID, in: app)
            XCTAssertTrue(editor.waitForExistence(timeout: 10))
            let editing = try await openKeyboard(editor, in: app, shell: false)
            editor.typeText("Çevrimdışı mesaj taslağı.")
            assertEditorIsOutsideKeyboard(editor, geometry: editing)
            try await dismissKeyboard(in: app)
            let dismissed = try await stableGeometry(app, keyboard: false, shell: false)
            XCTAssertGreaterThan(dismissed.window.height, 0)
            _ = try await openKeyboard(editor, in: app, shell: false)

            let close = app.buttons["shell.route.close"].firstMatch
            XCTAssertTrue(close.isHittable)
            close.tap()
            let restored = try await stableGeometry(app, keyboard: false, shell: true)
            assertRestoredShell(app, geometry: restored)
            XCTAssertFalse(editor.exists)
            app.terminate()
        }
    }

    func testBookCommentInRootRouteSheetRemainsAboveKeyboardAndRestoresShell() async throws {
        let app = launch(destination: "book-detail")
        let editor = element("book-comments-input", in: app)
        try reveal(editor, in: app, scrollID: "book-detail-scroll")
        let editing = try await openKeyboard(editor, in: app, shell: false)
        editor.typeText("Kitap yorumu taslağı.")
        assertEditorIsOutsideKeyboard(editor, geometry: editing)
        try await dismissKeyboard(in: app)
        XCTAssertEqual(editor.value as? String, "Kitap yorumu taslağı.")
        // Book detail uses its shipping custom top bar and hides the system navigation bar.
        let close = app.buttons["book.detail.back"]
        XCTAssertTrue(close.isHittable)
        close.tap()
        let restored = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: restored)
    }

    func testRotatingWithForumKeyboardOpenRecoversBothWindowOrientations() async throws {
        let app = launch(destination: "forum")
        try openForumThread(app)
        let portrait = try await stableGeometry(app, keyboard: false, shell: true)
        let editor = element("forum-reply-input", in: app)
        _ = try await openKeyboard(editor, in: app, shell: true)

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscapeEditing = try await stableGeometry(app, keyboard: true, shell: true,
                                                        orientation: .landscapeLeft)
        assertEditorIsOutsideKeyboard(editor, geometry: landscapeEditing)
        try await dismissKeyboard(in: app)
        let landscape = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: landscape)

        _ = try await openKeyboard(editor, in: app, shell: true)
        XCUIDevice.shared.orientation = .portrait
        let portraitEditing = try await stableGeometry(app, keyboard: true, shell: true,
                                                       orientation: .portrait)
        assertEditorIsOutsideKeyboard(editor, geometry: portraitEditing)
        try await dismissKeyboard(in: app)
        let restored = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: restored, baseline: portrait)
    }

    func testCurrentIPadWindowAtLargeTextRestoresAfterKeyboardAndSheetDismissal() async throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Run this case on iPad in full screen and a reduced app window")
        }
        // Public iOS XCTest APIs cannot resize another app's window. The matrix runner must set
        // the desired iPad window first; all measurements below use that actual UIWindow's bounds.
        let app = launch(destination: "forum", largeText: true)
        try openForumThread(app)
        let baseline = try await stableGeometry(app, keyboard: false, shell: true)
        let editor = element("forum-reply-input", in: app)
        let editing = try await openKeyboard(editor, in: app, shell: true)
        assertEditorIsOutsideKeyboard(editor, geometry: editing)
        editor.typeText("iPad penceresi taslağı.")
        try await dismissKeyboard(in: app)
        let restored = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: restored, baseline: baseline)

        app.navigationBars.buttons.firstMatch.tap()
        let compose = app.buttons["forum.create.open"]
        XCTAssertTrue(compose.waitForExistence(timeout: 5))
        compose.tap()
        let title = element("forum.create.title", in: app)
        let sheetEditing = try await openKeyboard(title, in: app, shell: false)
        assertEditorIsOutsideKeyboard(title, geometry: sheetEditing)
        try await dismissKeyboard(in: app)
        let cancel = app.buttons["forum.create.cancel"]
        try reveal(cancel, in: app)
        cancel.tap()
        let afterSheet = try await stableGeometry(app, keyboard: false, shell: true)
        assertRestoredShell(app, geometry: afterSheet, baseline: baseline)
    }

    private func launch(destination: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = "keyboard-shell"
        app.launchEnvironment["MODERN_PARITY_KEYBOARD_DESTINATION"] = destination
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DARK"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_PLAY_AUDIO"] = "0"
        activeApplication = app
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["modern-parity-error"].exists)
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func openForumThread(_ app: XCUIApplication) throws {
        let category = element("forum.category.1", in: app)
        try reveal(category, in: app)
        category.tap()
        let thread = element("forum.thread.960001", in: app)
        try reveal(thread, in: app)
        thread.tap()
        XCTAssertTrue(element("forum-reply-input", in: app).waitForExistence(timeout: 10))
    }

    private func openKeyboard(_ editor: XCUIElement, in app: XCUIApplication,
                              shell: Bool) async throws -> Geometry {
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertTrue(editor.isHittable, "The real editor must be reachable before focusing it")
        editor.tap()
        return try await stableGeometry(app, keyboard: true, shell: shell)
    }

    private func dismissKeyboard(in app: XCUIApplication, identifier: String = "keyboard-dismiss") async throws {
        let candidates = app.buttons.matching(identifier: identifier)
        let close = try XCTUnwrap(candidates.allElementsBoundByIndex.first(where: { $0.isHittable }),
                                 "The active composer must offer an accessible keyboard dismissal action")
        close.tap()
        _ = try await stableGeometry(app, keyboard: false, shell: false)
    }

    private struct Geometry {
        let window: CGRect
        let content: CGRect?
        let tabs: CGRect?
        let keyboard: CGRect?
    }

    private enum GeometryError: Error { case timeout, unreachableElement }

    private func stableGeometry(_ app: XCUIApplication, keyboard expectedKeyboard: Bool, shell: Bool,
                                orientation: UIDeviceOrientation? = nil) async throws -> Geometry {
        let deadline = Date().addingTimeInterval(12)
        var previous: Geometry?
        var stableSamples = 0
        while Date() < deadline && !Task.isCancelled {
            let window = app.windows.firstMatch
            let keyboard = app.keyboards.firstMatch
            let tabs = element("shell.primary-tabs", in: app)
            let content = element("shell.content", in: app)
            let windowFrame = window.exists ? window.frame : .zero
            let keyboardFrame = keyboard.exists ? keyboard.frame : .zero
            let visibleKeyboard = valid(keyboardFrame) && keyboardFrame.intersects(windowFrame)
                ? keyboardFrame : nil
            let sample = Geometry(window: windowFrame,
                                  content: content.exists ? content.frame : nil,
                                  tabs: tabs.exists ? tabs.frame : nil,
                                  keyboard: visibleKeyboard)
            let keyboardVisible = sample.keyboard != nil
            let dockedKeyboard = sample.keyboard.map {
                $0.width >= sample.window.width * 0.9 &&
                    $0.maxY >= sample.window.maxY - geometryTolerance
            } ?? false
            let orientationReady = orientation.map { XCUIDevice.shared.orientation == $0 } ?? true
            let shellReady = !shell || (expectedKeyboard
                ? !dockedKeyboard || sample.tabs == nil
                : sample.tabs.map(valid) == true && sample.content.map(valid) == true)
            if valid(sample.window), keyboardVisible == expectedKeyboard, orientationReady, shellReady,
               let previous, matches(sample, previous) {
                stableSamples += 1
                if stableSamples >= 3 { return sample }
            } else {
                stableSamples = 0
            }
            previous = sample
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        attachDiagnostics(app, name: "keyboard-layout-unstable")
        XCTFail("Window geometry did not settle (keyboard=\(expectedKeyboard), shell=\(shell)). " +
                "Enable the software keyboard and disable Connect Hardware Keyboard on the simulator.")
        throw GeometryError.timeout
    }

    private func assertRestoredShell(_ app: XCUIApplication, geometry: Geometry,
                                     baseline: Geometry? = nil,
                                     file: StaticString = #filePath, line: UInt = #line) {
        guard let tabs = geometry.tabs, let content = geometry.content else {
            XCTFail("The complete RootView shell must return after editing", file: file, line: line)
            return
        }
        XCTAssertNil(geometry.keyboard, file: file, line: line)
        // Home indicator and window safe area may remain; a keyboard-sized blank region may not.
        XCTAssertLessThanOrEqual(geometry.window.maxY - tabs.maxY, 60, file: file, line: line)
        XCTAssertLessThanOrEqual(tabs.maxY, geometry.window.maxY + geometryTolerance, file: file, line: line)
        XCTAssertGreaterThan(tabs.minY, geometry.window.midY, file: file, line: line)
        // A native ScrollView may keep a full-height frame and reserve the tab area as a content
        // inset. Its frame need not end at the tab bar; recovery is checked against its own baseline.
        XCTAssertTrue(valid(content), file: file, line: line)
        XCTAssertGreaterThanOrEqual(content.minX, geometry.window.minX - geometryTolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(content.maxX, geometry.window.maxX + geometryTolerance, file: file, line: line)
        for destination in ["home", "catalog", "agenda", "flow", "requests", "profile"] {
            XCTAssertTrue(app.buttons["primary-tab-\(destination)"].isHittable,
                          "Every primary destination must return after keyboard dismissal", file: file, line: line)
        }
        if let baseline {
            XCTAssertTrue(near(geometry.window, baseline.window), "The app window must retain its full bounds", file: file, line: line)
            XCTAssertTrue(near(tabs, baseline.tabs), "Primary tabs retained a previous keyboard offset", file: file, line: line)
            XCTAssertTrue(near(content, baseline.content), "Page content retained a previous keyboard inset", file: file, line: line)
        }
    }

    private func assertEditorIsOutsideKeyboard(_ editor: XCUIElement, geometry: Geometry,
                                               file: StaticString = #filePath, line: UInt = #line) {
        guard let keyboard = geometry.keyboard else {
            XCTFail("A real software keyboard is required", file: file, line: line)
            return
        }
        XCTAssertTrue(editor.isHittable, file: file, line: line)
        let field = editor.frame
        XCTAssertTrue(valid(field), file: file, line: line)
        XCTAssertGreaterThanOrEqual(field.minX, geometry.window.minX - geometryTolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(field.maxX, geometry.window.maxX + geometryTolerance, file: file, line: line)
        XCTAssertGreaterThanOrEqual(field.minY, geometry.window.minY - geometryTolerance, file: file, line: line)
        let overlap = field.intersection(keyboard)
        XCTAssertTrue(overlap.isNull || overlap.width <= geometryTolerance || overlap.height <= geometryTolerance,
                      "The software keyboard covers the active editor", file: file, line: line)
        let submitIdentifiers = [
            "forum-reply-input": "forum-reply-send",
            "conversation-reply-input": "conversation-reply-send",
            "chat-composer": "chat-send",
            "agenda.comment.message": "agenda.comment.submit"
        ]
        if let app = activeApplication, let identifier = submitIdentifiers[editor.identifier] {
            let submit = app.buttons[identifier]
            XCTAssertTrue(submit.exists, file: file, line: line)
            XCTAssertTrue(submit.isHittable, "The composer action must remain reachable", file: file, line: line)
            let submitOverlap = submit.frame.intersection(keyboard)
            XCTAssertTrue(submitOverlap.isNull || submitOverlap.width <= geometryTolerance ||
                            submitOverlap.height <= geometryTolerance,
                          "The software keyboard covers the composer action", file: file, line: line)
        }
    }

    private func reveal(_ target: XCUIElement, in app: XCUIApplication, scrollID: String? = nil) throws {
        let scroll = scrollID.map { app.scrollViews[$0] } ?? app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<20 {
            if target.exists && target.isHittable { return }
            let bounds = scroll.frame.intersection(app.windows.firstMatch.frame)
            guard valid(bounds) else { break }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = bounds.minX - app.frame.minX + bounds.width * 0.87
            let top = origin.withOffset(CGVector(dx: x, dy: bounds.minY - app.frame.minY + bounds.height * 0.2))
            let bottom = origin.withOffset(CGVector(dx: x, dy: bounds.minY - app.frame.minY + bounds.height * 0.8))
            if target.exists && valid(target.frame) && target.frame.maxY < bounds.minY {
                top.press(forDuration: 0.05, thenDragTo: bottom)
            } else {
                bottom.press(forDuration: 0.05, thenDragTo: top)
            }
        }
        attachDiagnostics(app, name: "keyboard-layout-unreachable-\(target.exists ? target.identifier : "missing")")
        XCTFail("The real scroll content must expose its editor or navigation action")
        throw GeometryError.unreachableElement
    }

    private func valid(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && !frame.isEmpty &&
            frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite
    }

    private func near(_ lhs: CGRect?, _ rhs: CGRect?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case let (.some(left), .some(right)):
            return abs(left.minX - right.minX) <= geometryTolerance &&
                abs(left.minY - right.minY) <= geometryTolerance &&
                abs(left.width - right.width) <= geometryTolerance &&
                abs(left.height - right.height) <= geometryTolerance
        default: return false
        }
    }

    private func matches(_ lhs: Geometry, _ rhs: Geometry) -> Bool {
        near(lhs.window, rhs.window) && near(lhs.content, rhs.content) &&
            near(lhs.tabs, rhs.tabs) && near(lhs.keyboard, rhs.keyboard)
    }

    private func attachDiagnostics(_ app: XCUIApplication, name: String) {
        let appImage = XCTAttachment(screenshot: app.screenshot())
        appImage.name = name + "-app"
        appImage.lifetime = .keepAlways
        add(appImage)
        let displayImage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        displayImage.name = name + "-display"
        displayImage.lifetime = .keepAlways
        add(displayImage)
        // This suite launches only synthetic accounts and locally intercepted payloads.
        let tree = XCTAttachment(string: String(app.debugDescription.prefix(40_000)))
        tree.name = name + "-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
