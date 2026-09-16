import XCTest
@testable import EkitapligimCore

final class ReaderPositionTests: XCTestCase {
    func testEPUBStartIsAContinueCandidateEvenWhenPercentRoundsToZero() {
        let item = LibraryItemDTO(bookId: "7", shelfState: "NONE", progressPercent: 0, lastReadPage: 0,
            isDownloaded: false, isFavorite: false, title: "Book", author: "", coverUrl: "", pageCount: 0,
            lastReadAt: 123, positionType: "epub")
        XCTAssertTrue(item.isContinueReadingCandidate)
        XCTAssertEqual([item].continueReadingItem()?.bookId, "7")
        XCTAssertEqual(item.updating(progressPercent: 25).libraryMetaText, L10n.commonPercent(25))
    }

    func testActualServerDateAliasesAndStringNumbersDecode() throws {
        for key in ["last_read_date", "lastReadDate", "last_read_at", "updated_at"] {
            let json = "{\"book_id\":\"7\",\"last_read_page\":\"25\",\"\(key)\":\"123456\"}"
            let item = try JSONDecoder.ekitapligim.decode(LibraryItemDTO.self, from: Data(json.utf8))
            XCTAssertEqual(item.lastReadAt, 123456, key)
            XCTAssertEqual(item.lastReadPage, 25)
        }
    }

    func testProgressResponseAndFormKeepCFIOutOfURL() throws {
        let json = #"{"progress":{"position_type":"epub","position_value":"epubcfi(/6/2!/4/2/1:25)","progress_percent":23.5,"last_read_date":123},"revision":"abc","saved":true,"conflict":false}"#
        let result = try JSONDecoder.ekitapligim.decode(ReaderProgressResponseDTO.self, from: Data(json.utf8))
        let position = try XCTUnwrap(result.progress)
        XCTAssertTrue(position.isValid)
        XCTAssertNil(position.page)
        let endpoint = APIEndpoint.saveReaderProgress(bookID: 7, position: position, baseRevision: "abc", accountName: "reader")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertTrue(endpoint.queryItems.isEmpty)
        guard case .form(let fields) = endpoint.body else { return XCTFail("Expected form") }
        XCTAssertEqual(fields["position_type"], "epub")
        XCTAssertEqual(fields["position_value"], "epubcfi(/6/2!/4/2/1:25)")
        XCTAssertEqual(fields["base_revision"], "abc")
        XCTAssertEqual(fields["account_name"], "reader")
        XCTAssertEqual(APIEndpoint.readerProgress(bookID: 7).method, .get)
        XCTAssertTrue(APIEndpoint.readerProgress(bookID: 7).requiresAuthentication)
    }

    func testCFIParsesSpineTextAndEscapedAssertions() throws {
        let cfi = try EPUBCFI("epubcfi(/6/4[bölüm^]iki]!/4/2[paragraf]/1:25)")
        XCTAssertEqual(cfi.spineIndex, 1)
        XCTAssertEqual(cfi.contentSteps, [4, 2, 1])
        XCTAssertEqual(cfi.textOffset, 25)
        XCTAssertEqual(cfi.cssSelector, ":root > :nth-child(2) > :nth-child(1)")
        let range = try EPUBCFI("epubcfi(/6/2!/4/2,/1:12,/1:25)")
        XCTAssertEqual(range.contentSteps, [4, 2, 1])
        XCTAssertEqual(range.textOffset, 12)
    }

    func testInvalidCFIsAndNonFiniteProgressRejected() {
        for value in ["25", "epubcfi(/6/0!/4/2)", "epubcfi(/6/2!/4/2/1:-1)", "epubcfi(/6/2[bad!/4/2)", "epubcfi(/6/2!/4/1/2)"] {
            XCTAssertThrowsError(try EPUBCFI(value), value)
        }
        XCTAssertFalse(ReaderPositionDTO(positionType: "pdf", positionValue: "25", progressPercent: .nan).isValid)
        XCTAssertFalse(ReaderPositionDTO(positionType: "pdf", positionValue: "0", progressPercent: 0).isValid)
    }

    func testOPFSpineIncludesNonlinearEntriesAndResolvesRelativeUnicodePaths() throws {
        let data = Data(#"<package><metadata/><manifest><item id="a" href="cover.xhtml"/><item id="b" href="Text/bölüm%202.xhtml"/></manifest><spine><itemref idref="a" linear="no"/><itemref idref="b"/></spine></package>"#.utf8)
        let index = try EPUBPackageIndex(opf: data, packagePath: "EPUB/content.opf")
        XCTAssertEqual(index.items.count, 2)
        XCTAssertEqual(index.items[1].cfiBase, "/6/4")
        XCTAssertEqual(index.items[1].href, "EPUB/Text/bölüm 2.xhtml")
        XCTAssertEqual(EPUBPackageIndex.normalizedPath("https://reader.invalid/EPUB/Text/b%C3%B6l%C3%BCm%202.xhtml#x"), index.items[1].href)
    }
}
