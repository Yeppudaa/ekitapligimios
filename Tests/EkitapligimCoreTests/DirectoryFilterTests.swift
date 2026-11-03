import XCTest
@testable import EkitapligimCore

final class DirectoryFilterTests: XCTestCase {
    func testRemoteQueryPreservesExistingEndpointSearchContract() {
        XCTAssertNil(DirectoryFilter().remoteQuery)
        XCTAssertEqual(DirectoryFilter(letter: " z ").remoteQuery, "Z")
        XCTAssertEqual(DirectoryFilter(query: " Şafak ", letter: "E").remoteQuery, "Şafak")
        XCTAssertEqual(DirectoryFilter(letter: "i").letter, "İ")
        XCTAssertEqual(DirectoryFilter(letter: "ı").letter, "I")
    }

    func testTurkishDottedAndDotlessInitialsAreDistinct() throws {
        let dotted = try item("İlber Ortaylı")
        let dotless = try item("Işık Öğütçü")
        XCTAssertTrue(DirectoryFilter(letter: "İ").matches(dotted))
        XCTAssertFalse(DirectoryFilter(letter: "I").matches(dotted))
        XCTAssertTrue(DirectoryFilter(letter: "I").matches(dotless))
        XCTAssertFalse(DirectoryFilter(letter: "İ").matches(dotless))
    }

    func testLetterMatchesInitialInsteadOfMiddleAndTrimsWhitespace() throws {
        XCTAssertFalse(DirectoryFilter(letter: "Z").matches(try item("Franz Kafka")))
        XCTAssertTrue(DirectoryFilter(letter: "Z").matches(try item("  Zülfü Livaneli\n")))
        for name in ["Çetin Altan", "Ömer Seyfettin", "Şermin Yaşar", "Ümit Kaftancıoğlu", "Ğ Test"] {
            XCTAssertTrue(DirectoryFilter(letter: String(name.prefix(1))).matches(try item(name)))
        }
    }

    func testSearchAndLetterIntersectUsingTurkishCase() throws {
        let filter = DirectoryFilter(query: "şafak", letter: "E")
        XCTAssertTrue(filter.matches(try item("Elif Şafak")))
        XCTAssertFalse(filter.matches(try item("Elif Batuman")))
        XCTAssertFalse(filter.matches(try item("Şafak Pavey")))
        XCTAssertTrue(DirectoryFilter(query: "ışık").matches(try item("Işık Öğütçü")))
    }

    func testAllLettersIncludesForeignInitialsAndNumbers() throws {
        for name in ["William Shakespeare", "Q Kitap", "1984 Yayınları", "X Yayınevi"] {
            XCTAssertTrue(DirectoryFilter().matches(try item(name)))
        }
        XCTAssertTrue(DirectoryFilter(query: " \n ").isUnfiltered)
        XCTAssertFalse(DirectoryFilter(letter: "A").isUnfiltered)
    }

    func testAscendingAndDescendingUseTurkishAlphabet() throws {
        let items = try ["Şule", "Işık", "İlber", "Ömer", "Cem", "Çetin", "Orhan", "Selim"].map(item)
        let expected = ["Cem", "Çetin", "Işık", "İlber", "Orhan", "Ömer", "Selim", "Şule"]
        XCTAssertEqual(DirectoryFilter().sorted(items, ascending: true).map(\.name), expected)
        XCTAssertEqual(DirectoryFilter().sorted(items, ascending: false).map(\.name), Array(expected.reversed()))
    }

    private func item(_ name: String) throws -> DirectoryItemDTO {
        try JSONDecoder().decode(DirectoryItemDTO.self, from: JSONSerialization.data(withJSONObject: ["id": name, "name": name]))
    }
}
