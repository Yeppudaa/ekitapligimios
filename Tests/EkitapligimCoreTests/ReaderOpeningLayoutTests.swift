import Foundation
import XCTest
@testable import EkitapligimCore

final class ReaderOpeningLayoutTests: XCTestCase {
    func testLiftPreservesTheVisibleCoverAndEndsAtTheAndroidCenter() {
        for viewport in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844),
                         CGSize(width: 1_024, height: 1_366), CGSize(width: 844, height: 390)] {
            let origin = CGRect(x: 24, y: 80, width: 112, height: 166)
            let layout = ReaderOpeningLayout(viewport: viewport, source: origin, displayScale: 3)
            assertRect(layout.coverRect(at: ReaderOpeningFrame(elapsedMilliseconds: 0)), equals: origin)
            let lifted = layout.coverRect(at: ReaderOpeningFrame(elapsedMilliseconds: 560))
            XCTAssertEqual(lifted.midX, viewport.width / 2, accuracy: 0.001)
            XCTAssertEqual(lifted.midY, viewport.height / 2 - 12, accuracy: 0.001)
            XCTAssertLessThanOrEqual(lifted.width, viewport.width * 0.72)
            XCTAssertLessThanOrEqual(lifted.height, viewport.height * 0.65 + 0.001)
            assertRect(layout.paperRect(at: ReaderOpeningFrame(elapsedMilliseconds: 1_640)),
                       equals: CGRect(origin: .zero, size: viewport))
        }
    }

    func testReferenceSizesUseAndroidPixelRoundingAndTabletScaleCap() {
        let phone = ReaderOpeningLayout(viewport: CGSize(width: 390, height: 844), source: nil, displayScale: 3)
        XCTAssertEqual(phone.coverSize.width, 220)
        XCTAssertEqual(phone.coverSize.height / phone.coverSize.width, 250.0 / 170, accuracy: 0.0001)
        let compact = ReaderOpeningLayout(viewport: CGSize(width: 320, height: 568), source: nil, displayScale: 3)
        XCTAssertEqual(compact.coverSize.width, 181)
        let tablet = ReaderOpeningLayout(viewport: CGSize(width: 1_024, height: 1_366), source: nil, displayScale: 2)
        XCTAssertEqual(tablet.coverSize.width, 253)
        XCTAssertEqual(tablet.cornerRadius, 7)
    }

    func testMissingCoverStartsCenteredAtSeventySixPercent() {
        let layout = ReaderOpeningLayout(viewport: CGSize(width: 390, height: 844), source: nil, displayScale: 3)
        let first = layout.coverRect(at: ReaderOpeningFrame(elapsedMilliseconds: 0))
        XCTAssertEqual(first.width, 220 * 0.76, accuracy: 0.001)
        XCTAssertEqual(first.midX, 195, accuracy: 0.001)
        XCTAssertEqual(first.midY, 410, accuracy: 0.001)
    }

    func testZeroAndNonfiniteViewportsNeverProduceInvalidFrameNumbers() {
        let source = CGRect(x: 24, y: 80, width: 112, height: 166)
        for size in [CGSize.zero, CGSize(width: 0, height: 844), CGSize(width: 390, height: 0),
                     CGSize(width: -1, height: 844), CGSize(width: CGFloat.nan, height: 844),
                     CGSize(width: 390, height: CGFloat.infinity)] {
            let layout = ReaderOpeningLayout(viewport: size, source: source, displayScale: 3)
            XCTAssertFalse(layout.isRenderable)
            for elapsed in [0.0, 560, 1_120, 1_640, 2_160] {
                XCTAssertEqual(layout.coverRect(at: ReaderOpeningFrame(elapsedMilliseconds: elapsed)), .zero)
                XCTAssertEqual(layout.paperRect(at: ReaderOpeningFrame(elapsedMilliseconds: elapsed)), .zero)
            }
        }
    }

    func testClippedEmptyAndNonfiniteSourceRectanglesUseTheCenteredFallback() {
        let viewport = CGSize(width: 390, height: 844)
        let fallback = ReaderOpeningLayout(viewport: viewport, source: nil, displayScale: 3)
        let sources = [CGRect.zero, CGRect(x: 0, y: 0, width: 0, height: 250),
                       CGRect(x: 0, y: 0, width: 170, height: 0),
                       CGRect(x: -20, y: 100, width: 170, height: 250),
                       CGRect(x: 24, y: 800, width: 170, height: 250),
                       CGRect(x: CGFloat.nan, y: 100, width: 170, height: 250),
                       CGRect(x: 24, y: 100, width: CGFloat.infinity, height: 250)]
        for source in sources {
            let layout = ReaderOpeningLayout(viewport: viewport, source: source, displayScale: 3)
            XCTAssertNil(layout.source)
            XCTAssertEqual(layout.coverSize, fallback.coverSize)
            XCTAssertEqual(layout.coverRect(at: ReaderOpeningFrame(elapsedMilliseconds: 0)),
                           fallback.coverRect(at: ReaderOpeningFrame(elapsedMilliseconds: 0)))
        }
    }

    func testUnknownDisplayScaleRemainsFinite() {
        let viewport = CGSize(width: 390, height: 844)
        for scale in [CGFloat.nan, .infinity, 0, -1] {
            let layout = ReaderOpeningLayout(viewport: viewport, source: nil, displayScale: scale)
            XCTAssertTrue(layout.isRenderable)
            XCTAssertEqual(layout.coverSize.width, 220)
            XCTAssertTrue(layout.coverSize.height.isFinite)
            XCTAssertEqual(layout.cornerRadius, 6)
        }
    }

    func testEveryPaperFrameFitsInsideTheWindowForPhoneTabletAndLandscape() {
        for viewport in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844),
                         CGSize(width: 1_024, height: 1_366), CGSize(width: 844, height: 390)] {
            let layout = ReaderOpeningLayout(viewport: viewport, source: nil, displayScale: 3)
            var previousArea: CGFloat = 0
            for elapsed in stride(from: 560.0, through: 1_640, by: 8) {
                let paper = layout.paperRect(at: ReaderOpeningFrame(elapsedMilliseconds: elapsed))
                XCTAssertTrue(paper.width.isFinite && paper.height.isFinite)
                XCTAssertGreaterThanOrEqual(paper.minX, -0.001)
                XCTAssertGreaterThanOrEqual(paper.minY, -0.001)
                XCTAssertLessThanOrEqual(paper.maxX, viewport.width + 0.001)
                XCTAssertLessThanOrEqual(paper.maxY, viewport.height + 0.001)
                XCTAssertGreaterThanOrEqual(paper.width * paper.height, previousArea)
                previousArea = paper.width * paper.height
            }
        }
    }

    private func assertRect(_ actual: CGRect, equals expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.001, file: file, line: line)
    }
}
