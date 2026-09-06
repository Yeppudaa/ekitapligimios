import XCTest
import ReadiumShared
import ReadiumStreamer
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class EPUBReaderPositionTests: XCTestCase {
    func testWebCFISelectsCorrectReadiumChapterAndParagraph() async throws {
        let (adapter, publication) = try await openFixture()
        let position = ReaderPositionDTO(positionType: "epub", positionValue: "epubcfi(/6/4[two]!/4/2/1:12)", progressPercent: 55)
        let locator = try XCTUnwrap(adapter.initialLocator(position, publication: publication))
        XCTAssertEqual(EPUBPackageIndex.normalizedPath(locator.href.string), "OEBPS/two.xhtml")
        XCTAssertEqual(locator.locations.cssSelector, ":root > :nth-child(2) > :nth-child(1)")
        XCTAssertEqual(adapter.package.items[0].cfiBase, "/6/2")
        XCTAssertEqual(adapter.package.items[1].cfiBase, "/6/4")
    }

    func testInvalidOrMismatchedSavedLocationIsNotSilentlyReplacedWithStart() async throws {
        let (adapter, publication) = try await openFixture()
        XCTAssertThrowsError(try adapter.initialLocator(ReaderPositionDTO(positionType: "epub",
            positionValue: "epubcfi(/6/200!/4/2/1:12)", progressPercent: 55), publication: publication))
        XCTAssertThrowsError(try adapter.initialLocator(ReaderPositionDTO(positionType: "pdf",
            positionValue: "25", progressPercent: 55), publication: publication))
        XCTAssertNil(try adapter.initialLocator(nil, publication: publication))
    }

    private func openFixture() async throws -> (EPUBPositionAdapter, Publication) {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ReadingSync", withExtension: "epub"))
        let http = DefaultHTTPClient()
        let retriever = AssetRetriever(httpClient: http)
        let file = try XCTUnwrap(FileURL(url: url))
        let asset = try await retriever.retrieve(url: file).get()
        let adapter = try await EPUBPositionAdapter(asset: asset)
        let opener = PublicationOpener(parser: DefaultPublicationParser(httpClient: http,
            assetRetriever: retriever, pdfFactory: DefaultPDFDocumentFactory()), contentProtections: [])
        let publication = try await opener.open(asset: asset, allowUserInteraction: false, sender: nil).get()
        return (adapter, publication)
    }
}
