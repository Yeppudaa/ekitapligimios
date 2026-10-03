import XCTest
@testable import EkitapligimCore

final class ChatReactionSpriteTests: XCTestCase {
    private func sprite(_ size: String = "", width: String = "32", height: String = "32", x: String = "-64") throws -> ChatReactionSpriteDTO {
        let json = "{\"w\":\"\(width)\",\"h\":\(height),\"x\":\(x),\"y\":0,\"bs\":\"\(size)\"}"
        return try JSONDecoder.ekitapligim.decode(ChatReactionSpriteDTO.self, from: Data(json.utf8))
    }

    func testDefaultSheetSelectsThirdCellWithoutScalingWholeImageIntoIcon() throws {
        let viewport = try XCTUnwrap(sprite().viewport(imageWidth: 192, imageHeight: 32, size: 24))
        XCTAssertEqual(viewport.sheetWidth, 144)
        XCTAssertEqual(viewport.sheetHeight, 24)
        XCTAssertEqual(viewport.offsetX, -48)
        XCTAssertEqual(viewport.cellWidth, 24)
    }

    func testRetinaSheetBackgroundSizeMatchesWebCoordinates() throws {
        for size in ["192px", "192px auto", "600% auto", "192px 32px"] {
            let viewport = try XCTUnwrap(sprite(size).viewport(imageWidth: 384, imageHeight: 64, size: 24))
            XCTAssertEqual(viewport.sheetWidth, 144, size)
            XCTAssertEqual(viewport.sheetHeight, 24, size)
            XCTAssertEqual(viewport.offsetX, -48, size)
        }
    }

    func testHeightOnlyAndContainCoverKeepImageAspectRatio() throws {
        let height = try XCTUnwrap(sprite("auto 32px").viewport(imageWidth: 384, imageHeight: 64, size: 24))
        XCTAssertEqual(height.sheetWidth, 144)
        let contain = try XCTUnwrap(sprite("contain").viewport(imageWidth: 192, imageHeight: 32, size: 24))
        XCTAssertEqual(contain.sheetWidth, 24)
        XCTAssertEqual(contain.sheetHeight, 4)
        let cover = try XCTUnwrap(sprite("cover").viewport(imageWidth: 192, imageHeight: 32, size: 24))
        XCTAssertEqual(cover.sheetWidth, 144)
        XCTAssertEqual(cover.sheetHeight, 24)
    }

    func testNonSquareCellIsCenteredAndClippedToItsOwnBounds() throws {
        let viewport = try XCTUnwrap(sprite(width: "64", x: "0").viewport(imageWidth: 192, imageHeight: 32, size: 24))
        XCTAssertEqual(viewport.cellWidth, 24)
        XCTAssertEqual(viewport.cellHeight, 12)
        XCTAssertEqual(viewport.insetY, 6)
        XCTAssertEqual(viewport.offsetY, 6)
    }

    func testInvalidDimensionsAndCSSUseFallback() throws {
        for size in ["0px", "-2px", "NaNpx", "calc(100%)", "10px 10px 10px", "10", "infinitypx"] {
            XCTAssertNil(try sprite(size).viewport(imageWidth: 192, imageHeight: 32, size: 24), size)
        }
        XCTAssertNil(try sprite(width: "0").viewport(imageWidth: 192, imageHeight: 32, size: 24))
        XCTAssertNil(try sprite().viewport(imageWidth: .infinity, imageHeight: 32, size: 24))
        XCTAssertNil(try sprite().viewport(imageWidth: 192, imageHeight: 32, size: 0))
    }

    func testAdditiveMetadataDecodesAndOldEmojiResponseRemainsSupported() throws {
        let json = #"{"reaction_id":7,"title":"Love","sprite_mode":1,"sprite_params":{"w":"32","h":32,"x":-32,"y":0,"bs":"auto"}}"#
        let reaction = try JSONDecoder.ekitapligim.decode(ChatReactionDTO.self, from: Data(json.utf8))
        XCTAssertTrue(reaction.spriteMode)
        XCTAssertEqual(reaction.spriteParams?.width, 32)
        XCTAssertEqual(reaction.spriteParams?.x, -32)
        let old = try JSONDecoder.ekitapligim.decode(ChatReactionDTO.self, from: Data(#"{"reaction_id":1,"emoji":"👍"}"#.utf8))
        XCTAssertFalse(old.spriteMode)
        XCTAssertNil(old.spriteParams)
        XCTAssertEqual(old.emoji, "👍")
    }

    func testMalformedOptionalSpriteDoesNotBreakEntireChatResponse() throws {
        for value in ["[]", "null", "\"invalid\""] {
            let json = "{\"reaction_id\":7,\"sprite_mode\":true,\"sprite_params\":\(value)}"
            let reaction = try JSONDecoder.ekitapligim.decode(ChatReactionDTO.self, from: Data(json.utf8))
            XCTAssertNil(reaction.spriteParams)
        }
    }
}
