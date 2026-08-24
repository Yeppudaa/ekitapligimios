import XCTest
@testable import EkitapligimCore

final class ForumMessageFormattingTests: XCTestCase {
    func testBlocksParseHeadingBulletAndSeparator() {
        let raw = """
        1. Giriş:
        • İlk madde
        ----------
        Normal paragraf
        """

        let blocks = ForumMessageFormatting.blocks(from: raw)

        XCTAssertEqual(blocks.count, 4)
        XCTAssertTrue(blocks[0].isHeading)
        XCTAssertEqual(blocks[0].text, "1. Giriş:")
        XCTAssertTrue(blocks[1].isBullet)
        XCTAssertTrue(blocks[2].isSeparator)
        XCTAssertFalse(blocks[3].isHeading)
        XCTAssertEqual(blocks[3].text, "Normal paragraf")
    }

    func testBlocksEmptyForBlankMessage() {
        XCTAssertTrue(ForumMessageFormatting.blocks(from: "   \n\n  ").isEmpty)
    }

    func testSonNotLineIsHeading() {
        let blocks = ForumMessageFormatting.blocks(from: "Son Not: devam edecek")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertTrue(blocks[0].isHeading)
    }

    func testDisplayUsernameFallsBackWhenBlank() {
        XCTAssertEqual(ForumMessageFormatting.displayUsername("  "), L10n.forumDefaultUsername)
        XCTAssertEqual(ForumMessageFormatting.displayUsername("Ada"), "Ada")
    }
}
