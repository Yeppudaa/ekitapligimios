import Foundation
import XCTest
@testable import EkitapligimCore

final class HomeRefreshTests: XCTestCase {
    func testEditorRequestUsesFeaturedWebsiteSelectionAndKeepsSubdirectory() throws {
        let web = try XCTUnwrap(URL(string: "https://example.com/ekitapligim/"))
        let url = try XCTUnwrap(HomeEditorialRepository(webBaseURL: web).requestURL)
        // URL.path normalizes away a trailing directory slash on some Foundation versions.
        // Assert the actual wire URL and its raw path, including the canonical slash.
        XCTAssertEqual(url.absoluteString, "https://example.com/ekitapligim/books/?featured=1")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath, "/ekitapligim/books/")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "featured", value: "1")])
    }

    func testParserIgnoresHeroAndReadsRealEditorCardsWithEntitiesAndRelativeCovers() throws {
        let web = try XCTUnwrap(URL(string: "https://example.com/ekitapligim/"))
        let html = """
        <a href="/konular/fixed-hero.999/">Fixed hero</a>
        <article class="xcuBktCatalog-card is-new">
          <img src="covers/&#220;lke.webp?x=1&amp;y=2" alt="Fallback">
          <div class="xcuBktCatalog-bookTitle"><a href="/konular/kitap.42/">Beyaz <b>Zambaklar</b> &amp; &#220;lke</a></div>
          <div class="xcuBktCatalog-author">Grigori Petrov</div>
          <span class="xcuBktCatalog-tag">Roman</span>
        </article>
        """
        let books = HomeEditorialCatalogParser.books(html: html, baseURL: web)
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.id, "42")
        XCTAssertEqual(books.first?.title, "Beyaz Zambaklar & Ülke")
        XCTAssertEqual(books.first?.author, "Grigori Petrov")
        XCTAssertEqual(books.first?.category, "Roman")
        XCTAssertTrue(books.first?.coverUrl.contains("/ekitapligim/covers/") == true)
        XCTAssertTrue(books.first?.coverUrl.contains("x=1&y=2") == true)
        XCTAssertFalse(books.first?.isPremiumOnly ?? true)
    }

    func testParserDeduplicatesAndRejectsCardsWithMissingIDOrTitle() throws {
        let web = try XCTUnwrap(URL(string: "https://example.com/"))
        let valid = """
        <article class='xcuBktCatalog-card'><img src='/a.png' alt='A &quot;book&quot;'><a href='/konular/a.7/'>open</a><span>Premium</span></article>
        """
        let noID = "<article class='xcuBktCatalog-card'><img alt='Invalid'><a href='/profile/8'>open</a></article>"
        let noTitle = "<article class='xcuBktCatalog-card'><a href='/konular/empty.9/'>open</a></article>"
        let books = HomeEditorialCatalogParser.books(html: valid + valid + noID + noTitle, baseURL: web)
        XCTAssertEqual(books.map(\.id), ["7"])
        XCTAssertEqual(books.first?.title, "A \"book\"")
        XCTAssertTrue(books.first?.isPremiumOnly == true)
    }

    func testEmptyOrChangedWebsiteMarkupDoesNotInventEditorBooks() throws {
        let web = try XCTUnwrap(URL(string: "https://example.com/"))
        XCTAssertTrue(HomeEditorialCatalogParser.books(html: "", baseURL: web).isEmpty)
        XCTAssertTrue(HomeEditorialCatalogParser.books(html: "<article class='unrelated'><a href='/konular/a.7/'>A book</a></article>", baseURL: web).isEmpty)
        XCTAssertNil(HomeEditorialSelection.select(from: [], retaining: "7"))
    }

    func testEditorSpotlightRemainsStableWhenItsPoolIsReordered() throws {
        let books = try [book(id: "1", title: "First"), book(id: "2", title: "Second")]
        XCTAssertEqual(HomeEditorialSelection.select(from: Array(books.reversed()), retaining: "2")?.id, "2")
        XCTAssertTrue(["1", "2"].contains(HomeEditorialSelection.select(from: books, retaining: "not-in-pool")?.id ?? ""))
    }

    func testInvalidEditorRecordsCannotBecomeTheSpotlight() throws {
        let books = try [book(id: "", title: "Missing ID"), book(id: "3", title: "   "), book(id: "4", title: "Valid")]
        XCTAssertEqual(HomeEditorialSelection.select(from: books, retaining: "3")?.id, "4")
    }

    private func book(id: String, title: String) throws -> BookDTO {
        let payload: [String: Any] = ["id": id, "title": title, "author": "", "publisher": "", "isbn": "", "category": "", "language": "", "publishYear": "", "description": "", "coverUrl": "", "pdfUrl": "", "pageCount": 0, "isPremiumOnly": false]
        return try JSONDecoder().decode(BookDTO.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}
