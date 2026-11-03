import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import XCTest
@testable import EkitapligimCore

final class KeyboardLayoutMetricsTests: XCTestCase {
    private let portrait = CGRect(x: 0, y: 0, width: 390, height: 844)

    func testHiddenGuideOnlyOccupiesTheBottomSafeArea() {
        XCTAssertEqual(inset(CGRect(x: 0, y: 810, width: 390, height: 34)), 0)
        XCTAssertEqual(inset(CGRect(x: 0, y: 844, width: 390, height: 0)), 0)
    }

    func testDockedPortraitKeyboardExcludesHomeIndicatorSafeArea() {
        XCTAssertEqual(inset(CGRect(x: 0, y: 510, width: 390, height: 334)), 300)
    }

    func testHomeButtonDeviceHasNoExtraSafeAreaToSubtract() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 568)
        XCTAssertEqual(KeyboardLayoutMetrics.bottomInset(
            viewBounds: bounds,
            keyboardFrame: CGRect(x: 0, y: 352, width: 320, height: 216),
            bottomSafeArea: 0
        ), 216)
    }

    func testLandscapeUsesCurrentLocalViewport() {
        XCTAssertEqual(KeyboardLayoutMetrics.bottomInset(
            viewBounds: CGRect(x: 0, y: 0, width: 844, height: 390),
            keyboardFrame: CGRect(x: 0, y: 180, width: 844, height: 210),
            bottomSafeArea: 21
        ), 189)
    }

    func testSplitViewAndResizingUseCurrentBoundsInsteadOfScreenSize() {
        let keyboard = CGRect(x: 0, y: 700, width: 1024, height: 324)
        XCTAssertEqual(KeyboardLayoutMetrics.bottomInset(
            viewBounds: CGRect(x: 0, y: 0, width: 375, height: 1024),
            keyboardFrame: keyboard,
            bottomSafeArea: 20
        ), 304)
        XCTAssertEqual(KeyboardLayoutMetrics.bottomInset(
            viewBounds: CGRect(x: 0, y: 0, width: 600, height: 800),
            keyboardFrame: keyboard,
            bottomSafeArea: 20
        ), 80)
    }

    func testFloatingNarrowAndSideKeyboardsDoNotReserveTheViewport() {
        let frames = [
            CGRect(x: 70, y: 400, width: 250, height: 200),
            CGRect(x: 70, y: 644, width: 250, height: 200),
            CGRect(x: 0, y: 500, width: 200, height: 344),
            CGRect(x: 200, y: 500, width: 190, height: 344)
        ]
        for frame in frames { XCTAssertEqual(inset(frame), 0, "\(frame)") }
    }

    func testFullWidthUndockedAndExternalKeyboardGuidesDoNotReserveSpace() {
        XCTAssertEqual(inset(CGRect(x: 0, y: 380, width: 390, height: 300)), 0)
        XCTAssertEqual(inset(CGRect(x: 0, y: 844, width: 390, height: 300)), 0)
    }

    func testOffscreenFramesDoNotReserveSpace() {
        let frames = [
            CGRect(x: 0, y: 900, width: 390, height: 300),
            CGRect(x: 0, y: -300, width: 390, height: 300),
            CGRect(x: 500, y: 500, width: 390, height: 344)
        ]
        for frame in frames { XCTAssertEqual(inset(frame), 0, "\(frame)") }
    }

    func testKeyboardPartlyClippedBelowBottomUsesOnlyTheIntersection() {
        XCTAssertEqual(inset(CGRect(x: 0, y: 600, width: 390, height: 400)), 210)
    }

    func testOversizedKeyboardAndSafeAreaRemainBounded() {
        let keyboard = CGRect(x: -50, y: -100, width: 500, height: 1200)
        XCTAssertEqual(inset(keyboard), 810)
        XCTAssertEqual(inset(keyboard, safeBottom: 10_000), 0)
        XCTAssertEqual(inset(keyboard, safeBottom: -34), 844)
    }

    func testNonzeroBoundsOriginsRemainInTheSameCoordinateSpace() {
        XCTAssertEqual(KeyboardLayoutMetrics.bottomInset(
            viewBounds: CGRect(x: 20, y: 30, width: 390, height: 844),
            keyboardFrame: CGRect(x: 20, y: 540, width: 390, height: 334),
            bottomSafeArea: 34
        ), 300)
    }

    func testSubpixelRoundingDoesNotLoseDockedKeyboard() {
        XCTAssertEqual(inset(CGRect(x: 0.25, y: 510, width: 389.5, height: 334)), 300)
        XCTAssertEqual(inset(CGRect(x: 1, y: 510, width: 388, height: 334)), 0)
    }

    func testInvalidAndEmptyGeometryCannotProduceAnInset() {
        let invalidFrames: [CGRect] = [
            .zero, .null, .infinite,
            CGRect(x: CGFloat.nan, y: 510, width: 390, height: 334),
            CGRect(x: 0, y: CGFloat.infinity, width: 390, height: 334),
            CGRect(x: 0, y: 510, width: CGFloat.infinity, height: 334),
            CGRect(x: 0, y: 510, width: 390, height: CGFloat.nan),
            CGRect(x: 0, y: 510, width: -390, height: 334)
        ]
        for frame in invalidFrames {
            XCTAssertEqual(inset(frame), 0)
            XCTAssertEqual(KeyboardLayoutMetrics.bottomInset(
                viewBounds: frame,
                keyboardFrame: CGRect(x: 0, y: 510, width: 390, height: 334),
                bottomSafeArea: 34
            ), 0)
        }
        XCTAssertEqual(inset(CGRect(x: 0, y: 510, width: 390, height: 334), safeBottom: .nan), 0)
        XCTAssertEqual(inset(CGRect(x: 0, y: 510, width: 390, height: 334), safeBottom: .infinity), 0)
    }

    func testReplyEditorNormalAndAccessibilityHeightsOnLargeViewports() {
        XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: 700, accessibility: false), 76)
        XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: 700, accessibility: true), 100)
    }

    func testReplyEditorCompactsInShortKeyboardVisibleViewports() {
        XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: 260, accessibility: false), 40)
        XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: 260, accessibility: true), 52)
        XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: 180, accessibility: true), 45)
    }

    func testReplyEditorHeightIsBoundedForVeryShortAndInvalidViewports() {
        let heights: [CGFloat] = [-500, 0, 50, 100]
        for height in heights {
            XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: height, accessibility: false), 36)
            XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: height, accessibility: true), 36)
        }
        XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: .nan, accessibility: false), 76)
        XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: .infinity, accessibility: true), 100)
        XCTAssertEqual(KeyboardLayoutMetrics.replyEditorHeight(availableHeight: .greatestFiniteMagnitude, accessibility: true), 100)
    }

    private func inset(_ keyboard: CGRect, safeBottom: CGFloat = 34) -> CGFloat {
        KeyboardLayoutMetrics.bottomInset(
            viewBounds: portrait,
            keyboardFrame: keyboard,
            bottomSafeArea: safeBottom
        )
    }
}
